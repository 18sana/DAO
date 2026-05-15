// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title GovToken - Governance Token for DAO
/// @notice Fixed supply ERC20 token minted to deployer
contract GovToken is ERC20 {
    constructor() ERC20("Governance Token", "GOV") {
        // Fixed supply = 1,000,000 tokens
        // 1e18 = 1 token (because decimals = 18)
        _mint(msg.sender, 1_000_000 * 1e18);
    }
}
