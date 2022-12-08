// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DataStore.sol";
import "./StakingStore.sol";

import "../utils/Roles.sol";

contract RebateStore is Roles {

	// each market has a rebate weight, default is 100 for eg BTC/USD. Markets like EUR/USD (high leverage, low fee) can have lower rebate weight, whereas small cryptos like ADA can have higher rebate weight. It determines the contribution volume on this market plays in your rebate. rebate weight = market fee in bps / 100

    uint256 public constant UNIT = 10**18;
	uint256 public constant BPS_DIVIDER = 10000;

	// Trading (weighted) volume rebate params
	uint256 public volumeDailyDecay = 333; // bps daily
	uint256 public minVolume = 5 * 10**6; // TODO: make relatively small so everyone starts getting discounts
	uint256 public maxVolume = 50 * 10**6;
	uint256 public minVolumeRebate = 500; // 5%
	uint256 public maxVolumeRebate = 5000; // 50%

	// Staking CAP trading fee rebate params
	uint256 public minStaked = 100;
	uint256 public maxStaked = 2500;
	uint256 public minStakingRebate = 500; // 5%
	uint256 public maxStakingRebate = 2000; // 20%

	// Global rebate params
	uint256 public rebateOverride;

	bool public volumeRebateEnabled = true;
	bool public stakingRebateEnabled = true;

	DataStore public DS;

	mapping(address => uint256) private volumes; // user => weighted volume in USD (decaying)
	mapping(address => uint256) private volumeLastChecked; // user => timestamp

	constructor(RoleStore rs, DataStore ds) Roles(rs) {
		DS = ds;
	}
	
	function setRebatesEnabled(
		bool _volumeRebateEnabled, 
		bool _stakingRebateEnabled
	) external onlyGov {
		volumeRebateEnabled = _volumeRebateEnabled;
		stakingRebateEnabled = _stakingRebateEnabled;
	}

	function setRebateOverride(
		uint256 _rebateOverride
	) external onlyGov {
		rebateOverride = _rebateOverride;
	}

	function setVolumeRebateParams(
		uint256 _volumeDailyDecay,
		uint256 _minVolume,
		uint256 _maxVolume,
		uint256 _minVolumeRebate,
		uint256 _maxVolumeRebate
	) external onlyGov {
		volumeDailyDecay = _volumeDailyDecay;
		minVolume = _minVolume;
		maxVolume = _maxVolume;
		minVolumeRebate = _minVolumeRebate;
		maxVolumeRebate = _maxVolumeRebate;
	}

	function setStakingRebateParams(
		uint256 _minStaked,
		uint256 _maxStaked,
		uint256 _minStakingRebate,
		uint256 _maxStakingRebate
	) external onlyGov {
		minStaked = _minStaked;
		maxStaked = _maxStaked;
		minStakingRebate = _minStakingRebate;
		maxStakingRebate = _maxStakingRebate;
	}

	
	// -- Methods -- //

	function incrementUserVolume(address user, uint256 feeBps, uint256 usdAmount) external onlyContract {
		// amount added in USD
		uint256 weightedAmount = usdAmount * feeBps / 100;
		volumes[user] = getUserVolume(user) + weightedAmount; // decayed volume + amount
	}

	// -- Getters -- //

	function getParams() external view returns(uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256) {
		return (minVolume, maxVolume, minVolumeRebate, maxVolumeRebate, minStaked, maxStaked, minStakingRebate, maxStakingRebate);
	}

	function getUserRebate(address user) public view returns(uint256) {
		if (!volumeRebateEnabled && !stakingRebateEnabled) {
			return 0;
		}
		if (rebateOverride > 0) {
			return rebateOverride;
		}
		uint256 totalRebate;
		if (volumeRebateEnabled) {
			totalRebate += getVolumeRebate(user);
		}
		if (stakingRebateEnabled) {
			totalRebate += getStakingRebate(user);
		}
		return totalRebate;
	}

	function getUserVolume(address user) public view returns(uint256) {

		uint256 userVolume = volumes[user];
		uint256 lastCheckedDayId = volumeLastChecked[user] / (1 days);
		uint256 currentDayId = block.timestamp / (1 days);

		if (currentDayId > lastCheckedDayId) {
			uint256 daysPassed = currentDayId - lastCheckedDayId;
		
			if (daysPassed >= BPS_DIVIDER / volumeDailyDecay) {
				userVolume = 0;
			} else {
				for (uint256 i = 0; i < daysPassed; i++) {
					userVolume *= (BPS_DIVIDER - volumeDailyDecay) / BPS_DIVIDER;
				}
			}
		}

		return userVolume;

	}

	function getVolumeRebate(address user) public view returns(uint256) {
		
		uint256 trailingVolume = getUserVolume(user);
	
		if (trailingVolume < minVolume) {
			return 0;
		}
		if (trailingVolume > maxVolume) {
			trailingVolume = maxVolume;
		}
		return minVolumeRebate + (maxVolumeRebate - minVolumeRebate) * (trailingVolume - minVolume) / (maxVolume - minVolume); // in bps
		/* example
			- 5M trading vol = 500 + (4500) * (0) / 95M = 500 ok
			- 10M trading vol = 500 + 4500 * 5M/95M = 736
			- 50M trading vol = 500 + 4500 * 45/95 = 26.31
			- 100M trading vol = 500 + 4500 * 95/95 = 5000
			Ok
		*/
	}

	function getStakingRebate(address user) public view returns(uint256) {

		// rebate on trading fees from staking CAP
		uint256 capBalance = StakingStore(DS.getAddress('StakingStore')).getBalance(user);

		if (capBalance < minStaked) {
			return 0;
		}
		if (capBalance > maxStaked) {
			capBalance = maxStaked;
		}
		return minStakingRebate + (maxStakingRebate - minStakingRebate) * (capBalance - minStaked) / (maxStaked - minStaked); // in bps

	}

}