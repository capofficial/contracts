// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

// import 'hardhat/console.sol';

import "@openzeppelin/contracts/utils/Address.sol";

import "../stores/AssetStore.sol";
import "../stores/DataStore.sol";
import "../stores/FundStore.sol";
import "../stores/OrderStore.sol";
import "../stores/PositionStore.sol";
import "../stores/MarketStore.sol";
import "../stores/RebateStore.sol";
import "../stores/ReferralStore.sol";
import "../stores/RiskStore.sol";

import "../utils/Chainlink.sol";
import "../utils/Roles.sol";

/*
Order of function / event params: id, user, asset, market
*/

contract Orders is Roles {

	using Address for address payable;

	uint256 public constant UNIT = 10**18;
	uint256 public constant BPS_DIVIDER = 10000;

	event OrderCreated(
		uint256 indexed orderId,
		address indexed user,
		address indexed asset,
		string market,
		bool isLong,
		uint256 margin,
		uint256 size,
		uint256 price,
		uint256 fee,
		uint8 orderType,
		bool isReduceOnly,
		uint256 expiry,
		uint256 cancelOrderId
	);

	event OrderCancelled(
		uint256 indexed orderId,
		address indexed user,
		string reason
	);

	DataStore public DS;

	AssetStore public assetStore;
	FundStore public fundStore;
	MarketStore public marketStore;
	OrderStore public orderStore;
	PositionStore public positionStore;
	RebateStore public rebateStore;
	ReferralStore public referralStore;
	RiskStore public riskStore;

	Chainlink public chainlink;

	constructor(RoleStore rs, DataStore ds) Roles(rs) {
		DS = ds;
	}

	function link() external onlyGov {
		assetStore = AssetStore(DS.getAddress('AssetStore'));
		fundStore = FundStore(payable(DS.getAddress('FundStore')));
		marketStore = MarketStore(DS.getAddress('MarketStore'));
		orderStore = OrderStore(DS.getAddress('OrderStore'));
		positionStore = PositionStore(DS.getAddress('PositionStore'));
		rebateStore = RebateStore(DS.getAddress('RebateStore'));
		referralStore = ReferralStore(DS.getAddress('ReferralStore'));
		riskStore = RiskStore(DS.getAddress('RiskStore'));
		chainlink = Chainlink(DS.getAddress('Chainlink'));
	}

	modifier ifNotPaused() {
		require(!orderStore.areNewOrdersPaused(), "!paused");
		_;
	}

	function submitOrder(
		OrderStore.Order memory params, 
		uint256 tpPrice,
		uint256 slPrice,
		string memory refCode
	) external payable ifNotPaused {

		referralStore.setReferrer(refCode);
		
		uint256 vc1;
		uint256 vc2;
		uint256 vc3;

		if (tpPrice > 0 || slPrice > 0) {
			params.isReduceOnly = false;
		}

		(, vc1) = _submitOrder(params);

		if (tpPrice > 0 || slPrice > 0) {
			
			if (params.price > 0) {
				if (tpPrice > 0) {
					require(params.isLong && tpPrice > params.price || !params.isLong && tpPrice < params.price, "!tp-invalid");
				}
				if (slPrice > 0) {
					require(params.isLong && slPrice < params.price || !params.isLong && slPrice > params.price, "!sl-invalid");
				}
			}

			if (tpPrice > 0 && slPrice > 0) {
				require(params.isLong && tpPrice > slPrice || !params.isLong && tpPrice < slPrice, "!tpsl-invalid");
			}

			uint256 tpOrderId;
			uint256 slOrderId;

			if (tpPrice > 0 || slPrice > 0) {
				params.isLong = !params.isLong;
			}

			if (tpPrice > 0) {
				params.price = tpPrice;
				params.orderType = 1;
				params.isReduceOnly = true;
				(tpOrderId, vc2) = _submitOrder(params);
			}
			if (slPrice > 0) {
				params.price = slPrice;
				params.orderType = 2;
				params.isReduceOnly = true;
				(slOrderId, vc3) = _submitOrder(params);
			}

			if (tpOrderId > 0 && slOrderId > 0) {
				// Update orders to cancel each other
				orderStore.updateCancelOrderId(tpOrderId, slOrderId);
				orderStore.updateCancelOrderId(slOrderId, tpOrderId);
			}

		}

		// Refund msg.value excess
		if (params.asset == address(0)) {
			uint256 diff = msg.value - vc1 - vc2 - vc3;
			if (diff > 0) {
				payable(msg.sender).sendValue(diff);
			}
		}

	}

	function _submitOrder(OrderStore.Order memory params) internal returns(uint256, uint256) {

		address user = msg.sender;

		// console.log(1);

		// Validations

		require(params.orderType == 0 || params.orderType == 1 || params.orderType == 2, "!order-type");

		if (params.orderType != 0) {
			require(params.price > 0, "!price");
		}

		// console.log(2);

		AssetStore.Asset memory asset = assetStore.get(params.asset);
		require(asset.minSize > 0, "!asset-exists");
		require(params.size >= asset.minSize, "!min-size");

		// console.log(3);

		MarketStore.Market memory market = marketStore.get(params.market);
		require(market.maxLeverage > 0, "!market-exists");
		require(!market.isClosed, "!market-closed");

		// console.log(4);

		require(!riskStore.isAddressBanned(user), "!banned-user");
		require(!riskStore.isAddressBannedForMarket(user, params.market), "!banned-user-market");

		// console.log(5);

		if (params.expiry > 0) {
			require(params.expiry >= block.timestamp, "!expiry-value");
			uint256 ttl = params.expiry - block.timestamp;
			require(
				params.orderType == 0 && ttl <= orderStore.maxMarketOrderTTL() ||
				ttl <= orderStore.maxTriggerOrderTTL()
			, "!max-expiry");
		}

		// console.log(6);

		if (params.cancelOrderId > 0) {
			require(orderStore.isUserOrder(params.cancelOrderId, user), "!user-oco");
		}

		// console.log(7);

		uint256 originalFee = params.size * market.fee / BPS_DIVIDER;
		uint256 feeRebateBps = rebateStore.getUserRebate(user);
		uint256 referralRebateBps = referralStore.getRebateForUser(user);
		uint256 feeWithRebate = originalFee * (BPS_DIVIDER - feeRebateBps - referralRebateBps) / BPS_DIVIDER;
		uint256 valueConsumed;

		if (params.isReduceOnly) {
			params.margin = 0;
			// Existing position is checked on execution so TP/SL can be submitted as reduce-only alongside a non-executed order
			// In this case, valueConsumed is zero as margin is zero and fee is taken from the order's margin 
		} else {
			require(!marketStore.isGlobalReduceOnly(), "!global-reduce-only");
			require(!market.isReduceOnly, "!market-reduce-only");
			require(params.margin > 0, "!margin");

			uint256 leverage = UNIT * params.size / params.margin;
			require(leverage >= UNIT, "!min-leverage");
			require(leverage <= market.maxLeverage * UNIT, "!max-leverage");

			// console.log(71);
			// Check against max OI if it's not reduce-only. this is not completely fail safe as user can place many consecutive market orders of smaller size and get past the max OI limit here, because OI is not updated until oracle picks up the order. That is why maxOI is checked on processing as well, which is fail safe. This check is more of preemptive for user to not submit an order
			riskStore.checkMaxOI(params.asset, params.market, params.size);
			// console.log(72);

			// Transfer fee and margin to store
			valueConsumed = params.margin + feeWithRebate;

			if (params.asset == address(0)) {
				fundStore.transferIn{value: valueConsumed}(params.asset, user, valueConsumed);
			} else {
				fundStore.transferIn(params.asset, user, valueConsumed);
			}

			// console.log(73);
		}

		// console.log(8);

		// Add order to store

		params.user = user;
		params.fee = feeWithRebate;
		params.timestamp = block.timestamp;

		uint256 orderId = orderStore.add(params);

		// console.log(9);

		emit OrderCreated(
			orderId,
			user,
			params.asset,
			params.market,
			params.isLong,
			params.margin,
			params.size,
			params.price,
			params.fee,
			params.orderType,
			params.isReduceOnly,
			params.expiry,
			params.cancelOrderId
		);

		return (orderId, valueConsumed);

	}

	function cancelOrder(uint256 orderId) external ifNotPaused {
		OrderStore.Order memory order = orderStore.get(orderId);
		require(order.size > 0, "!order");
		require(order.user == msg.sender, "!user");
		_cancelOrder(orderId, "by-user");
	}

	function cancelOrders(uint256[] calldata orderIds) external ifNotPaused {
		for (uint256 i = 0; i < orderIds.length; i++) {
			OrderStore.Order memory order = orderStore.get(orderIds[i]);
			if (order.size > 0 && order.user == msg.sender) {
				_cancelOrder(orderIds[i], "by-user");
			}
		}
	}

	function cancelOrderGov(uint256 orderId) external onlyGov {
		_cancelOrder(orderId, "by-gov");
	}

	// Can be used for expired orders / cleaning
	function cancelOrdersGov(uint256[] calldata orderIds) external onlyGov {
		for (uint256 i = 0; i < orderIds.length; i++) {
			_cancelOrder(orderIds[i], "by-gov-clearing");
		}
	}

	function cancelOrder(
		uint256 orderId, 
		string memory reason
	) external onlyContract {
		_cancelOrder(orderId, reason);
	}

	function cancelOrders(
		uint256[] calldata orderIds, 
		string[] calldata reasons
	) external onlyContract {
		for (uint256 i = 0; i < orderIds.length; i++) {
			_cancelOrder(orderIds[i], reasons[i]);
		}
	}

	function _cancelOrder(uint256 orderId, string memory reason) internal {

		OrderStore.Order memory order = orderStore.get(orderId);
		if (order.size == 0) return;

		fundStore.transferOut(order.asset, order.user, order.margin + order.fee);
		orderStore.remove(orderId);
		
		emit OrderCancelled(
			orderId, 
			order.user, 
			reason
		);

	}

}