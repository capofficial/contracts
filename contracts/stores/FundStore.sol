// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../utils/Roles.sol";

contract FundStore is Roles {

	using SafeERC20 for IERC20;
    using Address for address payable;

	constructor(RoleStore rs) Roles(rs) {}

	function transferIn(address asset, address from, uint256 amount) external payable onlyContract {
    	if (amount == 0 || asset == address(0)) return;
		IERC20(asset).safeTransferFrom(from, address(this), amount);
	}

	// !! orGov maintained for private beta only
	function transferOut(address asset, address to, uint256 amount) external onlyContractOrGov {
		if (amount == 0 || to == address(0)) return;
		if (asset == address(0)) {
			payable(to).sendValue(amount);
		} else {
			IERC20(asset).safeTransfer(to, amount);
		}
	}

	// Receive ETH

	fallback() external payable {}
	receive() external payable {}

}