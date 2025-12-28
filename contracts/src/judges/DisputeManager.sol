// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./JudgeRegistry.sol";
import "../core/Bet.sol";

/**
 * @title DisputeManager
 * @notice Manages dispute resolution for contested bets using judge voting
 * @dev Implements tier-based judge selection and majority voting with appeals
 */
contract DisputeManager is Ownable, ReentrancyGuard {
    // ============ Enums ============

    enum DisputeStatus {
        Active,          // Dispute is active, awaiting votes
        Resolved,        // Dispute resolved, outcome determined
        Appealed,        // Dispute appealed to higher tier
        Expired          // Voting deadline passed
    }

    enum DisputeTier {
        Tier0,  // 0-0.1 ETH equivalent: 1 judge
        Tier1,  // 0.1-1 ETH equivalent: 3 judges
        Tier2   // 1+ ETH equivalent: 5 judges
    }

    // ============ Structs ============

    struct Dispute {
        address betContract;
        address initiator;
        uint64 createdAt;
        uint64 votingDeadline;
        DisputeStatus status;
        DisputeTier tier;
        uint8 judgeCount;
        uint8 votesSubmitted;
        Bet.Outcome finalOutcome;
        bool appealed;
    }

    struct Vote {
        Bet.Outcome outcome;
        uint64 votedAt;
        bool hasVoted;
    }

    struct DisputeConfig {
        uint256 tier0Threshold;     // Max stake for tier 0 (e.g., 100 USDC)
        uint256 tier1Threshold;     // Max stake for tier 1 (e.g., 1000 USDC)
        uint256 votingPeriod;       // Time judges have to vote (e.g., 48 hours)
        uint256 judgeTimeout;       // Timeout for individual judge (e.g., 24 hours)
    }

    // ============ State Variables ============

    JudgeRegistry public immutable judgeRegistry;
    DisputeConfig public config;

    mapping(uint256 => Dispute) public disputes;
    mapping(uint256 => address[]) public disputeJudges;
    mapping(uint256 => mapping(address => Vote)) public votes;
    mapping(uint256 => mapping(Bet.Outcome => uint8)) public voteCount;

    uint256 public totalDisputes;
    uint256 private nonceCounter;

    // ============ Events ============

    event DisputeCreated(
        uint256 indexed disputeId,
        address indexed betContract,
        address indexed initiator,
        DisputeTier tier,
        uint8 judgeCount,
        uint256 deadline,
        uint256 timestamp
    );

    event VoteSubmitted(
        uint256 indexed disputeId,
        address indexed judge,
        Bet.Outcome outcome,
        uint256 timestamp
    );

    event DisputeResolved(
        uint256 indexed disputeId,
        Bet.Outcome finalOutcome,
        uint8 totalVotes,
        uint256 timestamp
    );

    event DisputeAppealed(
        uint256 indexed disputeId,
        uint256 indexed newDisputeId,
        DisputeTier newTier,
        uint256 timestamp
    );

    event JudgeReplaced(
        uint256 indexed disputeId,
        address indexed oldJudge,
        address indexed newJudge,
        uint256 timestamp
    );

    // ============ Errors ============

    error DisputeNotFound();
    error DisputeNotActive();
    error DisputeAlreadyResolved();
    error NotAssignedJudge();
    error AlreadyVoted();
    error VotingPeriodExpired();
    error VotingPeriodNotExpired();
    error InsufficientVotes();
    error CannotAppeal();
    error Unauthorized();

    // ============ Constructor ============

    /**
     * @param _judgeRegistry Address of JudgeRegistry contract
     */
    constructor(address _judgeRegistry) Ownable(msg.sender) {
        require(_judgeRegistry != address(0), "Invalid registry");
        judgeRegistry = JudgeRegistry(_judgeRegistry);

        // Set default configuration
        config = DisputeConfig({
            tier0Threshold: 100 * 10**6,    // 100 USDC
            tier1Threshold: 1000 * 10**6,   // 1000 USDC
            votingPeriod: 48 hours,         // 48 hours to resolve
            judgeTimeout: 24 hours          // 24 hours per judge
        });
    }

    // ============ External Functions - Dispute Creation ============

    /**
     * @notice Create a new dispute for a bet
     * @param betContract Address of the bet contract
     * @return disputeId The ID of the created dispute
     */
    function createDispute(address betContract) external nonReentrant returns (uint256 disputeId) {
        Bet bet = Bet(betContract);

        // Verify bet is in Disputed state
        (, , , , , , , , Bet.BetState state, ) = bet.betDetails();
        require(state == Bet.BetState.Disputed, "Bet not disputed");

        // Determine tier based on stake amount
        (, , uint256 stakeAmount, , , , , , , ) = bet.betDetails();
        DisputeTier tier = _determineTier(stakeAmount * 2); // Total stake is 2x individual stake
        uint8 judgeCount = _getJudgeCountForTier(tier);

        // Create dispute
        disputeId = totalDisputes++;
        disputes[disputeId] = Dispute({
            betContract: betContract,
            initiator: msg.sender,
            createdAt: uint64(block.timestamp),
            votingDeadline: uint64(block.timestamp + config.votingPeriod),
            status: DisputeStatus.Active,
            tier: tier,
            judgeCount: judgeCount,
            votesSubmitted: 0,
            finalOutcome: Bet.Outcome.None,
            appealed: false
        });

        // Select judges pseudo-randomly
        address[] memory selectedJudges = judgeRegistry.selectJudges(
            judgeCount,
            uint256(keccak256(abi.encodePacked(betContract, block.timestamp, nonceCounter++)))
        );

        disputeJudges[disputeId] = selectedJudges;

        emit DisputeCreated(
            disputeId,
            betContract,
            msg.sender,
            tier,
            judgeCount,
            disputes[disputeId].votingDeadline,
            block.timestamp
        );

        return disputeId;
    }

    // ============ External Functions - Voting ============

    /**
     * @notice Submit a vote on a dispute
     * @param disputeId ID of the dispute
     * @param outcome The judge's decision
     */
    function submitVote(uint256 disputeId, Bet.Outcome outcome) external nonReentrant {
        Dispute storage dispute = disputes[disputeId];

        if (dispute.createdAt == 0) revert DisputeNotFound();
        if (dispute.status != DisputeStatus.Active) revert DisputeNotActive();
        if (block.timestamp > dispute.votingDeadline) revert VotingPeriodExpired();
        if (outcome == Bet.Outcome.None) revert("Invalid outcome");

        // Verify msg.sender is assigned judge
        bool isAssigned = false;
        for (uint256 i = 0; i < disputeJudges[disputeId].length; i++) {
            if (disputeJudges[disputeId][i] == msg.sender) {
                isAssigned = true;
                break;
            }
        }
        if (!isAssigned) revert NotAssignedJudge();

        // Check if already voted
        if (votes[disputeId][msg.sender].hasVoted) revert AlreadyVoted();

        // Record vote
        votes[disputeId][msg.sender] = Vote({
            outcome: outcome,
            votedAt: uint64(block.timestamp),
            hasVoted: true
        });

        voteCount[disputeId][outcome]++;
        dispute.votesSubmitted++;

        emit VoteSubmitted(disputeId, msg.sender, outcome, block.timestamp);

        // Check if we can resolve early (majority reached)
        uint8 majority = dispute.judgeCount / 2 + 1;
        if (voteCount[disputeId][outcome] >= majority) {
            _resolveDispute(disputeId);
        }
    }

    /**
     * @notice Finalize dispute after voting period (if not auto-resolved)
     * @param disputeId ID of the dispute
     */
    function finalizeDispute(uint256 disputeId) external nonReentrant {
        Dispute storage dispute = disputes[disputeId];

        if (dispute.createdAt == 0) revert DisputeNotFound();
        if (dispute.status != DisputeStatus.Active) revert DisputeNotActive();
        if (block.timestamp <= dispute.votingDeadline) revert VotingPeriodNotExpired();

        _resolveDispute(disputeId);
    }

    /**
     * @notice Replace non-responsive judge
     * @param disputeId ID of the dispute
     * @param judgeIndex Index of judge to replace
     */
    function replaceTimeoutJudge(uint256 disputeId, uint256 judgeIndex) external onlyOwner {
        Dispute storage dispute = disputes[disputeId];

        if (dispute.status != DisputeStatus.Active) revert DisputeNotActive();
        if (judgeIndex >= disputeJudges[disputeId].length) revert("Invalid index");

        address oldJudge = disputeJudges[disputeId][judgeIndex];

        // Check if judge hasn't voted and timeout passed
        if (votes[disputeId][oldJudge].hasVoted) revert("Judge already voted");
        if (block.timestamp < dispute.createdAt + config.judgeTimeout) revert("Timeout not reached");

        // Select new judge
        address[] memory newJudges = judgeRegistry.selectJudges(
            1,
            uint256(keccak256(abi.encodePacked(disputeId, block.timestamp, nonceCounter++)))
        );

        address newJudge = newJudges[0];
        disputeJudges[disputeId][judgeIndex] = newJudge;

        // Penalize old judge
        judgeRegistry.updateJudgeStats(oldJudge, false);

        emit JudgeReplaced(disputeId, oldJudge, newJudge, block.timestamp);
    }

    // ============ External Functions - Appeals ============

    /**
     * @notice Appeal a dispute to a higher tier (free but reputation-based)
     * @param disputeId ID of the original dispute
     * @return newDisputeId ID of the new appeal dispute
     */
    function appealDispute(uint256 disputeId) external nonReentrant returns (uint256 newDisputeId) {
        Dispute storage dispute = disputes[disputeId];

        if (dispute.status != DisputeStatus.Resolved) revert("Dispute not resolved");
        if (dispute.appealed) revert("Already appealed");
        if (dispute.tier == DisputeTier.Tier2) revert CannotAppeal(); // Can't appeal Tier2

        // Only bet participants can appeal
        Bet bet = Bet(dispute.betContract);
        (address creator, address opponent,,,,,,,, ) = bet.betDetails();
        require(msg.sender == creator || msg.sender == opponent, "Not a bet participant");

        // Mark original as appealed
        dispute.appealed = true;
        dispute.status = DisputeStatus.Appealed;

        // Create new dispute at higher tier
        DisputeTier newTier = DisputeTier(uint8(dispute.tier) + 1);
        uint8 judgeCount = _getJudgeCountForTier(newTier);

        newDisputeId = totalDisputes++;
        disputes[newDisputeId] = Dispute({
            betContract: dispute.betContract,
            initiator: msg.sender,
            createdAt: uint64(block.timestamp),
            votingDeadline: uint64(block.timestamp + config.votingPeriod),
            status: DisputeStatus.Active,
            tier: newTier,
            judgeCount: judgeCount,
            votesSubmitted: 0,
            finalOutcome: Bet.Outcome.None,
            appealed: false
        });

        // Select new judges
        address[] memory selectedJudges = judgeRegistry.selectJudges(
            judgeCount,
            uint256(keccak256(abi.encodePacked(dispute.betContract, block.timestamp, nonceCounter++)))
        );

        disputeJudges[newDisputeId] = selectedJudges;

        emit DisputeAppealed(disputeId, newDisputeId, newTier, block.timestamp);
        emit DisputeCreated(
            newDisputeId,
            dispute.betContract,
            msg.sender,
            newTier,
            judgeCount,
            disputes[newDisputeId].votingDeadline,
            block.timestamp
        );

        return newDisputeId;
    }

    // ============ Internal Functions ============

    /**
     * @dev Resolve dispute by counting votes and updating judges
     */
    function _resolveDispute(uint256 disputeId) internal {
        Dispute storage dispute = disputes[disputeId];

        // Count votes for each outcome
        uint8 creatorVotes = voteCount[disputeId][Bet.Outcome.CreatorWins];
        uint8 opponentVotes = voteCount[disputeId][Bet.Outcome.OpponentWins];
        uint8 drawVotes = voteCount[disputeId][Bet.Outcome.Draw];

        // Find maximum votes
        uint8 maxVotes = creatorVotes;
        if (opponentVotes > maxVotes) maxVotes = opponentVotes;
        if (drawVotes > maxVotes) maxVotes = drawVotes;

        // Check for ties (multiple outcomes with same max votes)
        uint8 winnersCount = 0;
        if (creatorVotes == maxVotes && maxVotes > 0) winnersCount++;
        if (opponentVotes == maxVotes && maxVotes > 0) winnersCount++;
        if (drawVotes == maxVotes && maxVotes > 0) winnersCount++;

        Bet.Outcome winningOutcome;

        // Handle ties and no-vote scenarios
        if (winnersCount > 1 || maxVotes == 0 || dispute.votesSubmitted == 0) {
            // Tie or no votes -> default to Draw (fairest outcome)
            winningOutcome = Bet.Outcome.Draw;
        } else {
            // Clear winner exists
            if (creatorVotes == maxVotes) {
                winningOutcome = Bet.Outcome.CreatorWins;
            } else if (opponentVotes == maxVotes) {
                winningOutcome = Bet.Outcome.OpponentWins;
            } else {
                winningOutcome = Bet.Outcome.Draw;
            }
        }

        // Update judge reputations and slash incorrect voters
        for (uint256 i = 0; i < disputeJudges[disputeId].length; i++) {
            address judge = disputeJudges[disputeId][i];

            if (votes[disputeId][judge].hasVoted) {
                bool wasCorrect = votes[disputeId][judge].outcome == winningOutcome;
                judgeRegistry.updateJudgeStats(judge, wasCorrect);

                // Slash if incorrect
                if (!wasCorrect) {
                    judgeRegistry.slashJudge(judge);
                }
            } else {
                // Penalize for not voting
                judgeRegistry.updateJudgeStats(judge, false);
            }
        }

        // Update dispute
        dispute.status = DisputeStatus.Resolved;
        dispute.finalOutcome = winningOutcome;

        // Resolve bet contract
        Bet(dispute.betContract).resolveByJudges(winningOutcome);

        emit DisputeResolved(disputeId, winningOutcome, dispute.votesSubmitted, block.timestamp);
    }

    /**
     * @dev Determine dispute tier based on stake amount
     */
    function _determineTier(uint256 totalStake) internal view returns (DisputeTier) {
        if (totalStake <= config.tier0Threshold) {
            return DisputeTier.Tier0;
        } else if (totalStake <= config.tier1Threshold) {
            return DisputeTier.Tier1;
        } else {
            return DisputeTier.Tier2;
        }
    }

    /**
     * @dev Get number of judges for a tier
     */
    function _getJudgeCountForTier(DisputeTier tier) internal pure returns (uint8) {
        if (tier == DisputeTier.Tier0) return 1;
        if (tier == DisputeTier.Tier1) return 3;
        return 5; // Tier2
    }

    // ============ Owner Functions ============

    /**
     * @notice Update dispute configuration
     */
    function updateConfig(
        uint256 _tier0Threshold,
        uint256 _tier1Threshold,
        uint256 _votingPeriod,
        uint256 _judgeTimeout
    ) external onlyOwner {
        require(_tier0Threshold < _tier1Threshold, "Invalid thresholds");

        config.tier0Threshold = _tier0Threshold;
        config.tier1Threshold = _tier1Threshold;
        config.votingPeriod = _votingPeriod;
        config.judgeTimeout = _judgeTimeout;
    }

    // ============ View Functions ============

    /**
     * @notice Get dispute details
     */
    function getDispute(uint256 disputeId) external view returns (Dispute memory) {
        return disputes[disputeId];
    }

    /**
     * @notice Get judges assigned to a dispute
     */
    function getDisputeJudges(uint256 disputeId) external view returns (address[] memory) {
        return disputeJudges[disputeId];
    }

    /**
     * @notice Get vote for a specific judge
     */
    function getVote(uint256 disputeId, address judge) external view returns (Vote memory) {
        return votes[disputeId][judge];
    }

    /**
     * @notice Get vote counts for all outcomes
     */
    function getVoteCounts(uint256 disputeId)
        external
        view
        returns (uint8 creatorWins, uint8 opponentWins, uint8 draw)
    {
        return (
            voteCount[disputeId][Bet.Outcome.CreatorWins],
            voteCount[disputeId][Bet.Outcome.OpponentWins],
            voteCount[disputeId][Bet.Outcome.Draw]
        );
    }

    /**
     * @notice Check if dispute can be resolved
     */
    function canResolve(uint256 disputeId) external view returns (bool) {
        Dispute memory dispute = disputes[disputeId];

        if (dispute.status != DisputeStatus.Active) return false;

        // Can resolve if majority reached OR voting period expired
        uint8 majority = dispute.judgeCount / 2 + 1;

        bool majorityReached = voteCount[disputeId][Bet.Outcome.CreatorWins] >= majority
            || voteCount[disputeId][Bet.Outcome.OpponentWins] >= majority
            || voteCount[disputeId][Bet.Outcome.Draw] >= majority;

        bool periodExpired = block.timestamp > dispute.votingDeadline;

        return majorityReached || periodExpired;
    }
}
