// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

// import 'hardhat/console.sol';

import "../stores/AssetStore.sol";
import "../stores/DataStore.sol";
import "../stores/FundStore.sol";
import "../stores/MarketStore.sol";
import "../stores/OrderStore.sol";
import "../stores/PoolStore.sol";
import "../stores/PositionStore.sol";
import "../stores/RiskStore.sol";

import "./Funding.sol";
import "./Orders.sol";
import "./Pool.sol";
import "./Positions.sol";

import "../utils/Chainlink.sol";
import "../utils/Roles.sol";

contract Processor is Roles {

	uint256 public constant BPS_DIVIDER = 10000;

	event LiquidationError(
		address user,
		address asset,
		string market,
		uint256 price,
		string reason
	);

	event PositionLiquidated(
		address indexed user,
		address indexed asset,
		string market,
		bool isLong,
		uint256 size,
		uint256 margin,
		uint256 price,
		uint256 fee
	);

	DataStore public DS;

	AssetStore public assetStore;
	FundStore public fundStore;
	MarketStore public marketStore;
	OrderStore public orderStore;
	PoolStore public poolStore;
	PositionStore public positionStore;
	RiskStore public riskStore;

	Funding public funding;
	Orders public orders;
	Pool public pool;
	Positions public positions;

	Chainlink public chainlink;

	constructor(RoleStore rs, DataStore ds) Roles(rs) {
		DS = ds;
	}

	function link() external onlyGov {
		assetStore = AssetStore(DS.getAddress('AssetStore'));
		fundStore = FundStore(payable(DS.getAddress('FundStore')));
		marketStore = MarketStore(DS.getAddress('MarketStore'));
		orderStore = OrderStore(DS.getAddress('OrderStore'));
		poolStore = PoolStore(DS.getAddress('PoolStore'));
		positionStore = PositionStore(DS.getAddress('PositionStore'));
		riskStore = RiskStore(DS.getAddress('RiskStore'));
		funding = Funding(DS.getAddress('Funding'));
		pool = Pool(DS.getAddress('Pool'));
		orders = Orders(DS.getAddress('Orders'));
		positions = Positions(DS.getAddress('Positions'));
		chainlink = Chainlink(DS.getAddress('Chainlink'));
	}

	modifier ifNotPaused() {
		require(!orderStore.isProcessingPaused(), "!paused");
		_;
	}

	// ORDER EXECUTION

	// Anyone can call this
	function selfExecuteOrder(uint256 orderId) external ifNotPaused {
		(bool status, string memory reason) = _executeOrder(orderId, 0, true);
		require(status, reason);
	}

	// Orders that cannot be executed the first time by oracle are cancelled with reason
	function executeOrders(uint256[] calldata orderIds, uint256[] calldata prices) external ifNotPaused onlyOracle {
		for (uint256 i = 0; i < orderIds.length; i++) {
			(bool status, string memory reason) = _executeOrder(orderIds[i], prices[i], false);
			if (!status) orders.cancelOrder(orderIds[i], reason);
		}
	}

	function _executeOrder(uint256 orderId, uint256 price, bool withChainlink) internal returns(bool, string memory) {

		// console.log(1);

		OrderStore.Order memory order = orderStore.get(orderId);
		if (order.size == 0) {
			return (false, "!order");
		}

		// console.log(3);

		if (order.expiry > 0 && order.expiry <= block.timestamp) {
			return (false, "!expired");
		}

		// console.log(4);

		// cancel if order is too old
		uint256 ttl = block.timestamp - order.timestamp;
		if (order.orderType == 0 && ttl > orderStore.maxMarketOrderTTL() || ttl > orderStore.maxTriggerOrderTTL()) {
			return (false, "!too-old");
		}

		// console.log(5);

		MarketStore.Market memory market = marketStore.get(order.market);
		if (market.isClosed) {
			return (false, "!market-closed");
		}

		// console.log(6);

		uint256 chainlinkPrice = chainlink.getPrice(market.chainlinkFeed);

		if (withChainlink) {
			if (chainlinkPrice == 0) {
				return (false, "!no-chainlink-price");
			}
			if (!market.allowChainlinkExecution) {
				return (false, "!chainlink-not-allowed");
			}
			if (order.timestamp >= block.timestamp - orderStore.chainlinkCooldown()) {
				return (false, "!chainlink-cooldown");
			}
			price = chainlinkPrice;
		}

		// console.log(7);

		if (price == 0) {
			return (false, "!no-price");
		}

		// console.log(market.maxDeviation, chainlinkPrice, price);

		// Bound provided price with chainlink
		if (!_boundPriceWithChainlink(market.maxDeviation, chainlinkPrice, price)) {
			// TODO: not ideal?
			return (true, "!chainlink-deviation"); // returns true so as not to trigger order cancellation
		}

		// console.log(8);

		// Is trigger order executable at provided price?
		if (order.orderType != 0) {
			if( withChainlink && (
				order.orderType == 1 && order.isLong && price > order.price || // limit buy
				order.orderType == 1 && !order.isLong && price < order.price || // limit sell
				order.orderType == 2 && order.isLong && price < order.price || // stop buy
				order.orderType == 2 && !order.isLong && price > order.price // stop sell
			)) {
				return (true, "!no-execution"); // don't cancel order
			}
			// price = order.price; // can't have this otherwise orders might execute at much worse than market price
		} else if (order.price > 0) {
			// protected market order
			if(order.isLong && price > order.price || !order.isLong && price < order.price) {
				return (false, "!protected");
			}
		}

		// console.log(9);

		// OCO
		if (order.cancelOrderId > 0) {
			try orders.cancelOrder(order.cancelOrderId, "!oco") {	
			} catch Error(string memory reason) {
				return (false, reason);
			}
		}

		// Check if there is a position
		PositionStore.Position memory position = positionStore.get(order.user, order.asset, order.market);

		// console.log(10);

		bool doAdd = !order.isReduceOnly && (position.size == 0 || order.isLong == position.isLong);
		bool doReduce = position.size > 0 && order.isLong != position.isLong;

		if (doAdd) {
			try positions.increasePosition(orderId, price) {
			} catch Error(string memory reason) {
				return (false, reason);
			}
		} else if (doReduce) {
			try positions.decreasePosition(orderId, price) {
			} catch Error(string memory reason) {
				return (false, reason);
			}
		} else {
			return (false, "!reduce");
		}

		// console.log(11);

		return (true, '');

	}

	// POSITION LIQUIDATION

	// Anyone can call this
	function selfLiquidatePosition(address user, address asset, string memory market) external ifNotPaused {
		(bool status, string memory reason) = _liquidatePosition(user, asset, market, 0, true);
		require(status, reason);
	}

	function liquidatePositions(
		address[] calldata users,
		address[] calldata assets,
		string[] calldata markets,
		uint256[] calldata prices
	) external ifNotPaused onlyOracle {
		for (uint256 i = 0; i < users.length; i++) {
			(bool status, string memory reason) = _liquidatePosition(
				users[i], 
				assets[i], 
				markets[i], 
				prices[i], 
				false
			);
			if (!status) {
				emit LiquidationError(
					users[i], 
					assets[i], 
					markets[i], 
					prices[i],
					reason
				);
			}
		}
	}

	function _liquidatePosition(
		address user, 
		address asset,
		string memory market,
		uint256 price,
		bool withChainlink
	) internal returns(bool, string memory) {

		PositionStore.Position memory position = positionStore.get(user, asset, market);
		if (position.size == 0) {
			return (false, "!position");
		}

		MarketStore.Market memory marketInfo = marketStore.get(market);
		if (marketInfo.isClosed) {
			return (false, "!market-closed");
		}

		uint256 chainlinkPrice = chainlink.getPrice(marketInfo.chainlinkFeed);

		if (withChainlink) {
			if (chainlinkPrice == 0) {
				return (false, "!no-chainlink-price");
			}
			price = chainlinkPrice;
		}

		if (price == 0) {
			return (false, "!no-price");
		}

		// Bound provided price with chainlink
		if (!_boundPriceWithChainlink(marketInfo.maxDeviation, chainlinkPrice, price)) {
			return (false, "!chainlink-deviation");
		}

		(int256 pnl, ) = positions.getPnL(
			asset, 
			market, 
			position.isLong, 
			price, 
			position.price, 
			position.size, 
			position.fundingTracker
		);

		uint256 threshold = position.margin * marketInfo.liqThreshold / BPS_DIVIDER;

		if (pnl <= -1 * int256(threshold)) {

			// TODO: below should probably be DRYed with position decreased in Positions contract, and emit same event with isLiquidation = true

			uint256 fee = position.size * marketInfo.fee / BPS_DIVIDER;

			pool.creditTraderLoss(
				user,
				asset, 
				market, 
				position.margin - fee
			);

			positions.creditFee(
				0,
				user, 
				asset, 
				market, 
				fee, 
				fee,
				true
			);

			positionStore.decrementOI(
				asset, 
				market, 
				position.size, 
				position.isLong
			);

			funding.updateFundingTracker(asset, market);

			positionStore.remove(user, asset, market);

			emit PositionLiquidated(
				user,
				asset,
				market,
				position.isLong,
				position.size,
				position.margin,
				price,
				fee
			);

		}

		return (true, '');

	}


	// -- Utils -- //

	function _boundPriceWithChainlink(uint256 maxDeviation, uint256 chainlinkPrice, uint256 price) internal pure returns(bool) {
		if (chainlinkPrice == 0 || maxDeviation == 0) return true;
		if (
			price >= chainlinkPrice * (BPS_DIVIDER - maxDeviation) / BPS_DIVIDER &&
			price <= chainlinkPrice * (BPS_DIVIDER + maxDeviation) / BPS_DIVIDER
		) {
			return true;
		}
		return false;
	}

	

}