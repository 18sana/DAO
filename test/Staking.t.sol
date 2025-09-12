// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/Staking.sol";
import "../src/GovToken.sol";

contract StakingTest is Test {
    GovToken token;
    Staking staking;
    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public {
        // Deploy token
        token = new GovToken();

        // Deploy staking contract
        staking = new Staking(address(token));

        // Fund users with tokens
        token.transfer(alice, 1000 ether);
        token.transfer(bob, 1000 ether);

        // Fund staking contract for rewards
        token.transfer(address(staking), 5000 ether);
    }

    function testStakeAndUnstake() public {
        vm.startPrank(alice);

        // Approve staking contract
        token.approve(address(staking), 500 ether);

        // Stake tokens
        staking.stake(500 ether);

        uint256 stakedAmount = staking.stakedAmount(alice);
        assertEq(stakedAmount, 500 ether, "Stake amount incorrect");

        // Unstake
        staking.unstake(200 ether);

        stakedAmount = staking.stakedAmount(alice);
        assertEq(stakedAmount, 300 ether, "Unstake amount incorrect");

        vm.stopPrank();
    }

    function testRewardsAccrual() public {
        vm.startPrank(bob);

        token.approve(address(staking), 500 ether);
        staking.stake(500 ether);

        // Move forward some blocks to accrue rewards
        vm.roll(block.number + 10);

        // Claim rewards
        uint256 balanceBefore = token.balanceOf(bob);
        staking.claimRewards();
        uint256 balanceAfter = token.balanceOf(bob);
        assertGt(balanceAfter - balanceBefore, 0, "Rewards not claimed");

        vm.stopPrank();
    }
}
