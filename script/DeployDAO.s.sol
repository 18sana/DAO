// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/GovToken.sol";
import "../src/Staking.sol";
import "../src/Governance.sol";

contract DeployDAO is Script {
    function run() external {
        vm.startBroadcast();

        //  Deploy GovToken
        GovToken token = new GovToken();
        console.log("GovToken deployed at:", address(token));

        //  Deploy Staking contract
        Staking staking = new Staking(address(token));
        console.log("Staking deployed at:", address(staking));

        // Fund staking contract with some tokens for rewards
        token.transfer(address(staking), 500_000 * 1e18);
        console.log("Staking contract funded for rewards");

        //  Deploy Governance contract
        address treasury = msg.sender; // deployer wallet as treasury
        Governance governance = new Governance(address(staking), treasury);
        console.log("Governance deployed at:", address(governance));

        vm.stopBroadcast();
    }
}
