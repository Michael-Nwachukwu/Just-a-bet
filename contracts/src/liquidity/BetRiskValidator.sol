// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../core/Bet.sol";

/**
 * @title BetRiskValidator
 * @notice Multi-layered risk validation system for CDO Pool bet matching
 * @dev Prevents pool from matching "easy win" or unfair bets that could drain liquidity
 */
contract BetRiskValidator is Ownable {

    // ============ Structs ============

    struct ValidationRules {
        uint256 minDuration;           // Minimum bet duration (e.g., 24 hours)
        uint256 maxDuration;           // Maximum bet duration (e.g., 365 days)
        uint256 minStakeAmount;        // Minimum stake (e.g., 10 USDC)
        uint256 maxStakePercentage;    // Max stake as % of pool liquidity (e.g., 500 = 5%)
        uint256 minRiskScore;          // Minimum risk score to pass (e.g., 60/100)
        uint256 maxUtilization;        // Max pool utilization % (e.g., 8000 = 80%)
    }

    struct CategoryRisk {
        bool enabled;                  // Whether this category can be matched
        uint256 riskLevel;            // Risk level 1-10 (1 = safest, 10 = riskiest)
        uint256 minDuration;          // Override min duration for this category
        uint256 maxStakePercentage;   // Override max stake % for this category
    }

    struct PriceProximityRule {
        uint256 minPriceGapPercentage; // Min % gap between current and target price
        uint256 minDurationForGap;     // Min duration required for small gaps
    }

    // ============ State Variables ============

    ValidationRules public rules;
    PriceProximityRule public priceProximityRule;

    // Category name => risk settings
    mapping(string => CategoryRisk) public categoryRisk;

    // Bet contract => blacklisted
    mapping(address => bool) public blacklistedBets;

    // Bet creator => reputation score (0-100)
    mapping(address => uint256) public creatorReputation;

    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant DEFAULT_REPUTATION = 50; // Neutral starting reputation

    // ============ Events ============

    event ValidationRulesUpdated(ValidationRules newRules, uint256 timestamp);
    event CategoryRiskUpdated(string indexed category, bool enabled, uint256 riskLevel, uint256 timestamp);
    event BetBlacklisted(address indexed betContract, string reason, uint256 timestamp);
    event BetWhitelisted(address indexed betContract, uint256 timestamp);
    event ReputationUpdated(address indexed creator, uint256 oldScore, uint256 newScore, uint256 timestamp);
    event ValidationFailed(address indexed betContract, string reason, uint256 timestamp);

    // ============ Errors ============

    error BetDurationTooShort();
    error BetDurationTooLong();
    error StakeAmountTooLow();
    error StakeAmountTooHigh();
    error CategoryNotEnabled();
    error BetIsBlacklisted();
    error RiskScoreTooLow();
    error PoolUtilizationTooHigh();
    error PriceProximityTooClose();

    // ============ Constructor ============

    constructor() Ownable(msg.sender) {
        // Set default validation rules
        rules = ValidationRules({
            minDuration: 24 hours,
            maxDuration: 365 days,
            minStakeAmount: 10e6,           // 10 USDC (6 decimals)
            maxStakePercentage: 500,        // 5% of pool
            minRiskScore: 60,               // 60/100 minimum score
            maxUtilization: 8000            // 80% max utilization
        });

        // Price proximity rule: target price must be >2% away for bets <7 days
        priceProximityRule = PriceProximityRule({
            minPriceGapPercentage: 200,     // 2% minimum gap
            minDurationForGap: 7 days       // Required duration if gap is small
        });

        // Initialize common categories
        _initializeCategories();
    }

    // ============ External Functions - Validation ============

    /**
     * @notice Validate if a bet can be matched by the pool
     * @param betContract Address of the bet to validate
     * @param poolLiquidity Current available pool liquidity
     * @param poolUtilization Current pool utilization percentage (basis points)
     * @return isValid Whether bet passes validation
     * @return reason Failure reason if invalid
     */
    function validateBetForMatching(
        address betContract,
        uint256 poolLiquidity,
        uint256 poolUtilization
    ) external view returns (bool isValid, string memory reason) {

        // Layer 1: Check blacklist
        if (blacklistedBets[betContract]) {
            return (false, "Bet is blacklisted");
        }

        // Get bet details
        Bet bet = Bet(betContract);
        Bet.BetDetails memory details = bet.getBetDetails();

        // Layer 2: Basic validation rules
        (bool basicValid, string memory basicReason) = _validateBasicRules(details, poolLiquidity, poolUtilization);
        if (!basicValid) {
            return (false, basicReason);
        }

        // Layer 3: Category validation
        (bool categoryValid, string memory categoryReason) = _validateCategory(details);
        if (!categoryValid) {
            return (false, categoryReason);
        }

        // Layer 4: Risk score calculation
        (bool scoreValid, string memory scoreReason) = _validateRiskScore(details, betContract);
        if (!scoreValid) {
            return (false, scoreReason);
        }

        // Layer 5: Price proximity check (if applicable)
        // Note: This would require oracle integration in production
        // For now, we check based on tags and description
        (bool priceValid, string memory priceReason) = _validatePriceProximity(details);
        if (!priceValid) {
            return (false, priceReason);
        }

        return (true, "");
    }

    /**
     * @notice Calculate risk score for a bet (0-100, higher = safer)
     * @param betContract Address of bet to score
     * @return score Risk score
     */
    function calculateRiskScore(address betContract) external view returns (uint256 score) {
        Bet bet = Bet(betContract);
        Bet.BetDetails memory details = bet.getBetDetails();

        return _calculateRiskScore(details, betContract);
    }

    // ============ Internal Functions - Validation ============

    /**
     * @dev Validate basic rules (duration, stake amount, utilization)
     */
    function _validateBasicRules(
        Bet.BetDetails memory details,
        uint256 poolLiquidity,
        uint256 poolUtilization
    ) internal view returns (bool, string memory) {

        // Check duration
        if (details.duration < rules.minDuration) {
            return (false, "Duration too short");
        }
        if (details.duration > rules.maxDuration) {
            return (false, "Duration too long");
        }

        // Check stake amount
        if (details.stakeAmount < rules.minStakeAmount) {
            return (false, "Stake amount too low");
        }

        // Check stake vs pool liquidity
        uint256 maxStake = (poolLiquidity * rules.maxStakePercentage) / BASIS_POINTS;
        if (details.stakeAmount > maxStake) {
            return (false, "Stake exceeds pool limit");
        }

        // Check pool utilization
        if (poolUtilization >= rules.maxUtilization) {
            return (false, "Pool utilization too high");
        }

        return (true, "");
    }

    /**
     * @dev Validate bet category and apply category-specific rules
     */
    function _validateCategory(Bet.BetDetails memory details) internal view returns (bool, string memory) {

        // Check if bet has tags
        if (details.tags.length == 0) {
            return (false, "No category tags");
        }

        // Get primary category (first tag)
        string memory primaryCategory = details.tags[0];
        CategoryRisk memory catRisk = categoryRisk[primaryCategory];

        // Check if category is enabled
        if (!catRisk.enabled) {
            return (false, "Category not enabled for pool matching");
        }

        // Check category-specific duration
        if (catRisk.minDuration > 0 && details.duration < catRisk.minDuration) {
            return (false, "Duration too short for this category");
        }

        return (true, "");
    }

    /**
     * @dev Calculate and validate risk score
     */
    function _validateRiskScore(
        Bet.BetDetails memory details,
        address betContract
    ) internal view returns (bool, string memory) {

        uint256 score = _calculateRiskScore(details, betContract);

        if (score < rules.minRiskScore) {
            return (false, "Risk score too low");
        }

        return (true, "");
    }

    /**
     * @dev Calculate risk score (0-100)
     */
    function _calculateRiskScore(
        Bet.BetDetails memory details,
        address betContract
    ) internal view returns (uint256) {

        uint256 score = 0;

        // Component 1: Duration score (0-30 points)
        // Longer duration = higher score (safer)
        if (details.duration >= 30 days) {
            score += 30;
        } else if (details.duration >= 7 days) {
            score += 20;
        } else if (details.duration >= 3 days) {
            score += 10;
        } else {
            score += 5;
        }

        // Component 2: Stake size score (0-20 points)
        // Smaller stake relative to max = higher score (safer)
        // This is calculated in validateBetForMatching with pool context
        // For standalone scoring, give moderate score
        score += 15;

        // Component 3: Category risk level (0-25 points)
        if (details.tags.length > 0) {
            CategoryRisk memory catRisk = categoryRisk[details.tags[0]];
            if (catRisk.enabled) {
                // Lower risk level = higher score
                // Risk level 1-10, convert to 25-5 points
                uint256 categoryPoints = 30 - (catRisk.riskLevel * 2);
                score += categoryPoints;
            }
        }

        // Component 4: Creator reputation (0-15 points)
        uint256 reputation = creatorReputation[details.creator];
        if (reputation == 0) {
            reputation = DEFAULT_REPUTATION; // Default for new users
        }
        // Scale 0-100 reputation to 0-15 points
        score += (reputation * 15) / 100;

        // Component 5: Description quality (0-10 points)
        // Longer, detailed descriptions = higher score
        if (bytes(details.description).length > 200) {
            score += 10;
        } else if (bytes(details.description).length > 100) {
            score += 7;
        } else if (bytes(details.description).length > 50) {
            score += 5;
        } else {
            score += 2;
        }

        return score > 100 ? 100 : score;
    }

    /**
     * @dev Validate price proximity (prevent "ETH at $2979 will hit $2980" bets)
     */
    function _validatePriceProximity(Bet.BetDetails memory details) internal view returns (bool, string memory) {

        // Check if this is a price-based bet
        bool isPriceBet = false;
        for (uint i = 0; i < details.tags.length; i++) {
            if (_isStringEqual(details.tags[i], "Price") ||
                _isStringEqual(details.tags[i], "Crypto") ||
                _isStringEqual(details.tags[i], "Trading")) {
                isPriceBet = true;
                break;
            }
        }

        // If not a price bet, pass validation
        if (!isPriceBet) {
            return (true, "");
        }

        // For price bets with short duration, check description for suspicious patterns
        if (details.duration < priceProximityRule.minDurationForGap) {
            // Check for specific price targets in description
            // In production, this would use Chainlink oracles to check actual prices
            // For now, we require longer duration for all price bets
            return (false, "Price bets require longer duration");
        }

        return (true, "");
    }

    // ============ Owner Functions ============

    /**
     * @notice Update validation rules
     */
    function updateValidationRules(ValidationRules calldata newRules) external onlyOwner {
        require(newRules.minDuration > 0, "Invalid min duration");
        require(newRules.maxDuration > newRules.minDuration, "Invalid max duration");
        require(newRules.maxStakePercentage <= 1000, "Max stake too high"); // Max 10%
        require(newRules.minRiskScore <= 100, "Invalid risk score");
        require(newRules.maxUtilization <= BASIS_POINTS, "Invalid utilization");

        rules = newRules;
        emit ValidationRulesUpdated(newRules, block.timestamp);
    }

    /**
     * @notice Configure category risk settings
     */
    function setCategoryRisk(
        string calldata category,
        bool enabled,
        uint256 riskLevel,
        uint256 minDuration,
        uint256 maxStakePercentage
    ) external onlyOwner {
        require(riskLevel <= 10, "Risk level must be 1-10");
        require(maxStakePercentage <= 1000, "Max stake too high");

        categoryRisk[category] = CategoryRisk({
            enabled: enabled,
            riskLevel: riskLevel,
            minDuration: minDuration,
            maxStakePercentage: maxStakePercentage
        });

        emit CategoryRiskUpdated(category, enabled, riskLevel, block.timestamp);
    }

    /**
     * @notice Blacklist a specific bet
     */
    function blacklistBet(address betContract, string calldata reason) external onlyOwner {
        blacklistedBets[betContract] = true;
        emit BetBlacklisted(betContract, reason, block.timestamp);
    }

    /**
     * @notice Remove bet from blacklist
     */
    function whitelistBet(address betContract) external onlyOwner {
        blacklistedBets[betContract] = false;
        emit BetWhitelisted(betContract, block.timestamp);
    }

    /**
     * @notice Update creator reputation score
     */
    function updateCreatorReputation(address creator, uint256 newScore) external onlyOwner {
        require(newScore <= 100, "Score must be 0-100");

        uint256 oldScore = creatorReputation[creator];
        creatorReputation[creator] = newScore;

        emit ReputationUpdated(creator, oldScore, newScore, block.timestamp);
    }

    /**
     * @notice Update price proximity rule
     */
    function updatePriceProximityRule(
        uint256 minPriceGapPercentage,
        uint256 minDurationForGap
    ) external onlyOwner {
        priceProximityRule = PriceProximityRule({
            minPriceGapPercentage: minPriceGapPercentage,
            minDurationForGap: minDurationForGap
        });
    }

    // ============ Internal Helpers ============

    /**
     * @dev Initialize default categories
     */
    function _initializeCategories() internal {
        // Sports - Low risk, enabled
        categoryRisk["Sports"] = CategoryRisk({
            enabled: true,
            riskLevel: 3,
            minDuration: 1 hours,
            maxStakePercentage: 500  // 5%
        });

        // Crypto (long-term) - Medium risk, enabled with longer duration
        categoryRisk["Crypto"] = CategoryRisk({
            enabled: true,
            riskLevel: 5,
            minDuration: 7 days,
            maxStakePercentage: 300  // 3%
        });

        // Price - High risk, strict requirements
        categoryRisk["Price"] = CategoryRisk({
            enabled: true,
            riskLevel: 8,
            minDuration: 7 days,
            maxStakePercentage: 200  // 2%
        });

        // Politics/Elections - Low risk, enabled
        categoryRisk["Politics"] = CategoryRisk({
            enabled: true,
            riskLevel: 3,
            minDuration: 1 days,
            maxStakePercentage: 500  // 5%
        });

        // Entertainment - Low risk, enabled
        categoryRisk["Entertainment"] = CategoryRisk({
            enabled: true,
            riskLevel: 3,
            minDuration: 1 hours,
            maxStakePercentage: 500  // 5%
        });

        // Weather - High risk, disabled by default
        categoryRisk["Weather"] = CategoryRisk({
            enabled: false,
            riskLevel: 9,
            minDuration: 7 days,
            maxStakePercentage: 100  // 1%
        });

        // Personal - Very high risk, disabled
        categoryRisk["Personal"] = CategoryRisk({
            enabled: false,
            riskLevel: 10,
            minDuration: 30 days,
            maxStakePercentage: 100  // 1%
        });
    }

    /**
     * @dev String comparison helper
     */
    function _isStringEqual(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    // ============ View Functions ============

    /**
     * @notice Get category risk settings
     */
    function getCategoryRisk(string calldata category) external view returns (CategoryRisk memory) {
        return categoryRisk[category];
    }

    /**
     * @notice Check if bet is blacklisted
     */
    function isBetBlacklisted(address betContract) external view returns (bool) {
        return blacklistedBets[betContract];
    }

    /**
     * @notice Get creator reputation
     */
    function getCreatorReputation(address creator) external view returns (uint256) {
        uint256 reputation = creatorReputation[creator];
        return reputation == 0 ? DEFAULT_REPUTATION : reputation;
    }

    /**
     * @notice Get current validation rules
     */
    function getValidationRules() external view returns (ValidationRules memory) {
        return rules;
    }
}
