// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Staking Contract for Governance Tokens
contract Staking {
    IERC20 public govToken;

    struct Staker {
        uint256 amount;        // tokens staked
        uint256 rewardDebt;    // unclaimed rewards
        uint256 lastBlock;     // last block when user interacted
    }

    address public governance; // governance contract address 
    uint256 public rewardRate = 1e18; // 1 GOV per block 
    
    mapping(address => Staker) private stakers;
    mapping(address => uint256) public lockedUntil; // block number until which user's actions are locked
   

    //EVENTS
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 reward);
    event RewardsClaimed(address indexed user, uint256 reward);
    event Locked(address indexed user, uint256 untilBlock);
    event Unlocked(address indexed user);
    event Slashed(address indexed user, uint256 amount, address indexed to);

    //MODIFIERSß
    modifier onlyGovernance() {
        require(msg.sender == governance, "Only governance");
        _;
    }

    constructor(address _govToken) {
        govToken = IERC20(_govToken);
    }

    /// @notice Governance contract sets itself 
    function setGovernance(address _gov) external {
        require(governance == address(0), "Governance already set");
        require(_gov != address(0), "zero");
        governance = _gov;
    }

    /// @notice Stake governance tokens
    function stake(uint256 _amount) external {
        require(_amount > 0, "Cannot stake 0");
        _updateRewards(msg.sender);

        govToken.transferFrom(msg.sender, address(this), _amount);

        stakers[msg.sender].amount += _amount;
        stakers[msg.sender].lastBlock = block.number;

        emit Staked(msg.sender, _amount);
    }

    /// @notice Unstake tokens + claim rewards
    function unstake(uint256 _amount) external {
        Staker storage user = stakers[msg.sender];
        require(user.amount >= _amount, "Not enough staked");
        require(block.number > lockedUntil[msg.sender], "Stake locked during vote");

        _updateRewards(msg.sender);

        user.amount -= _amount;
        uint256 reward = user.rewardDebt;
        user.rewardDebt = 0;
        user.lastBlock = block.number;

        govToken.transfer(msg.sender, _amount + reward);

        emit Unstaked(msg.sender, _amount, reward);
        if (reward > 0) {
            emit RewardsClaimed(msg.sender, reward);
        }
    }

    /// @notice Claim only rewards
    function claimRewards() external {
        require(block.number > lockedUntil[msg.sender], "Rewards locked during vote");

        _updateRewards(msg.sender);
        uint256 reward = stakers[msg.sender].rewardDebt;
        require(reward > 0, "No rewards");

        stakers[msg.sender].rewardDebt = 0;
        govToken.transfer(msg.sender, reward);

        emit RewardsClaimed(msg.sender, reward);
    }

    /// @dev Internal reward update
    function _updateRewards(address _user) internal {
        Staker storage user = stakers[_user];
        if (user.amount > 0) {
            uint256 blocksPassed = block.number - user.lastBlock;
            uint256 pending = (user.amount * rewardRate * blocksPassed) / 1e18;
            user.rewardDebt += pending;
        }
        user.lastBlock = block.number;
    }

    /// @notice View pending rewards without claiming
    function pendingRewardsOf(address _user) external view returns (uint256) {
        Staker storage user = stakers[_user];
        if (user.amount == 0) return user.rewardDebt;
        uint256 blocksPassed = block.number - user.lastBlock;
        uint256 pending = (user.amount * rewardRate * blocksPassed) / 1e18;
        return user.rewardDebt + pending;
    }

    /// @notice Get staked amount of a user
    function stakedAmount(address _user) external view returns (uint256) {
        return stakers[_user].amount;
    }

    /// @notice Lock a user's stake until given block (used by Governance when proposer creates or when voter votes)
    function lockUntil(address _user, uint256 _untilBlock) external onlyGovernance {
        if (_untilBlock > lockedUntil[_user]) {
            lockedUntil[_user] = _untilBlock;
            emit Locked(_user, _untilBlock);
        }
    }

    /// @notice Unlock immediately (used by Governance on proposal cancellation)
    function unlock(address _user) external onlyGovernance {
        if (lockedUntil[_user] != 0) {
            lockedUntil[_user] = 0;
            emit Unlocked(_user);
        }
    }

    /// @notice Slash a user's stake (penalty if governance decides). Amount is deducted from staked principal first, then from rewardDebt if needed.
    /// @param _user the user to slash
    /// @param _amount amount to slash (in tokens)
    /// @param _to recipient (dao treasury)
    function slash(address _user, uint256 _amount, address _to) external onlyGovernance {
        Staker storage s = stakers[_user];
        uint256 remaining = _amount;
        uint256 deducted = 0;

        // take from staked amount first
        if (s.amount >= remaining) {
            s.amount -= remaining;
            deducted = _amount;
            remaining = 0;
        } else {
            deducted = s.amount;
            remaining -= s.amount;
            s.amount = 0;
        }

        // then take from rewardDebt
        if (remaining > 0) {
            if (s.rewardDebt >= remaining) {
                s.rewardDebt -= remaining;
                deducted += remaining;
                remaining = 0;
            } else {
                deducted += s.rewardDebt;
                remaining -= s.rewardDebt;
                s.rewardDebt = 0;
            }
        }

        // transfer deducted (slashed) tokens to recipient (if contract has enough balance)
        if (deducted > 0) {
            uint256 bal = govToken.balanceOf(address(this));
            uint256 toTransfer = deducted;
            if (toTransfer > bal) {
                toTransfer = bal; // transfer as much as available
            }
            if (toTransfer > 0) {
                govToken.transfer(_to, toTransfer);
            }
            emit Slashed(_user, toTransfer, _to);
        }
    }
}
