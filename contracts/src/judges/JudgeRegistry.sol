// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title JudgeRegistry
 * @notice Registry for judges who resolve disputed bets
 * @dev Judges stake native MNT (Mantle's native token), build reputation, and can be slashed for incorrect decisions
 */
contract JudgeRegistry is Ownable, ReentrancyGuard {

    // ============ Structs ============

    struct JudgeProfile {
        uint256 stakedAmount;           // MNT staked by judge (18 decimals)
        uint96 reputationScore;         // 0-10000 (10000 = 100%)
        uint96 totalCases;              // Total cases judged
        uint96 correctDecisions;        // Number of correct decisions
        uint64 registeredAt;            // Registration timestamp
        bool isActive;                  // Active status
        uint64 withdrawRequestTime;     // Timestamp of withdrawal request (0 if none)
    }

    struct RegistryConfig {
        uint256 minStakeAmount;         // Minimum MNT stake (e.g., 1 MNT = 1e18)
        uint256 minReputationScore;     // Minimum reputation to judge (e.g., 7000 = 70%)
        uint256 withdrawalLockPeriod;   // Lock period for withdrawals (e.g., 30 days)
        uint256 slashPercentage;        // Percentage to slash for incorrect votes (e.g., 1000 = 10%)
        uint256 initialReputation;      // Starting reputation for new judges (e.g., 8000 = 80%)
    }

    // ============ State Variables ============

    RegistryConfig public config;
    address public treasury; // Address to receive slashed funds

    mapping(address => JudgeProfile) public judges;
    address[] public activeJudges;
    mapping(address => uint256) private activeJudgesIndex;

    uint256 public totalJudges;
    uint256 public totalStaked;

    // ============ Events ============

    event JudgeRegistered(address indexed judge, uint256 stakeAmount, uint256 timestamp);
    event JudgeStakeIncreased(address indexed judge, uint256 amount, uint256 newTotal, uint256 timestamp);
    event WithdrawalRequested(address indexed judge, uint256 availableAt, uint256 timestamp);
    event WithdrawalCompleted(address indexed judge, uint256 amount, uint256 timestamp);
    event JudgeSlashed(address indexed judge, uint256 slashedAmount, uint256 remainingStake, uint256 timestamp);
    event ReputationUpdated(address indexed judge, uint256 oldReputation, uint256 newReputation, uint256 timestamp);
    event JudgeDeactivated(address indexed judge, uint256 timestamp);
    event ConfigUpdated(string parameter, uint256 newValue, uint256 timestamp);

    // ============ Errors ============

    error InsufficientStake();
    error JudgeAlreadyRegistered();
    error JudgeNotRegistered();
    error JudgeNotActive();
    error WithdrawalNotRequested();
    error WithdrawalLockActive();
    error NoStakeToWithdraw();
    error InsufficientReputation();
    error Unauthorized();
    error InvalidAmount();

    // ============ Constructor ============

    constructor() Ownable(msg.sender) {
        // Set default configuration
        config = RegistryConfig({
            minStakeAmount: 1 ether,           // 1 MNT minimum (1e18 wei)
            minReputationScore: 7000,          // 70% minimum reputation
            withdrawalLockPeriod: 30 days,     // 30-day lock period
            slashPercentage: 1000,             // 10% slash for incorrect votes
            initialReputation: 8000            // Start at 80% reputation
        });
    }

    // ============ External Functions - Judge Management ============

    /**
     * @notice Register as a judge by staking native MNT
     * @dev Send MNT value with the transaction
     */
    function registerJudge() external payable nonReentrant {
        if (judges[msg.sender].isActive) revert JudgeAlreadyRegistered();
        if (msg.value < config.minStakeAmount) revert InsufficientStake();

        uint256 stakeAmount = msg.value;

        // Create judge profile
        judges[msg.sender] = JudgeProfile({
            stakedAmount: stakeAmount,
            reputationScore: uint96(config.initialReputation),
            totalCases: 0,
            correctDecisions: 0,
            registeredAt: uint64(block.timestamp),
            isActive: true,
            withdrawRequestTime: 0
        });

        // Add to active judges array
        activeJudgesIndex[msg.sender] = activeJudges.length;
        activeJudges.push(msg.sender);

        totalJudges++;
        totalStaked += stakeAmount;

        emit JudgeRegistered(msg.sender, stakeAmount, block.timestamp);
    }

    /**
     * @notice Increase stake amount by sending additional MNT
     * @dev Send MNT value with the transaction
     */
    function increaseStake() external payable nonReentrant {
        if (!judges[msg.sender].isActive) revert JudgeNotActive();
        if (msg.value == 0) revert InvalidAmount();

        uint256 amount = msg.value;

        judges[msg.sender].stakedAmount += amount;
        totalStaked += amount;

        emit JudgeStakeIncreased(msg.sender, amount, judges[msg.sender].stakedAmount, block.timestamp);
    }

    /**
     * @notice Request withdrawal of stake (starts lock period)
     */
    function requestWithdrawal() external nonReentrant {
        if (!judges[msg.sender].isActive) revert JudgeNotActive();
        if (judges[msg.sender].stakedAmount == 0) revert NoStakeToWithdraw();

        // Deactivate judge immediately
        judges[msg.sender].isActive = false;
        judges[msg.sender].withdrawRequestTime = uint64(block.timestamp);

        // Remove from active judges array
        _removeFromActiveJudges(msg.sender);

        uint256 availableAt = block.timestamp + config.withdrawalLockPeriod;

        emit WithdrawalRequested(msg.sender, availableAt, block.timestamp);
    }

    /**
     * @notice Complete withdrawal after lock period expires
     */
    function completeWithdrawal() external nonReentrant {
        JudgeProfile storage judge = judges[msg.sender];

        if (judge.withdrawRequestTime == 0) revert WithdrawalNotRequested();
        if (block.timestamp < judge.withdrawRequestTime + config.withdrawalLockPeriod) {
            revert WithdrawalLockActive();
        }

        uint256 amount = judge.stakedAmount;
        if (amount == 0) revert NoStakeToWithdraw();

        // Reset judge profile
        judge.stakedAmount = 0;
        judge.withdrawRequestTime = 0;
        totalStaked -= amount;

        // Transfer MNT stake back
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "MNT transfer failed");

        emit WithdrawalCompleted(msg.sender, amount, block.timestamp);
    }

    // ============ External Functions - Judge Selection ============

    /**
     * @notice Get eligible judges for a dispute
     * @param requiredCount Number of judges needed
     * @param seed Random seed for selection
     * @return selectedJudges Array of selected judge addresses
     */
    function selectJudges(uint256 requiredCount, uint256 seed)
        external
        view
        returns (address[] memory selectedJudges)
    {
        uint256 eligibleCount = 0;

        // Count eligible judges
        for (uint256 i = 0; i < activeJudges.length; i++) {
            if (_isEligible(activeJudges[i])) {
                eligibleCount++;
            }
        }

        require(eligibleCount >= requiredCount, "Insufficient eligible judges");

        // Create array of eligible judges
        address[] memory eligible = new address[](eligibleCount);
        uint256 index = 0;
        for (uint256 i = 0; i < activeJudges.length; i++) {
            if (_isEligible(activeJudges[i])) {
                eligible[index] = activeJudges[i];
                index++;
            }
        }

        // Pseudo-random selection (NOTE: For production, use Chainlink VRF)
        selectedJudges = new address[](requiredCount);
        for (uint256 i = 0; i < requiredCount; i++) {
            uint256 randomIndex = uint256(keccak256(abi.encodePacked(seed, i, block.timestamp))) % eligible.length;
            selectedJudges[i] = eligible[randomIndex];

            // Remove selected judge from pool (swap with last)
            eligible[randomIndex] = eligible[eligible.length - 1];
            assembly {
                mstore(eligible, sub(mload(eligible), 1))
            }
        }

        return selectedJudges;
    }

    /**
     * @notice Check if a judge is eligible to vote
     * @param judge Address of judge
     * @return bool True if eligible
     */
    function isEligible(address judge) external view returns (bool) {
        return _isEligible(judge);
    }

    // ============ External Functions - DisputeManager Only ============

    /**
     * @notice Update judge reputation and stats after a case
     * @param judge Address of judge
     * @param wasCorrect Whether the judge voted correctly
     */
    function updateJudgeStats(address judge, bool wasCorrect) external onlyOwner {
        // NOTE: In production, only DisputeManager should call this
        JudgeProfile storage profile = judges[judge];

        if (!profile.isActive && profile.withdrawRequestTime == 0) revert JudgeNotActive();

        uint256 oldReputation = profile.reputationScore;
        profile.totalCases++;

        if (wasCorrect) {
            profile.correctDecisions++;

            // Increase reputation (cap at 10000)
            uint256 increase = 100; // +1% per correct decision
            profile.reputationScore = uint96(
                oldReputation + increase > 10000 ? 10000 : oldReputation + increase
            );
        } else {
            // Decrease reputation
            uint256 decrease = 200; // -2% per incorrect decision
            profile.reputationScore = uint96(
                oldReputation > decrease ? oldReputation - decrease : 0
            );
        }

        emit ReputationUpdated(judge, oldReputation, profile.reputationScore, block.timestamp);
    }

    /**
     * @notice Slash judge stake for incorrect decision
     * @param judge Address of judge to slash
     */
    function slashJudge(address judge) external onlyOwner {
        // NOTE: In production, only DisputeManager should call this
        JudgeProfile storage profile = judges[judge];

        uint256 slashAmount = (profile.stakedAmount * config.slashPercentage) / 10000;

        if (slashAmount > 0) {
            profile.stakedAmount -= slashAmount;
            totalStaked -= slashAmount;

            // Send slashed funds to treasury if set
            if (treasury != address(0)) {
                (bool success, ) = treasury.call{value: slashAmount}("");
                require(success, "Treasury transfer failed");
            }
            // Otherwise, slashed funds remain in contract

            emit JudgeSlashed(judge, slashAmount, profile.stakedAmount, block.timestamp);
        }

        // Deactivate if stake falls below minimum
        if (profile.stakedAmount < config.minStakeAmount && profile.isActive) {
            profile.isActive = false;
            _removeFromActiveJudges(judge);
            emit JudgeDeactivated(judge, block.timestamp);
        }
    }

    /**
     * @notice Set treasury address for slashed funds
     * @param _treasury Address to receive slashed MNT
     */
    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Invalid treasury");
        treasury = _treasury;
    }

    // ============ Owner Functions ============

    /**
     * @notice Update registry configuration
     */
    function updateConfig(
        uint256 _minStakeAmount,
        uint256 _minReputationScore,
        uint256 _withdrawalLockPeriod,
        uint256 _slashPercentage,
        uint256 _initialReputation
    ) external onlyOwner {
        require(_minReputationScore <= 10000, "Invalid reputation");
        require(_slashPercentage <= 5000, "Slash too high"); // Max 50%
        require(_initialReputation <= 10000, "Invalid initial reputation");

        config.minStakeAmount = _minStakeAmount;
        config.minReputationScore = _minReputationScore;
        config.withdrawalLockPeriod = _withdrawalLockPeriod;
        config.slashPercentage = _slashPercentage;
        config.initialReputation = _initialReputation;

        emit ConfigUpdated("all", block.timestamp, block.timestamp);
    }

    // ============ Internal Functions ============

    /**
     * @dev Check if judge is eligible to vote on disputes
     */
    function _isEligible(address judge) internal view returns (bool) {
        JudgeProfile memory profile = judges[judge];
        return profile.isActive
            && profile.stakedAmount >= config.minStakeAmount
            && profile.reputationScore >= config.minReputationScore;
    }

    /**
     * @dev Remove judge from activeJudges array
     */
    function _removeFromActiveJudges(address judge) private {
        uint256 index = activeJudgesIndex[judge];
        uint256 lastIndex = activeJudges.length - 1;

        if (index != lastIndex) {
            address lastJudge = activeJudges[lastIndex];
            activeJudges[index] = lastJudge;
            activeJudgesIndex[lastJudge] = index;
        }

        activeJudges.pop();
        delete activeJudgesIndex[judge];
    }

    // ============ View Functions ============

    /**
     * @notice Get judge profile
     */
    function getJudgeProfile(address judge) external view returns (JudgeProfile memory) {
        return judges[judge];
    }

    /**
     * @notice Get all active judges
     */
    function getActiveJudges() external view returns (address[] memory) {
        return activeJudges;
    }

    /**
     * @notice Get total active judge count
     */
    function getActiveJudgeCount() external view returns (uint256) {
        return activeJudges.length;
    }

    /**
     * @notice Get judge's reputation percentage (0-100)
     */
    function getReputationPercentage(address judge) external view returns (uint256) {
        return judges[judge].reputationScore / 100;
    }

    /**
     * @notice Calculate judge's success rate
     */
    function getSuccessRate(address judge) external view returns (uint256) {
        JudgeProfile memory profile = judges[judge];
        if (profile.totalCases == 0) return 0;
        return (uint256(profile.correctDecisions) * 10000) / uint256(profile.totalCases);
    }

    /**
     * @notice Check withdrawal availability
     */
    function getWithdrawalAvailability(address judge)
        external
        view
        returns (bool canWithdraw, uint256 availableAt)
    {
        JudgeProfile memory profile = judges[judge];

        if (profile.withdrawRequestTime == 0) {
            return (false, 0);
        }

        availableAt = profile.withdrawRequestTime + config.withdrawalLockPeriod;
        canWithdraw = block.timestamp >= availableAt;
    }
}
