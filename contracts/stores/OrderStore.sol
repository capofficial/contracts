// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../utils/Roles.sol";

contract OrderStore is Roles {

	using EnumerableSet for EnumerableSet.UintSet;

	struct Order {
		uint256 orderId;
		address user;
		address asset;
		string market;
		uint256 margin;
		uint256 size;
		uint256 price;
		uint256 fee;
		bool isLong;
		uint8 orderType; // 0 = market, 1 = limit, 2 = stop
		bool isReduceOnly;
		uint256 timestamp;
		uint256 expiry;
		uint256 cancelOrderId;
	}

	uint256 public oid; // incremental order id
	mapping(uint256 => Order) private orders; // order id => Order
	mapping(address => EnumerableSet.UintSet) private userOrderIds; // user => [order ids..]
	EnumerableSet.UintSet private marketOrderIds; // [order ids..]
	EnumerableSet.UintSet private triggerOrderIds; // [order ids..]

	bool public areNewOrdersPaused;
	bool public isProcessingPaused;
	uint256 public maxMarketOrderTTL = 5 minutes;
	uint256 public maxTriggerOrderTTL = 180 days;
	uint256 public chainlinkCooldown = 5 minutes;
	uint256 public minOracleBalance = 1 ether;

	constructor(RoleStore rs) Roles(rs) {}

	// Setters

	function setAreNewOrdersPaused(bool b) external onlyGov {
		areNewOrdersPaused = b;
	}
	function setIsProcessingPaused(bool b) external onlyGov {
		isProcessingPaused = b;
	}
	function setMaxMarketOrderTTL(uint256 amount) external onlyGov {
		maxMarketOrderTTL = amount;
	}
	function setMaxTriggerOrderTTL(uint256 amount) external onlyGov {
		maxTriggerOrderTTL = amount;
	}
	function setChainlinkCooldown(uint256 amount) external onlyGov {
		chainlinkCooldown = amount;
	}
	function setMinOracleBalance(uint256 amount) external onlyGov {
		minOracleBalance = amount;
	}

	function add(Order memory order) external onlyContract returns(uint256) {
		uint256 nextOrderId = ++oid;
		order.orderId = nextOrderId;
		orders[nextOrderId] = order;
		userOrderIds[order.user].add(nextOrderId);
		if (order.orderType == 0) {
			marketOrderIds.add(order.orderId);
		} else {
			triggerOrderIds.add(order.orderId);
		}
		return nextOrderId;
	}

	function remove(uint256 orderId) external onlyContract {
		Order memory order = orders[orderId];
		if (order.size == 0) return;
		userOrderIds[order.user].remove(orderId);
		marketOrderIds.remove(orderId);
		triggerOrderIds.remove(orderId);
		delete orders[orderId];
	}

	function updateCancelOrderId(uint256 orderId, uint256 cancelOrderId) external onlyContract {
		Order storage order = orders[orderId];
		order.cancelOrderId = cancelOrderId;
	}

	// Getters

	function get(uint256 orderId) public view returns(Order memory) {
		return orders[orderId];
	}

	function getMany(uint256[] calldata orderIds) external view returns(Order[] memory _orders) {
		uint256 length = orderIds.length;
		_orders = new Order[](length);
		for (uint256 i = 0; i < length; i++) {
			_orders[i] = orders[orderIds[i]];
		}
		return _orders;
	}

	function getMarketOrders(uint256 length) external view returns(Order[] memory _orders) {
		uint256 _length = marketOrderIds.length();
		if (length > _length) length = _length;
		_orders = new Order[](length);
		for (uint256 i = 0; i < length; i++) {
			_orders[i] = orders[marketOrderIds.at(i)];
		}
		return _orders;
	}

	function getTriggerOrders(uint256 length, uint256 offset) external view returns(Order[] memory _orders) {
		uint256 _length = triggerOrderIds.length();
		if (length > _length) length = _length;
		_orders = new Order[](length);
		for (uint256 i = offset; i < length + offset; i++) {
			_orders[i] = orders[triggerOrderIds.at(i)];
		}
		return _orders;
	}

	function getUserOrders(address user) external view returns(Order[] memory _orders) {
		uint256 length = userOrderIds[user].length();
		_orders = new Order[](length);
		for (uint256 i = 0; i < length; i++) {
			_orders[i] = orders[userOrderIds[user].at(i)];
		}
		return _orders;
	}

	function getMarketOrderCount() external view returns (uint256) {
		return marketOrderIds.length();
	}

	function getTriggerOrderCount() external view returns (uint256) {
		return triggerOrderIds.length();
	}

	function getUserOrderCount(address user) external view returns (uint256) {
		return userOrderIds[user].length();
	}

	function isUserOrder(uint256 orderId, address user) external view returns (bool) {
		return userOrderIds[user].contains(orderId);
	}

}