// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DataStore.sol";

import "../utils/Roles.sol";

contract ReferralStore is Roles {

	uint256 public constant BPS_DIVIDER = 10000;

	uint256 public referrerShareBps = 1000; 
	uint256 public referredRebateBps = 1000;

	uint256 public referrerShareExpiresAfter;
	uint256 public referredRebateExpiresAfter;

	mapping(address => string) private latestReferralCode; // referrer => code
	mapping(string => address) private referrersByCode; // code => referrer
	mapping(address => address) private referredBy; // referred => referrer
	mapping(address => uint256) private referredAt; // referred => timestamp

	constructor(RoleStore rs) Roles(rs) {
	}
	
	function setReferrerShareBps(uint256 _referrerShareBps) external onlyGov {
		referrerShareBps = _referrerShareBps;
	}

	function setReferredRebateBps(uint256 _referredRebateBps) external onlyGov {
		referredRebateBps = _referredRebateBps;
	}

	function setReferrerShareExpiresAfter(uint256 _referrerShareExpiresAfter) external onlyGov {
		referrerShareExpiresAfter = _referrerShareExpiresAfter;
	}

	function setReferredRebateExpiresAfter(uint256 _referredRebateExpiresAfter) external onlyGov {
		referredRebateExpiresAfter = _referredRebateExpiresAfter;
	}

	function setReferralCode(string memory code) external {
		// this allows a referrer to set many codes
		require(referrersByCode[code] == address(0) || referrersByCode[code] == msg.sender, "!exists");
		referrersByCode[code] = msg.sender;
		latestReferralCode[msg.sender] = code;
	}

	function setReferrer(string memory refCode) external {
		address referred = msg.sender;
		address referrer = referrersByCode[refCode];
		if (referrer == address(0) || referredBy[referred] != address(0)) return;
		referredBy[referred] = referrer;
		referredAt[referred] = block.timestamp;
	}

	// -- Getters -- //

	function getReferredBy(address user) external view returns(address) {
		return referredBy[user];
	}

	function getReferredAt(address user) external view returns(uint256) {
		return referredAt[user];
	}

	function getReferrerShareForUser(address user) external view returns(uint256) {
		if (referredBy[user] == address(0)) return 0;
		if (referrerShareExpiresAfter > 0 && referredAt[user] < block.timestamp - referrerShareExpiresAfter) return 0;
		return referrerShareBps;
	}

	function getRebateForUser(address user) external view returns(uint256) {
		if (referredBy[user] == address(0)) return 0;
		if (referredRebateExpiresAfter > 0 && referredAt[user] < block.timestamp - referredRebateExpiresAfter) return 0;
		return referredRebateBps;
	}

	function getReferralCode(address user) external view returns(string memory) {
		return latestReferralCode[user];
	}

}