// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/Governance.sol";
import "../src/Staking.sol";
import "../src/GovToken.sol";

contract GovernanceTest is Test {
    GovToken token;
    Staking staking;
    Governance governance;
    address alice = address(0x1);

    function setUp() public {
        token = new GovToken();
        staking = new Staking(address(token));
        governance = new Governance(address(staking), address(0x123)); // Using a sample treasury address

        // Fund Alice
        token.transfer(alice, 1000 ether);

        vm.startPrank(alice);
        token.approve(address(staking), 500 ether);
        staking.stake(500 ether);
        vm.stopPrank();
    }

    function testCreateAndVoteProposal() public {
        vm.startPrank(alice);

        // Create a proposal to toggle DAO state (by passing 0 value and address(0))
        governance.createProposal("Toggle DAO State", Governance.ActionType.ToggleDAO, address(0), 0, "", 100);
        uint256 proposalId = 0; // First proposal has ID 0

        // Vote in favor
        governance.vote(proposalId, true);

        // Fast forward to after voting deadline (101 blocks later to be safe)
        vm.roll(block.number + 101);

        // Stop the current prank
        vm.stopPrank();

        // Get the current DAO state
        bool wasActive = governance.daoActive();

        // Execute the proposal as Alice
        vm.prank(alice);
        governance.executeProposal(proposalId);

        // Verify the DAO state was toggled
        assertEq(governance.daoActive(), !wasActive, "DAO state should be toggled");
    }
}
