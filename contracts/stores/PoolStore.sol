// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../utils/Roles.sol";

contract PoolStore is Roles {

	using SafeERC20 for IERC20;

	uint256 public bufferPayoutPeriod = 7 days;

	mapping(address => uint256) private clpSupply; // asset => clp supply
    mapping(address => uint256) private balances; // asset => balance
    mapping(address => mapping(address => uint256)) private userClpBalances; // asset => account => clp amount
	mapping(address => mapping(address => uint256)) private lastDeposited; // asset => account => timestamp

	mapping(address => uint256) private bufferBalances; // asset => balance
	mapping(address => uint256) private lastPaid; // asset => timestamp

	mapping(address => uint256) private withdrawalFees; // asset => bps

    constructor(RoleStore rs) Roles(rs) {}

    // Setters

    function setBufferPayoutPeriod(uint256 time) external onlyGov {
		bufferPayoutPeriod = time;
	}

	function setWithdrawalFee(address asset, uint256 bps) external onlyGov {
		withdrawalFees[asset] = bps;
	}

	function setLastDeposited(address asset, address user, uint256 timestamp) external onlyContract {
		lastDeposited[asset][user] = timestamp;
	}

	function incrementBalance(address asset, uint256 amount) external onlyContract {
		balances[asset] += amount;
	}

	function decrementBalance(address asset, uint256 amount) external onlyContract {
		balances[asset] = balances[asset] <= amount ? 0 : balances[asset] - amount;
	}

	function incrementBufferBalance(address asset, uint256 amount) external onlyContract {
		bufferBalances[asset] += amount;
	}

	function decrementBufferBalance(address asset, uint256 amount) external onlyContract {
		bufferBalances[asset] = bufferBalances[asset] <= amount ? 0 : bufferBalances[asset] - amount;
	}

	function setLastPaid(address asset, uint256 timestamp) external onlyContract {
		lastPaid[asset] = timestamp;
	}

	function incrementClpSupply(address asset, uint256 amount) external onlyContract {
		clpSupply[asset] += amount;
	}

	function decrementClpSupply(address asset, uint256 amount) external onlyContract {
		clpSupply[asset] = clpSupply[asset] <= amount ? 0 : clpSupply[asset] - amount;
	}

	function incrementUserClpBalance(address asset, address user, uint256 amount) external onlyContract {
		userClpBalances[asset][user] += amount;
	}

	function decrementUserClpBalance(address asset, address user, uint256 amount) external onlyContract {
		userClpBalances[asset][user] = userClpBalances[asset][user] <= amount ? 0 : userClpBalances[asset][user] - amount;
	}

    // Getters

    function getWithdrawalFee(address asset) external view returns(uint256) {
		return withdrawalFees[asset];
	}
    
	function getBalance(address asset) external view returns(uint256) {
		return balances[asset];
	}

	function getAvailable(address asset) external view returns(uint256) {
		return balances[asset] + bufferBalances[asset];
	}

	function getBalances(address[] calldata _assets) external view returns(uint256[] memory _balances) {
		uint256 length = _assets.length;
		_balances = new uint256[](length);
		for (uint256 i = 0; i < length; i++) {
			_balances[i] = balances[_assets[i]];
		}
		return _balances;
	}

	function getUserBalance(address asset, address account) public view returns(uint256) {
		if (clpSupply[asset] == 0) return 0;
		return userClpBalances[asset][account] * balances[asset] / clpSupply[asset];
	}

	function getUserBalances(address[] calldata _assets, address account) external view returns(uint256[] memory _balances) {
		uint256 length = _assets.length;
		_balances = new uint256[](length);
		for (uint256 i = 0; i < length; i++) {
			_balances[i] = getUserBalance(_assets[i], account);
		}
		return _balances;
	}

	function getClpSupply(address asset) public view returns(uint256) {
		return clpSupply[asset];
	}

	function getUserClpBalance(address asset, address account) public view returns(uint256) {
		return userClpBalances[asset][account];
	}

	function getLastDeposited(address asset, address user) external view returns(uint256) {
		return lastDeposited[asset][user];
	}

	function getBufferBalance(address asset) external view returns(uint256) {
		return bufferBalances[asset];
	}

	function getLastPaid(address asset) external view returns(uint256) {
		return lastPaid[asset];
	}
	
}