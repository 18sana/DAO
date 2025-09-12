// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/GovToken.sol";

contract GovTokenTest is Test {
    GovToken token;

    function setUp() public {
        token = new GovToken();
    }

    function testDeployerBalance() public {
        uint256 balance = token.balanceOf(address(this));
        assertEq(balance, 1_000_000 ether); // 1M tokens
    }

    function testInitialSupply() public {
        uint256 total = token.totalSupply();
        assertEq(total, 1_000_000 ether);
    }
}
