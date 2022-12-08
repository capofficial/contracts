// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DataStore.sol";
import "./PoolStore.sol";
import "./PositionStore.sol";

import "../utils/Roles.sol";

contract RiskStore is Roles {

	uint256 public constant BPS_DIVIDER = 10000;

	// Market Risk Measures
	uint256 public marketHourlyDecay = 416; // bps = 4.16% hourly, disappears after 24 hours
	mapping(string => mapping(address => int256)) private marketProfitTracker; // market => asset => amount (amortized / time-weigthed)
	mapping(string => mapping(address => uint256)) private marketProfitLimit; // market => asset => bps (as % of pool + buffer balance)
	mapping(string => mapping(address => uint256)) private marketLastChecked; // market => asset => timestamp
	mapping(string => mapping(address => uint256)) private maxOI; // market => asset => amount

	// Pool Risk Measures
	uint256 public poolHourlyDecay = 416; // bps = 4.16% hourly, disappears after 24 hours
	mapping(address => int256) private poolProfitTracker; // asset => amount (amortized)
	mapping(address => uint256) private poolProfitLimit; // asset => bps
	mapping(address => uint256) private poolLastChecked; // asset => timestamp

	// User Risk Measures
	mapping(string => mapping(address => bool)) private bannedAddressesForMarket;
	mapping(address => bool) private bannedAddresses;

	DataStore public DS;

	constructor(RoleStore rs, DataStore ds) Roles(rs) {
		DS = ds;
	}

	// setters
	function setMaxOI(string memory market, address asset, uint256 amount) external onlyGov {
		maxOI[market][asset] = amount;
	}
	function setMarketHourlyDecay(uint256 bps) external onlyGov {
		marketHourlyDecay = bps;
	}
	function setPoolHourlyDecay(uint256 bps) external onlyGov {
		poolHourlyDecay = bps;
	}
	function setMarketProfitLimit(string memory market, address asset, uint256 bps) external onlyGov {
		marketProfitLimit[market][asset] = bps;
	}
	function setPoolProfitLimit(address asset, uint256 bps) external onlyGov {
		poolProfitLimit[asset] = bps;
	}
	function banAddressForMarket(address user, string memory market, bool isBanned) external onlyGov {
		bannedAddressesForMarket[market][user] = isBanned;
	}
	function banAddress(address user, bool isBanned) external onlyGov {
		bannedAddresses[user] = isBanned;
	}

	// Checkers

	function checkMaxOI(address asset, string memory market, uint256 size) external view {
		uint256 OI = PositionStore(DS.getAddress('PositionStore')).getOI(asset, market);
		uint256 _maxOI = maxOI[market][asset];
		if (_maxOI > 0 && OI + size > _maxOI) revert("!max-oi");
	}

	function checkMarketRisk(string memory market, address asset, int256 pnl) external onlyContract {
		
		// pnl > 0 means trader win

		uint256 poolAvailable = PoolStore(DS.getAddress('PoolStore')).getAvailable(asset);
		int256 profitTracker = getMarketProfitTracker(market, asset) + pnl;

		marketProfitTracker[market][asset] = profitTracker;
		marketLastChecked[market][asset] = block.timestamp;
		
		uint256 profitLimit = marketProfitLimit[market][asset];
		
		if (poolAvailable == 0 || profitLimit == 0 || profitTracker <= 0) return;

		require(uint256(profitTracker) < profitLimit * poolAvailable / BPS_DIVIDER, "!market-risk");
	
	}

	function checkPoolRisk(address asset, int256 pnl) external onlyContract {

		// pnl > 0 means trader win

		uint256 poolAvailable = PoolStore(DS.getAddress('PoolStore')).getAvailable(asset);
		int256 profitTracker = getPoolProfitTracker(asset) + pnl;

		poolProfitTracker[asset] = profitTracker;
		poolLastChecked[asset] = block.timestamp;
		
		uint256 profitLimit = poolProfitLimit[asset];
		
		if (profitLimit == 0 || profitTracker <= 0) return;
		
		require(uint256(profitTracker) < profitLimit * poolAvailable / BPS_DIVIDER, "!pool-risk");

	}

	// getters

	function getMaxOI(string memory market, address asset) external view returns(uint256) {
		return maxOI[market][asset];
	}

	function getMarketProfitTracker(string memory market, address asset) public view returns(int256) {
		int256 profitTracker = marketProfitTracker[market][asset];
		uint256 lastCheckedHourId = marketLastChecked[market][asset] / (1 hours);
		uint256 currentHourId = block.timestamp / (1 hours);
		if (currentHourId > lastCheckedHourId) {
			uint256 hoursPassed = currentHourId - lastCheckedHourId;
			if (hoursPassed >= BPS_DIVIDER / marketHourlyDecay) {
				profitTracker = 0;
			} else {
				for (uint256 i = 0; i < hoursPassed; i++) {
					profitTracker *= (int256(BPS_DIVIDER) - int256(marketHourlyDecay)) / int256(BPS_DIVIDER);
				}
			}
		}
		return profitTracker;
	}

	function getPoolProfitTracker(address asset) public view returns(int256) {
		int256 profitTracker = poolProfitTracker[asset];
		uint256 lastCheckedHourId = poolLastChecked[asset] / (1 hours);
		uint256 currentHourId = block.timestamp / (1 hours);
		if (currentHourId > lastCheckedHourId) {
			uint256 hoursPassed = currentHourId - lastCheckedHourId;
			if (hoursPassed >= BPS_DIVIDER / poolHourlyDecay) {
				profitTracker = 0;
			} else {
				for (uint256 i = 0; i < hoursPassed; i++) {
					profitTracker *= (int256(BPS_DIVIDER) - int256(poolHourlyDecay)) / int256(BPS_DIVIDER);
				}
			}
		}
		return profitTracker;
	}

	function getMarketProfitLimit(string memory market, address asset) external view returns(uint256) {
		return marketProfitLimit[market][asset];
	}

	function getPoolProfitLimit(address asset) external view returns(uint256) {
		return poolProfitLimit[asset];
	}

	function isAddressBannedForMarket(address user, string memory market) external view returns(bool) {
		return bannedAddressesForMarket[market][user];
	}

	function isAddressBanned(address user) external view returns(bool) {
		return bannedAddresses[user];
	}

	function getParams(address asset, string memory market) external view returns(uint256,uint256,int256,uint256,int256,uint256) {
		uint256 poolAvailable = PoolStore(DS.getAddress('PoolStore')).getAvailable(asset);
		return (
			poolAvailable, 
			maxOI[market][asset], 
			getMarketProfitTracker(market, asset), 
			marketProfitLimit[market][asset], 
			getPoolProfitTracker(asset), 
			poolProfitLimit[asset]
		);
	}

}