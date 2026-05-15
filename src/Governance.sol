// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./Staking.sol";

contract Governance {
    Staking public stakingContract;
    address public daoTreasury;
    bool public daoActive = true;

    uint256 public minStakeToPropose = 1 ether; // Minimum stake to create a proposal
    uint256 public maxProposalDuration = 500;   // Max duration in blocks
    uint256 public minDescriptionLength = 10;
    uint256 public maxDescriptionLength = 500;

    enum ActionType {
        ToggleDAO,
        ETHTransfer,
        CallContract,
        CustomUpdate
    }

    struct Proposal {
        string description;
        bytes data;
        uint256 deadline;
        uint256 value;
        uint256 votesFor;
        uint256 votesAgainst;
        address proposer;
        address target;
        bool executed;
        bool cancelled;   
        ActionType action;
        mapping(address => bool) voted;
    }

    Proposal[] private proposals;

    // EVENTS
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string description,
        uint256 deadline,
        ActionType action
    );
    event Voted(
        uint256 indexed proposalId,
        address indexed voter,
        bool support,
        uint256 votingPower
    );
    event ProposalExecuted(uint256 indexed proposalId, bool success);
    event ProposalCancelled(uint256 indexed proposalId, address cancelledBy); 
    event ProposalSlashed(uint256 indexed proposalId, address proposer, uint256 amount);

    // CONSTRUCTOR
    constructor(address _stakingContract, address _daoTreasury) {
        stakingContract = Staking(_stakingContract);
        daoTreasury = _daoTreasury;
        stakingContract.setGovernance(address(this));
    }

    // MODIFIERS
    modifier onlyEligibleProposer() {
        require(
            stakingContract.stakedAmount(msg.sender) >= minStakeToPropose,
            "Not enough stake to propose"
        );
        _;
    }

    modifier onlyMember() {
        uint256 power = stakingContract.stakedAmount(msg.sender);
        require(power > 0, "Not a DAO member");
        _;
    }

    // CREATE PROPOSAL
    function createProposal(
        string memory _desc,
        ActionType _action,
        address _target,
        uint256 _value,
        bytes memory _data,
        uint256 _durationBlocks
    ) external onlyEligibleProposer {
        require(
            bytes(_desc).length >= minDescriptionLength &&
                bytes(_desc).length <= maxDescriptionLength,
            "Invalid description length"
        );
        require(
            _durationBlocks > 0 && _durationBlocks <= maxProposalDuration,
            "Invalid duration"
        );

        Proposal storage p = proposals.push();
        p.description = _desc;
        p.deadline = block.number + _durationBlocks;
        p.proposer = msg.sender;
        p.action = _action;
        p.target = _target;
        p.value = _value;
        p.data = _data;
        p.executed = false;
        p.cancelled = false;

        //  lock proposer's stake till proposal deadline
        stakingContract.lockUntil(msg.sender, p.deadline);

        emit ProposalCreated(
            proposals.length - 1,
            msg.sender,
            _desc,
            p.deadline,
            _action
        );
    }

    // VOTE
    function vote(uint256 _proposalId, bool _support) public onlyMember {
        Proposal storage p = proposals[_proposalId];
        require(!p.cancelled, "Proposal cancelled");
        require(block.number <= p.deadline, "Voting ended");
        require(!p.voted[msg.sender], "Already voted");

        uint256 votingPower = stakingContract.stakedAmount(msg.sender) +
            stakingContract.pendingRewardsOf(msg.sender);
        require(votingPower > 0, "No voting power");

        if (_support) {
            p.votesFor += votingPower;
        } else {
            p.votesAgainst += votingPower;
        }

        p.voted[msg.sender] = true;

        //  lock voter stake till deadline
        stakingContract.lockUntil(msg.sender, p.deadline);

        emit Voted(_proposalId, msg.sender, _support, votingPower);
    }

    // EXECUTE PROPOSAL
    function executeProposal(uint256 _proposalId) external {
        Proposal storage p = proposals[_proposalId];
        require(!p.cancelled, "Proposal cancelled");
        require(block.number > p.deadline, "Voting not ended");
        require(!p.executed, "Already executed");

        bool success = false;

        if (p.votesFor > p.votesAgainst) {
            if (p.action == ActionType.ToggleDAO) {
                daoActive = !daoActive;
                success = true;
            } else if (p.action == ActionType.ETHTransfer) {
                require(
                    p.value <= address(this).balance,
                    "Insufficient balance"
                );
                (success, ) = p.target.call{value: p.value}("");
                require(success, "Proposal execution failed");
            } else if (
                p.action == ActionType.CallContract ||
                p.action == ActionType.CustomUpdate
            ) {
                (success, ) = p.target.call(p.data);
                require(success, "Proposal execution failed");
            }
        }

        p.executed = true;
        emit ProposalExecuted(_proposalId, success);
    }

    //  CANCEL PROPOSAL
    function cancelProposal(uint256 _proposalId, bool slash) external {
        Proposal storage p = proposals[_proposalId];
        require(!p.executed, "Already executed");
        require(!p.cancelled, "Already cancelled");
        require(
            msg.sender == p.proposer || msg.sender == daoTreasury,
            "Not authorized"
        );

        p.cancelled = true;

        if (slash) {
            // slash 10% of proposer stake
            uint256 staked = stakingContract.stakedAmount(p.proposer);
            uint256 penalty = (staked * 10) / 100;
            stakingContract.slash(p.proposer, penalty, daoTreasury);
            emit ProposalSlashed(_proposalId, p.proposer, penalty);
        }

        emit ProposalCancelled(_proposalId, msg.sender);
    }

    // GETTER
    function getProposal(
        uint256 _proposalId
    )
        external
        view
        returns (
            string memory description,
            uint256 deadline,
            address proposer,
            ActionType action,
            address target,
            uint256 value,
            uint256 votesFor,
            uint256 votesAgainst,
            bool executed,
            bool cancelled
        )
    {
        Proposal storage p = proposals[_proposalId];
        return (
            p.description,
            p.deadline,
            p.proposer,
            p.action,
            p.target,
            p.value,
            p.votesFor,
            p.votesAgainst,
            p.executed,
            p.cancelled
        );
    }

    // FUND DAO
    receive() external payable {}
}
