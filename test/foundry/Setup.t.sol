// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../contracts/mocks/MockToken.sol";

// Test file, just to see if forge test works

contract SetupTest is Test {   

    MockToken public token;

    function setUp() public {
        token = new MockToken("Mock", "mock", 18);
    }

    function testMint() public {
        token.mint(100 ether);
    }
}
