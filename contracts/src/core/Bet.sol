// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./BetYieldVault.sol";
import "./UsernameRegistry.sol";

/**
 * @title Bet
 * @notice Individual P2P bet contract with optimistic resolution
 * @dev Uses USDC, deposits to BetYieldVault for yield generation
 *      Winner self-declares outcome, loser can dispute within 24h window
 */
contract Bet is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Enums ============

    enum BetState {
        Created,              // Bet created, awaiting opponent
        Active,               // Both parties funded, bet is active
        AwaitingResolution,   // Bet expired, awaiting outcome declaration
        Disputed,             // Outcome disputed, escalated to judges
        Resolved,             // Bet resolved, funds distributed
        Cancelled             // Bet cancelled (no opponent or mutual cancellation)
    }

    enum Outcome {
        None,           // No outcome yet
        CreatorWins,    // Creator won the bet
        OpponentWins,   // Opponent won the bet
        Draw            // Draw/tie
    }

    // ============ Structs ============

    struct BetDetails {
        address creator;
        address opponent;
        uint256 stakeAmount;           // USDC amount (6 decimals)
        string description;
        string outcomeDescription;
        uint256 createdAt;
        uint256 duration;              // Duration in seconds
        uint256 expiresAt;
        BetState state;
        Outcome outcome;
        string[] tags;                 // Tags for categorization
    }

    struct ResolutionWindow {
        uint256 disputeWindowDuration; // e.g., 24 hours
        address declaredWinner;
        uint256 declaredAt;
        uint256 disputeDeadline;
    }

    // ============ State Variables ============

    BetDetails public betDetails;
    ResolutionWindow public resolution;

    IERC20 public immutable usdc;
    BetYieldVault public immutable yieldVault;
    UsernameRegistry public immutable usernameRegistry;
    address public disputeManager; // Set by factory after deployment

    bool public creatorFunded;
    bool public opponentFunded;

    uint256 public constant DISPUTE_WINDOW = 24 hours;

    // ============ Events ============

    event BetCreated(
        address indexed creator,
        address indexed opponent,
        uint256 stakeAmount,
        string description,
        uint256 duration,
        uint256 timestamp
    );

    event BetAccepted(address indexed opponent, uint256 timestamp);
    event BetFunded(address indexed participant, uint256 amount, uint256 timestamp);
    event OutcomeDeclared(address indexed declarer, Outcome outcome, uint256 disputeDeadline, uint256 timestamp);
    event DisputeRaised(address indexed disputer, uint256 timestamp);
    event BetResolved(Outcome outcome, address winner, uint256 totalPayout, uint256 yieldEarned, uint256 timestamp);
    event BetCancelled(address canceller, uint256 timestamp);

    // ============ Errors ============

    error InvalidOpponent();
    error InvalidStakeAmount();
    error InvalidDuration();
    error BetAlreadyAccepted();
    error BetNotActive();
    error BetNotExpired();
    error BetExpired();
    error NotParticipant();
    error AlreadyFunded();
    error NotBothFunded();
    error DisputeWindowActive();
    error DisputeWindowExpired();
    error CannotDeclareAsWinner();
    error InvalidState();
    error Unauthorized();

    // ============ Modifiers ============

    modifier onlyParticipant() {
        if (msg.sender != betDetails.creator && msg.sender != betDetails.opponent) {
            revert NotParticipant();
        }
        _;
    }

    modifier inState(BetState _state) {
        if (betDetails.state != _state) revert InvalidState();
        _;
    }

    // ============ Constructor ============

    constructor(
        address _creator,
        address _opponent,
        uint256 _stakeAmount,
        string memory _description,
        string memory _outcomeDescription,
        uint256 _duration,
        string[] memory _tags,
        address _usdc,
        address _yieldVault,
        address _usernameRegistry
    ) {
        require(_opponent != address(0) && _opponent != _creator, "Invalid opponent");
        require(_stakeAmount > 0, "Invalid stake");
        require(_duration >= 1 hours && _duration <= 365 days, "Invalid duration");
        require(bytes(_description).length > 0, "Empty description");
        require(_usdc != address(0), "Invalid USDC address");
        require(_yieldVault != address(0), "Invalid vault address");
        require(_usernameRegistry != address(0), "Invalid registry address");

        usdc = IERC20(_usdc);
        yieldVault = BetYieldVault(_yieldVault);
        usernameRegistry = UsernameRegistry(_usernameRegistry);

        betDetails = BetDetails({
            creator: _creator,
            opponent: _opponent,
            stakeAmount: _stakeAmount,
            description: _description,
            outcomeDescription: _outcomeDescription,
            createdAt: block.timestamp,
            duration: _duration,
            expiresAt: block.timestamp + _duration,
            state: BetState.Created,
            outcome: Outcome.None,
            tags: _tags
        });

        resolution.disputeWindowDuration = DISPUTE_WINDOW;

        emit BetCreated(
            _creator,
            _opponent,
            _stakeAmount,
            _description,
            _duration,
            block.timestamp
        );
    }

    // ============ External Functions ============

    /**
     * @notice Creator funds their stake
     */
    function fundCreator() external nonReentrant {
        if (msg.sender != betDetails.creator) revert Unauthorized();
        if (creatorFunded) revert AlreadyFunded();
        if (betDetails.state != BetState.Created) revert InvalidState();

        creatorFunded = true;

        // Transfer USDC from creator
        usdc.safeTransferFrom(msg.sender, address(this), betDetails.stakeAmount);

        emit BetFunded(msg.sender, betDetails.stakeAmount, block.timestamp);

        // If both funded, activate bet and deposit to vault
        if (opponentFunded) {
            _activateBet();
        }
    }

    /**
     * @notice Opponent accepts bet and funds their stake
     */
    function acceptBet() external nonReentrant inState(BetState.Created) {
        if (msg.sender != betDetails.opponent) revert Unauthorized();
        if (opponentFunded) revert AlreadyFunded();
        if (block.timestamp >= betDetails.expiresAt) revert BetExpired();

        opponentFunded = true;

        // Transfer USDC from opponent
        usdc.safeTransferFrom(msg.sender, address(this), betDetails.stakeAmount);

        emit BetAccepted(msg.sender, block.timestamp);
        emit BetFunded(msg.sender, betDetails.stakeAmount, block.timestamp);

        // If both funded, activate bet and deposit to vault
        if (creatorFunded) {
            _activateBet();
        }
    }

    /**
     * @notice Declare outcome (optimistic resolution)
     * @param _outcome The declared outcome
     * @dev Winner declares the outcome. Loser has 24h to dispute if they disagree.
     *      This is the correct optimistic resolution model.
     */
    function declareOutcome(Outcome _outcome) external onlyParticipant nonReentrant {
        if (betDetails.state != BetState.Active) revert InvalidState();
        if (block.timestamp < betDetails.expiresAt) revert BetNotExpired();
        if (_outcome == Outcome.None) revert InvalidState();

        // Determine winner and validate declarer
        address winner;
        if (_outcome == Outcome.CreatorWins) {
            winner = betDetails.creator;
            // Only the creator (winner) can declare they won
            if (msg.sender != betDetails.creator) revert Unauthorized();
        } else if (_outcome == Outcome.OpponentWins) {
            winner = betDetails.opponent;
            // Only the opponent (winner) can declare they won
            if (msg.sender != betDetails.opponent) revert Unauthorized();
        } else {
            // Draw can be declared by either party
            winner = address(0);
        }

        betDetails.state = BetState.AwaitingResolution;
        betDetails.outcome = _outcome;
        resolution.declaredWinner = winner;
        resolution.declaredAt = block.timestamp;
        resolution.disputeDeadline = block.timestamp + resolution.disputeWindowDuration;

        emit OutcomeDeclared(msg.sender, _outcome, resolution.disputeDeadline, block.timestamp);
    }

    /**
     * @notice Raise a dispute within the dispute window
     */
    function raiseDispute() external onlyParticipant nonReentrant {
        if (betDetails.state != BetState.AwaitingResolution) revert InvalidState();
        if (block.timestamp > resolution.disputeDeadline) revert DisputeWindowExpired();

        betDetails.state = BetState.Disputed;

        emit DisputeRaised(msg.sender, block.timestamp);

        // Note: In full implementation, this would call DisputeManager
        // For now, mark as disputed and require manual resolution
    }

    /**
     * @notice Finalize resolution after dispute window expires (no dispute raised)
     */
    function finalizeResolution() external nonReentrant {
        if (betDetails.state != BetState.AwaitingResolution) revert InvalidState();
        if (block.timestamp <= resolution.disputeDeadline) revert DisputeWindowActive();

        _resolveBet(betDetails.outcome);
    }

    /**
     * @notice Resolve bet by judges (called by DisputeManager)
     * @param _outcome Outcome determined by judges
     */
    function resolveByJudges(Outcome _outcome) external nonReentrant {
        // Only DisputeManager can resolve disputed bets
        if (msg.sender != disputeManager && disputeManager != address(0)) revert Unauthorized();
        if (betDetails.state != BetState.Disputed) revert InvalidState();

        _resolveBet(_outcome);
    }

    /**
     * @notice Set dispute manager address (called once by factory)
     * @param _disputeManager Address of DisputeManager contract
     */
    function setDisputeManager(address _disputeManager) external {
        require(disputeManager == address(0), "Already set");
        require(_disputeManager != address(0), "Invalid address");
        disputeManager = _disputeManager;
    }

    /**
     * @notice Cancel bet (before both parties fund)
     */
    function cancelBet() external onlyParticipant nonReentrant {
        if (betDetails.state != BetState.Created) revert InvalidState();
        if (creatorFunded && opponentFunded) revert NotBothFunded();

        betDetails.state = BetState.Cancelled;

        // Refund any funded stakes
        if (creatorFunded) {
            usdc.safeTransfer(betDetails.creator, betDetails.stakeAmount);
        }
        if (opponentFunded) {
            usdc.safeTransfer(betDetails.opponent, betDetails.stakeAmount);
        }

        emit BetCancelled(msg.sender, block.timestamp);
    }

    // ============ Internal Functions ============

    /**
     * @dev Activate bet and deposit funds to yield vault
     */
    function _activateBet() internal {
        betDetails.state = BetState.Active;

        uint256 totalStake = betDetails.stakeAmount * 2;

        // Approve and deposit to yield vault
        usdc.approve(address(yieldVault), totalStake);
        yieldVault.depositForBet(address(this), totalStake);
    }

    /**
     * @dev Resolve bet and distribute funds
     * @param _outcome Final outcome
     */
    function _resolveBet(Outcome _outcome) internal {
        betDetails.state = BetState.Resolved;
        betDetails.outcome = _outcome;

        address winner;
        if (_outcome == Outcome.CreatorWins) {
            winner = betDetails.creator;
        } else if (_outcome == Outcome.OpponentWins) {
            winner = betDetails.opponent;
        } else {
            winner = address(0); // Draw
        }

        // Withdraw from vault (principal + yield - platform fee)
        address recipient = winner != address(0) ? winner : address(this); // Send to contract if draw
        (uint256 totalAmount, uint256 yieldEarned) = yieldVault.withdrawForBet(
            address(this),
            recipient
        );

        // If draw, split funds between both participants
        if (_outcome == Outcome.Draw) {
            uint256 halfAmount = totalAmount / 2;
            usdc.safeTransfer(betDetails.creator, halfAmount);
            usdc.safeTransfer(betDetails.opponent, totalAmount - halfAmount); // Handle rounding
        }

        emit BetResolved(_outcome, winner, totalAmount, yieldEarned, block.timestamp);
    }

    // ============ View Functions ============

    /**
     * @notice Get full bet details
     */
    function getBetDetails() external view returns (BetDetails memory) {
        return betDetails;
    }

    /**
     * @notice Get resolution window details
     */
    function getResolutionWindow() external view returns (ResolutionWindow memory) {
        return resolution;
    }

    /**
     * @notice Check if bet has expired
     */
    function hasExpired() external view returns (bool) {
        return block.timestamp >= betDetails.expiresAt;
    }

    /**
     * @notice Get time remaining
     */
    function getTimeRemaining() external view returns (uint256) {
        if (block.timestamp >= betDetails.expiresAt) return 0;
        return betDetails.expiresAt - block.timestamp;
    }

    /**
     * @notice Check if both parties have funded
     */
    function isBothFunded() external view returns (bool) {
        return creatorFunded && opponentFunded;
    }
}
