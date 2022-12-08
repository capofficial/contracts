// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../utils/Roles.sol";

contract StakingStore is Roles {
	
    uint256 public constant UNIT = 10**18;

	uint256 public feeShare = 5000;

    mapping(address => uint256) private balances; // account => cap amount
    uint256 totalSupply; // cap staked

    constructor(RoleStore rs) Roles(rs) {}

    function setFeeShare(uint256 bps) external onlyGov {
    	feeShare = bps;
    }

    // Getters

	function getTotalSupply() public view returns(uint256) {
		return totalSupply;
	}

	function getBalance(address account) public view returns(uint256) {
		return balances[account];
	}

	// Setters

	function incrementSupply(uint256 amount) external onlyContract {
		totalSupply += amount;
	}

	function incrementBalance(address user, uint256 amount) external onlyContract {
		balances[user] += amount;
	}

	function decrementSupply(uint256 amount) external onlyContract {
		totalSupply = totalSupply <= amount ? 0 : totalSupply - amount;
	}

	function decrementBalance(address user, uint256 amount) external onlyContract {
		balances[user] = balances[user] <= amount ? 0 : balances[user] - amount;
	}

	// rewards below

	mapping(address => uint256) private rewardPerTokenSum;
	mapping(address => uint256) private pendingReward;
	mapping(address => mapping(address => uint256)) private previousReward;
	mapping(address => mapping(address => uint256)) private claimableReward;

	// Setters

	function incrementPendingReward(address asset, uint256 amount) external onlyContract {
		pendingReward[asset] += amount;
	}

	function incrementRewardPerToken(address asset) external onlyContract {
		if (totalSupply == 0) return;
		uint256 amount = pendingReward[asset] * UNIT / totalSupply;
		rewardPerTokenSum[asset] += amount;
		pendingReward[asset] = 0;
	}

	function updateClaimableReward(address asset, address user) external onlyContract {
		if (rewardPerTokenSum[asset] == 0) return;
		uint256 amount = balances[user] * (rewardPerTokenSum[asset] - previousReward[asset][user]) / UNIT;
		claimableReward[asset][user] += amount;
		previousReward[asset][user] = rewardPerTokenSum[asset];
	}

	function setClaimableReward(address asset, address user, uint256 amount) external onlyContract {
		claimableReward[asset][user] = amount;
	}

	// Getters

	function getPendingReward(address asset) external view returns(uint256) {
		return pendingReward[asset];
	}

	function getPreviousReward(address asset, address user) external view returns(uint256) {
		return previousReward[asset][user];
	}

	function getRewardPerTokenSum(address asset) external view returns(uint256) {
		return rewardPerTokenSum[asset];
	}

	function getClaimableReward(address asset, address user) external view returns(uint256) {
		return claimableReward[asset][user];
	}


}