// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

// import 'hardhat/console.sol';

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../stores/AssetStore.sol";
import "../stores/DataStore.sol";
import "../stores/FundStore.sol";
import "../stores/FundingStore.sol";
import "../stores/MarketStore.sol";
import "../stores/OrderStore.sol";
import "../stores/PoolStore.sol";
import "../stores/PositionStore.sol";
import "../stores/RebateStore.sol";
import "../stores/ReferralStore.sol";
import "../stores/RiskStore.sol";
import "../stores/StakingStore.sol";

import "./Funding.sol";
import "./Pool.sol";

import "../utils/Chainlink.sol";
import "../utils/Roles.sol";

contract Positions is Roles {

	uint256 public constant UNIT = 10**18;
	uint256 public constant BPS_DIVIDER = 10000;

	event PositionIncreased(
		uint256 indexed orderId,
		address indexed user,
		address indexed asset,
		string market,
		bool isLong,
		uint256 size,
		uint256 margin,
		uint256 price,
		uint256 positionMargin,
		uint256 positionSize,
		uint256 positionPrice,
		int256 fundingTracker,
		uint256 fee
	);

	event PositionDecreased(
		uint256 indexed orderId,
		address indexed user,
		address indexed asset,
		string market,
		bool isLong,
		uint256 size,
		uint256 margin,
		uint256 price,
		uint256 positionMargin,
		uint256 positionSize,
		uint256 positionPrice,
		int256 fundingTracker,
		uint256 fee,
		int256 pnl,
		int256 fundingFee
	);


	event MarginIncreased(
		address indexed user,
		address indexed asset,
		string market,
		uint256 marginDiff,
		uint256 positionMargin
	);

	event MarginDecreased(
		address indexed user,
		address indexed asset,
		string market,
		uint256 marginDiff,
		uint256 positionMargin
	);

	event FeePaid(
		uint256 indexed orderId,
	    address indexed user,
	    address indexed asset,
	    string market,
	    uint256 fee,
	    uint256 originalFee,
	    uint256 poolFee,
	    uint256 stakingFee,
	    uint256 referrerFee,
	    uint256 oracleFee,
	    bool isLiquidation
	);

	event ReferrerPaid(
		address indexed referrer,
		address indexed asset,
		uint256 referrerFee,
		address referrerUser,
		uint256 referrerShareBps
	);

	DataStore public DS;

	AssetStore public assetStore;
	FundStore public fundStore;
	FundingStore public fundingStore;
	MarketStore public marketStore;
	OrderStore public orderStore;
	PoolStore public poolStore;
	PositionStore public positionStore;
	RebateStore public rebateStore;
	ReferralStore public referralStore;
	RiskStore public riskStore;
	StakingStore public stakingStore;

	Funding public funding;
	Pool public pool;

	Chainlink public chainlink;

	constructor(RoleStore rs, DataStore ds) Roles(rs) {
		DS = ds;
	}

	function link() external onlyGov {
		assetStore = AssetStore(DS.getAddress('AssetStore'));
		fundStore = FundStore(payable(DS.getAddress('FundStore')));
		fundingStore = FundingStore(DS.getAddress('FundingStore'));
		marketStore = MarketStore(DS.getAddress('MarketStore'));
		orderStore = OrderStore(DS.getAddress('OrderStore'));
		poolStore = PoolStore(DS.getAddress('PoolStore'));
		positionStore = PositionStore(DS.getAddress('PositionStore'));
		rebateStore = RebateStore(DS.getAddress('RebateStore'));
		referralStore = ReferralStore(DS.getAddress('ReferralStore'));
		riskStore = RiskStore(DS.getAddress('RiskStore'));
		stakingStore = StakingStore(DS.getAddress('StakingStore'));
		funding = Funding(DS.getAddress('Funding'));
		pool = Pool(DS.getAddress('Pool'));
		chainlink = Chainlink(DS.getAddress('Chainlink'));
	}

	modifier ifNotPaused() {
		require(!orderStore.areNewOrdersPaused(), "!paused");
		_;
	}

	function increasePosition(
		uint256 orderId, 
		uint256 price
	) public onlyContract {

		// console.log(1);

		OrderStore.Order memory order = orderStore.get(orderId);
		riskStore.checkMaxOI(order.asset, order.market, order.size);

		// console.log(2);

		PositionStore.Position memory position = positionStore.get(order.user, order.asset, order.market);
		MarketStore.Market memory market = marketStore.get(order.market);

		// console.log(3);

		uint256 originalFee = order.size * market.fee / BPS_DIVIDER;
		uint256 feeWithRebate = order.fee;

		// console.log(4);

		creditFee(
			orderId,
			order.user, 
			order.asset, 
			order.market, 
			feeWithRebate, 
			originalFee,
			false
		);

		positionStore.incrementOI(
			order.asset, 
			order.market, 
			order.size, 
			position.isLong
		);

		funding.updateFundingTracker(order.asset, order.market);

		// console.log(5);

		uint256 averagePrice = (position.size * position.price + order.size * price) / (position.size + order.size);

		if (position.size == 0) {
			position.user = order.user;
			position.asset = order.asset;
			position.market = order.market;
			position.timestamp = block.timestamp;
			position.isLong = order.isLong;
			position.fundingTracker = fundingStore.getFundingTracker(order.asset, order.market);
		}

		// console.log(6);

		position.size += order.size;
		position.margin += order.margin;
		position.price = averagePrice;

		positionStore.addOrUpdate(position);

		// console.log(7);

		// console.log(8);

		rebateStore.incrementUserVolume(
			order.user, 
			market.fee,
			_getUsdAmount(order.asset, order.size)
		);

		// console.log(9);

		orderStore.remove(orderId);

		// console.log(10);

		emit PositionIncreased(
			orderId,
			order.user,
			order.asset,
			order.market,
			order.isLong,
			order.size,
			order.margin,
			price,
			position.margin,
			position.size,
			position.price,
			position.fundingTracker,
			feeWithRebate
		);

	}

	function decreasePosition(
		uint256 orderId, 
		uint256 price
	) external onlyContract {

		OrderStore.Order memory order = orderStore.get(orderId);
		MarketStore.Market memory market = marketStore.get(order.market);
		PositionStore.Position memory position = positionStore.get(order.user, order.asset, order.market);

		uint256 executedOrderSize = position.size > order.size ? order.size : position.size;
		uint256 remainingOrderSize = order.size - executedOrderSize;

		uint256 remainingOrderMargin;

		uint256 amountToReturnToUser;

		// if (order.isReduceOnly) {
		// 	// order.margin = 0
		// 	// A fee (order.fee) corresponding to order.size was charged on submit. Only fee corresponding to executedOrderSize should be charged, rest should be returned, if any
		// 	amountToReturnToUser += order.fee * remainingOrderSize / order.size;
		// } else {
		if (!order.isReduceOnly) {
			// User submitted order.margin when sending the order. Refund the portion of order.margin that executes against the position
			uint256 executedOrderMargin = order.margin * executedOrderSize / order.size;
			amountToReturnToUser += executedOrderMargin;
			remainingOrderMargin = order.margin - executedOrderMargin;
		}

		uint256 originalFee = market.fee * executedOrderSize / BPS_DIVIDER;
		uint256 feeWithRebate = order.fee * executedOrderSize / order.size;

		creditFee(
			orderId,
			order.user, 
			order.asset, 
			order.market, 
			feeWithRebate, 
			originalFee, 
			false
		);

		// If an order is reduce-only, fee is taken from the position's margin.
		uint256 feeToPay = order.isReduceOnly ? feeWithRebate : 0;

		// Funding update

		positionStore.decrementOI(
			order.asset, 
			order.market, 
			order.size, 
			position.isLong
		);

		funding.updateFundingTracker(order.asset, order.market);

		// P/L

		(int256 pnl, int256 fundingFee) = getPnL(
			order.asset, 
			order.market, 
			position.isLong, 
			price, 
			position.price, 
			executedOrderSize, 
			position.fundingTracker
		);

		uint256 executedPositionMargin = position.margin * executedOrderSize / position.size;

		if (pnl <= -1 * int256(position.margin)) {
			pnl = -1 * int256(position.margin);
			executedPositionMargin = position.margin;
			executedOrderSize = position.size;
			position.size = 0;
		} else {
			position.margin -= executedPositionMargin;
			position.size -= executedOrderSize;
			position.fundingTracker = fundingStore.getFundingTracker(order.asset, order.market);
		}

		riskStore.checkMarketRisk(order.market, order.asset, pnl);
		riskStore.checkPoolRisk(order.asset, pnl);

		if (pnl < 0) {
			uint256 absPnl = uint256(-1 * pnl);
			
			pool.creditTraderLoss(
				order.user,
				order.asset, 
				order.market, 
				absPnl
			);

			uint256 totalPnl = absPnl + feeToPay;

			if (totalPnl < executedPositionMargin) {
				// If an order is reduce-only, fee is taken from the position's margin as the order's margin is zero.
				amountToReturnToUser += executedPositionMargin - totalPnl;
			}

		} else {	
			pool.debitTraderProfit(
				order.user, 
				order.asset, 
				order.market, 
				uint256(pnl)
			);
			// If an order is reduce-only, fee is taken from the position's margin as the order's margin is zero.
			amountToReturnToUser += executedPositionMargin - feeToPay;
		}

		fundStore.transferOut(order.asset, order.user, amountToReturnToUser);

		rebateStore.incrementUserVolume(
			order.user, 
			market.fee,
			_getUsdAmount(order.asset, executedOrderSize)
		);

		

		if (position.size == 0) {
			positionStore.remove(order.user, order.asset, order.market);
		} else {
			positionStore.addOrUpdate(position);
		}

		orderStore.remove(orderId);

		emit PositionDecreased(
			orderId,
			order.user,
			order.asset,
			order.market,
			order.isLong,
			executedOrderSize,
			executedPositionMargin,
			price,
			position.margin,
			position.size,
			position.price,
			position.fundingTracker,
			feeWithRebate,
			pnl,
			fundingFee
		);

		// Open position in opposite direction if size remains

		if (!order.isReduceOnly && remainingOrderSize > 0) {

			OrderStore.Order memory nextOrder = OrderStore.Order({
				orderId: 0,
				user: order.user,
				market: order.market,
				asset: order.asset,
				margin: remainingOrderMargin,
				size: remainingOrderSize,
				price: 0,
				isLong: order.isLong,
				fee: order.fee * remainingOrderSize / order.size,
				orderType: 0,
				isReduceOnly: false,
				timestamp: block.timestamp,
				expiry: 0,
				cancelOrderId: 0
			});

			uint256 nextOrderId = orderStore.add(nextOrder);

			increasePosition(nextOrderId, price);

		}

	}

	function flushPosition(
		address user, 
		address asset, 
		string memory market
	) external onlyGov {

		PositionStore.Position memory position = positionStore.get(user, asset, market);
		require(position.size > 0, "!position");

		// flush a user out of a position, can be used after they are blocked, simply close their position and return their margin without profits

		fundStore.transferOut(asset, user, position.margin);
		
		positionStore.decrementOI(
			asset, 
			market, 
			position.size, 
			position.isLong
		);
		
		positionStore.remove(user, asset, market);

		funding.updateFundingTracker(asset, market);

		emit PositionDecreased(
			0,
			user,
			asset,
			market,
			!position.isLong,
			0,
			0,
			0,
			position.margin,
			position.size,
			position.price,
			position.fundingTracker,
			0,
			0,
			0
		);

	}

	function addMargin(
		address asset,
		string calldata market,
		uint256 margin
	) external payable ifNotPaused {

		address user = msg.sender;

		PositionStore.Position memory position = positionStore.get(user, asset, market);

		require(position.size > 0, "!position");

		// Transfer funds
		if (asset == address(0)) {
			margin = msg.value;
			fundStore.transferIn{value: margin}(asset, user, margin);
		} else {
			fundStore.transferIn(asset, user, margin);
		}

		require(margin > 0, "!margin");

		position.margin += margin;

		// Leverage
		uint256 leverage = UNIT * position.size / position.margin;
		require(leverage >= UNIT, "!min-leverage");

		positionStore.addOrUpdate(position);

		emit MarginIncreased(
			user,
			asset,
			market,
			margin,
			position.margin
		);

	}

	function removeMargin(
		address asset,
		string calldata market,
		uint256 margin
	) external ifNotPaused {

		address user = msg.sender;

		MarketStore.Market memory marketInfo = marketStore.get(market);
		PositionStore.Position memory position = positionStore.get(user, asset, market);
		require(position.size > 0, "!position");
		require(position.margin > margin, "!margin");

		uint256 remainingMargin = position.margin - margin;

		// Leverage
		uint256 leverageAfterRemoval = UNIT * position.size / remainingMargin;
		require(leverageAfterRemoval <= marketInfo.maxLeverage * UNIT, "!max-leverage");

		// This is not available for markets without Chainlink
		uint256 price = chainlink.getPrice(marketInfo.chainlinkFeed);
		require(price > 0, "!price");

		(int256 upl, ) = getPnL(
			asset, 
			market, 
			position.isLong, 
			price, 
			position.price, 
			position.size, 
			position.fundingTracker
		);

		if (upl < 0) {
			uint256 absUpl = uint256(-1 * upl);
			require(absUpl < remainingMargin * (BPS_DIVIDER - positionStore.removeMarginBuffer()) / BPS_DIVIDER, "!upl");
		}

		position.margin = remainingMargin;

		positionStore.addOrUpdate(position);

		fundStore.transferOut(asset, user, margin);

		emit MarginDecreased(
			user,
			asset,
			market,
			margin,
			position.margin
		);

	}

	function creditFee(
		uint256 orderId,
		address user,
		address asset,
		string memory market,
		uint256 fee,
		uint256 originalFee,
		bool isLiquidation
	) public onlyContract {

		// Credit fee to poolers and stakers

		if (fee == 0) return;

		uint256 referrerFee = _payReferrer(user, asset, fee);
		uint256 oracleFee = _fundOracle(asset, fee);

		uint256 netFee = fee - referrerFee - oracleFee;

		uint256 feeToStaking = netFee * stakingStore.feeShare() / BPS_DIVIDER;
		uint256 feeToPool = netFee - feeToStaking;

		poolStore.incrementBalance(asset, feeToPool);
		stakingStore.incrementPendingReward(asset, feeToStaking);

		emit FeePaid(
			orderId,
			user, 
			asset, 
			market,
			fee, // paid by user
			originalFee,
			feeToPool,
			feeToStaking,
			referrerFee,
			oracleFee,
			isLiquidation
		);

	}

	function getPnL(
		address asset,
		string memory market,
		bool isLong,
		uint256 price,
		uint256 positionPrice,
		uint256 size,
		int256 fundingTracker
	) public view returns(int256 pnl, int256 fundingFee) {

		if (price == 0 || positionPrice == 0 || size == 0) return (0,0);

		if (isLong) {
			pnl = int256(size) * (int256(price) - int256(positionPrice)) / int256(positionPrice);
		} else {
			pnl = int256(size) * (int256(positionPrice) - int256(price)) / int256(positionPrice);
		}

		int256 currentFundingTracker = fundingStore.getFundingTracker(asset, market);
		fundingFee = int256(size) * (currentFundingTracker - fundingTracker) / int256(BPS_DIVIDER);

		if (isLong) {
			pnl -= fundingFee; // positive = longs pay, negative = longs receive
		} else {
			pnl += fundingFee; // positive = shorts receive, negative = shorts pay
		}

		return (pnl, fundingFee);

	}


	// Utils

	function _getUsdAmount(
		address asset, 
		uint256 amount
	) internal view returns(uint256) {
		AssetStore.Asset memory assetInfo = assetStore.get(asset);
		uint256 chainlinkPrice = chainlink.getPrice(assetInfo.chainlinkFeed);
		uint256 decimals = 18;
		if (asset != address(0)) {
			decimals = IERC20Metadata(asset).decimals();
		}
		// amount is in the asset's decimals, convert to 18. Price is 18 decimals
		return amount * chainlinkPrice / 10**decimals;
	}

	function _payReferrer(
		address user,
		address asset,
		uint256 amount 
	) internal returns(uint256) {
		// Transfer fee portion to referrer if any
		address referrer = referralStore.getReferredBy(user);
		uint256 referrerFee;
		if (referrer != address(0)) {
			uint256 referrerShareBps = referralStore.getReferrerShareForUser(user);
			referrerFee = amount * referrerShareBps / BPS_DIVIDER;
			fundStore.transferOut(asset, referrer, referrerFee);
			emit ReferrerPaid(
				referrer,
				asset,
				referrerFee,
				user,
				referrerShareBps
			);
		}
		return referrerFee;
	}

	function _fundOracle(address asset, uint256 amount) internal returns(uint256) {
		// Transfer fee portion to oracle if any
		address oracle = DS.getAddress("oracle");
		uint256 oracleFeeShare = positionStore.oracleFeeShare();
		uint256 oracleFee = oracleFeeShare * amount / BPS_DIVIDER;
		fundStore.transferOut(asset, oracle, oracleFee);
		return oracleFee;
	}

}