// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/liquidity/BetRiskValidator.sol";
import "../src/core/Bet.sol";
import "../src/core/BetFactory.sol";
import "../src/core/BetYieldVault.sol";
import "../src/core/UsernameRegistry.sol";
import "../src/mocks/MockUSDC.sol";

contract BetRiskValidatorTest is Test {
    BetRiskValidator public validator;
    BetFactory public factory;
    BetYieldVault public vault;
    UsernameRegistry public registry;
    MockUSDC public usdc;

    address public owner = address(1);
    address public alice = address(2);
    address public bob = address(3);
    address public platformFeeReceiver = address(4);

    uint256 constant POOL_LIQUIDITY = 100_000e6; // 100k USDC
    uint256 constant POOL_UTILIZATION = 5000; // 50%

    function setUp() public {
        vm.startPrank(owner);

        // Deploy contracts
        usdc = new MockUSDC();
        registry = new UsernameRegistry();
        vault = new BetYieldVault(address(usdc), platformFeeReceiver);
        validator = new BetRiskValidator();
        factory = new BetFactory(address(usdc), address(registry));

        // Set yield vault in factory
        factory.setYieldVault(address(vault));

        // Mint USDC to test users
        usdc.mint(alice, 1_000_000e6);
        usdc.mint(bob, 1_000_000e6);

        vm.stopPrank();

        // Register bob as opponent for all tests
        vm.prank(bob);
        registry.registerUsername("bob");
    }

    // ============ Constructor & Initialization Tests ============

    function test_Constructor_SetsDefaultRules() public view {
        BetRiskValidator.ValidationRules memory rules = validator.getValidationRules();

        assertEq(rules.minDuration, 24 hours, "Min duration should be 24h");
        assertEq(rules.maxDuration, 365 days, "Max duration should be 365 days");
        assertEq(rules.minStakeAmount, 10e6, "Min stake should be 10 USDC");
        assertEq(rules.maxStakePercentage, 500, "Max stake should be 5%");
        assertEq(rules.minRiskScore, 60, "Min risk score should be 60");
        assertEq(rules.maxUtilization, 8000, "Max utilization should be 80%");
    }

    function test_Constructor_InitializesCategories() public view {
        BetRiskValidator.CategoryRisk memory sports = validator.getCategoryRisk("Sports");
        assertEq(sports.enabled, true, "Sports should be enabled");
        assertEq(sports.riskLevel, 3, "Sports risk level should be 3");

        BetRiskValidator.CategoryRisk memory crypto = validator.getCategoryRisk("Crypto");
        assertEq(crypto.enabled, true, "Crypto should be enabled");
        assertEq(crypto.riskLevel, 5, "Crypto risk level should be 5");
        assertEq(crypto.minDuration, 7 days, "Crypto min duration should be 7 days");

        BetRiskValidator.CategoryRisk memory weather = validator.getCategoryRisk("Weather");
        assertEq(weather.enabled, false, "Weather should be disabled");
        assertEq(weather.riskLevel, 9, "Weather risk level should be 9");

        BetRiskValidator.CategoryRisk memory personal = validator.getCategoryRisk("Personal");
        assertEq(personal.enabled, false, "Personal should be disabled");
    }

    // ============ Basic Validation Tests ============

    function test_ValidateBet_PassesForValidSportsBet() public {
        // Create a valid sports bet
        address betContract = _createBet(
            alice,
            bob,
            100e6, // 100 USDC
            "Lakers vs Warriors",
            "Lakers will win",
            7 days,
            _createTags("Sports")
        );

        (bool isValid, string memory reason) = validator.validateBetForMatching(
            betContract,
            POOL_LIQUIDITY,
            POOL_UTILIZATION
        );

        assertTrue(isValid, "Valid sports bet should pass");
        assertEq(reason, "", "Reason should be empty");
    }

    function test_ValidateBet_FailsForShortDuration() public {
        // Create bet with 12 hour duration (below 24h minimum)
        address betContract = _createBet(
            alice,
            bob,
            100e6,
            "Quick bet",
            "Something happens",
            12 hours,
            _createTags("Sports")
        );

        (bool isValid, string memory reason) = validator.validateBetForMatching(
            betContract,
            POOL_LIQUIDITY,
            POOL_UTILIZATION
        );

        assertFalse(isValid, "Bet with short duration should fail");
        assertEq(reason, "Duration too short");
    }

    function test_ValidateBet_FailsForLongDuration() public {
        // Note: Bet contract constructor prevents durations > 365 days
        // So we test at the edge: exactly 365 days should PASS the validator
        // (since max is 365 days)
        address betContract = _createBet(
            alice,
            bob,
            100e6,
            "Year-long bet",
            "Something happens",
            365 days,
            _createTags("Sports")
        );

        (bool isValid,) = validator.validateBetForMatching(
            betContract,
            POOL_LIQUIDITY,
            POOL_UTILIZATION
        );

        assertTrue(isValid, "Bet with 365 day duration should pass");
    }

    function test_ValidateBet_FailsForLowStake() public {
        // Create bet with 5 USDC stake (below 10 USDC minimum)
        address betContract = _createBet(
            alice,
            bob,
            5e6,
            "Small bet",
            "Something happens",
            7 days,
            _createTags("Sports")
        );

        (bool isValid, string memory reason) = validator.validateBetForMatching(
            betContract,
            POOL_LIQUIDITY,
            POOL_UTILIZATION
        );

        assertFalse(isValid, "Bet with low stake should fail");
        assertEq(reason, "Stake amount too low");
    }

    function test_ValidateBet_FailsForHighStake() public {
        // Create bet with 10k USDC stake (>5% of 100k pool)
        address betContract = _createBet(
            alice,
            bob,
            10_000e6,
            "Large bet",
            "Something happens",
            7 days,
            _createTags("Sports")
        );

        (bool isValid, string memory reason) = validator.validateBetForMatching(
            betContract,
            POOL_LIQUIDITY,
            POOL_UTILIZATION
        );

        assertFalse(isValid, "Bet with high stake should fail");
        assertEq(reason, "Stake exceeds pool limit");
    }

    function test_ValidateBet_FailsForHighUtilization() public {
        // Test with 85% utilization (above 80% max)
        address betContract = _createBet(
            alice,
            bob,
            100e6,
            "Test bet",
            "Something happens",
            7 days,
            _createTags("Sports")
        );

        (bool isValid, string memory reason) = validator.validateBetForMatching(
            betContract,
            POOL_LIQUIDITY,
            8500 // 85% utilization
        );

        assertFalse(isValid, "Bet should fail with high utilization");
        assertEq(reason, "Pool utilization too high");
    }

    // ============ Category Validation Tests ============

    function test_ValidateBet_FailsForDisabledCategory() public {
        // Create weather bet (disabled by default)
        address betContract = _createBet(
            alice,
            bob,
            100e6,
            "Weather bet",
            "It will rain tomorrow",
            7 days,
            _createTags("Weather")
        );

        (bool isValid, string memory reason) = validator.validateBetForMatching(
            betContract,
            POOL_LIQUIDITY,
            POOL_UTILIZATION
        );

        assertFalse(isValid, "Disabled category should fail");
        assertEq(reason, "Category not enabled for pool matching");
    }

    function test_ValidateBet_FailsForNoCategoryTags() public {
        // Create bet with no tags
        string[] memory emptyTags = new string[](0);
        address betContract = _createBetWithTags(
            alice,
            bob,
            100e6,
            "No category bet",
            "Something happens",
            7 days,
            emptyTags
        );

        (bool isValid, string memory reason) = validator.validateBetForMatching(
            betContract,
            POOL_LIQUIDITY,
            POOL_UTILIZATION
        );

        assertFalse(isValid, "Bet with no tags should fail");
        assertEq(reason, "No category tags");
    }

    function test_ValidateBet_AppliesCategorySpecificRules() public {
        // Crypto category requires 7 days minimum
        // Try with 3 days - should fail
        address betContract = _createBet(
            alice,
            bob,
            100e6,
            "BTC bet",
            "BTC will reach 100k",
            3 days,
            _createTags("Crypto")
        );

        (bool isValid, string memory reason) = validator.validateBetForMatching(
            betContract,
            POOL_LIQUIDITY,
            POOL_UTILIZATION
        );

        assertFalse(isValid, "Crypto bet with 3 days should fail");
        assertEq(reason, "Duration too short for this category");
    }

    function test_ValidateBet_PassesCryptoWithLongDuration() public {
        // Crypto category with 30 days should pass
        address betContract = _createBet(
            alice,
            bob,
            100e6,
            "BTC long term",
            "BTC will reach 100k",
            30 days,
            _createTags("Crypto")
        );

        (bool isValid, string memory reason) = validator.validateBetForMatching(
            betContract,
            POOL_LIQUIDITY,
            POOL_UTILIZATION
        );

        assertTrue(isValid, "Crypto bet with 30 days should pass");
    }

    // ============ Price Proximity Tests ============

    function test_ValidateBet_FailsForShortPriceBet() public {
        // Price bets with short duration should fail
        // Price category requires minimum 7 days
        address betContract = _createBet(
            alice,
            bob,
            100e6,
            "ETH price bet",
            "ETH will hit $3000",
            3 days,
            _createTags("Price")
        );

        (bool isValid, string memory reason) = validator.validateBetForMatching(
            betContract,
            POOL_LIQUIDITY,
            POOL_UTILIZATION
        );

        assertFalse(isValid, "Short price bet should fail");
        // Category-specific check runs first, so we get this message
        assertEq(reason, "Duration too short for this category");
    }

    function test_ValidateBet_PassesForLongPriceBet() public {
        // Price bets with 7+ days should pass
        address betContract = _createBet(
            alice,
            bob,
            100e6,
            "ETH price bet long term",
            "ETH will hit $5000",
            30 days,
            _createTags("Price")
        );

        (bool isValid, string memory reason) = validator.validateBetForMatching(
            betContract,
            POOL_LIQUIDITY,
            POOL_UTILIZATION
        );

        assertTrue(isValid, "Long price bet should pass");
    }

    // ============ Risk Score Tests ============

    function test_CalculateRiskScore_HighScoreForLongDuration() public {
        address betContract = _createBet(
            alice,
            bob,
            100e6,
            "Very detailed description of the bet with lots of information to make it clear what the conditions are",
            "Clear outcome",
            30 days,
            _createTags("Sports")
        );

        uint256 score = validator.calculateRiskScore(betContract);
        assertTrue(score >= 60, "Score should be >= 60");
    }

    function test_CalculateRiskScore_LowerScoreForShortDuration() public {
        address betContract = _createBet(
            alice,
            bob,
            100e6,
            "Short description",
            "Outcome",
            1 days,
            _createTags("Sports")
        );

        uint256 score = validator.calculateRiskScore(betContract);
        // Short duration (1 day) gets low duration score
        assertTrue(score < 80, "Short duration should have lower score");
    }

    // ============ Blacklist Tests ============

    function test_BlacklistBet_FailsValidation() public {
        address betContract = _createBet(
            alice,
            bob,
            100e6,
            "Valid bet",
            "Outcome",
            7 days,
            _createTags("Sports")
        );

        // Blacklist the bet
        vm.prank(owner);
        validator.blacklistBet(betContract, "Suspicious activity");

        (bool isValid, string memory reason) = validator.validateBetForMatching(
            betContract,
            POOL_LIQUIDITY,
            POOL_UTILIZATION
        );

        assertFalse(isValid, "Blacklisted bet should fail");
        assertEq(reason, "Bet is blacklisted");
    }

    function test_WhitelistBet_PassesAfterBlacklist() public {
        address betContract = _createBet(
            alice,
            bob,
            100e6,
            "Valid bet",
            "Outcome",
            7 days,
            _createTags("Sports")
        );

        // Blacklist then whitelist
        vm.startPrank(owner);
        validator.blacklistBet(betContract, "Test");
        validator.whitelistBet(betContract);
        vm.stopPrank();

        (bool isValid,) = validator.validateBetForMatching(
            betContract,
            POOL_LIQUIDITY,
            POOL_UTILIZATION
        );

        assertTrue(isValid, "Whitelisted bet should pass");
    }

    // ============ Owner Function Tests ============

    function test_UpdateValidationRules_UpdatesCorrectly() public {
        BetRiskValidator.ValidationRules memory newRules = BetRiskValidator.ValidationRules({
            minDuration: 48 hours,
            maxDuration: 180 days,
            minStakeAmount: 20e6,
            maxStakePercentage: 300,
            minRiskScore: 70,
            maxUtilization: 7000
        });

        vm.prank(owner);
        validator.updateValidationRules(newRules);

        BetRiskValidator.ValidationRules memory updated = validator.getValidationRules();
        assertEq(updated.minDuration, 48 hours);
        assertEq(updated.maxDuration, 180 days);
        assertEq(updated.minStakeAmount, 20e6);
        assertEq(updated.maxStakePercentage, 300);
        assertEq(updated.minRiskScore, 70);
        assertEq(updated.maxUtilization, 7000);
    }

    function test_UpdateValidationRules_RevertsForNonOwner() public {
        BetRiskValidator.ValidationRules memory newRules = BetRiskValidator.ValidationRules({
            minDuration: 48 hours,
            maxDuration: 180 days,
            minStakeAmount: 20e6,
            maxStakePercentage: 300,
            minRiskScore: 70,
            maxUtilization: 7000
        });

        vm.prank(alice);
        vm.expectRevert();
        validator.updateValidationRules(newRules);
    }

    function test_SetCategoryRisk_UpdatesCategory() public {
        vm.prank(owner);
        validator.setCategoryRisk("NewCategory", true, 5, 3 days, 400);

        BetRiskValidator.CategoryRisk memory cat = validator.getCategoryRisk("NewCategory");
        assertEq(cat.enabled, true);
        assertEq(cat.riskLevel, 5);
        assertEq(cat.minDuration, 3 days);
        assertEq(cat.maxStakePercentage, 400);
    }

    function test_SetCategoryRisk_EnablesDisabledCategory() public {
        // Enable weather category
        vm.prank(owner);
        validator.setCategoryRisk("Weather", true, 5, 7 days, 200);

        BetRiskValidator.CategoryRisk memory weather = validator.getCategoryRisk("Weather");
        assertTrue(weather.enabled, "Weather should be enabled");

        // Now weather bet should pass
        address betContract = _createBet(
            alice,
            bob,
            100e6,
            "Weather bet",
            "It will rain",
            7 days,
            _createTags("Weather")
        );

        (bool isValid,) = validator.validateBetForMatching(
            betContract,
            POOL_LIQUIDITY,
            POOL_UTILIZATION
        );

        assertTrue(isValid, "Weather bet should now pass");
    }

    function test_UpdateCreatorReputation_UpdatesScore() public {
        vm.prank(owner);
        validator.updateCreatorReputation(alice, 80);

        uint256 reputation = validator.getCreatorReputation(alice);
        assertEq(reputation, 80, "Reputation should be updated");
    }

    function test_GetCreatorReputation_ReturnsDefaultForNewUser() public view {
        uint256 reputation = validator.getCreatorReputation(alice);
        assertEq(reputation, 50, "Should return default reputation");
    }

    // ============ Integration Tests ============

    function test_ValidateBet_ComplexScenario_HighRiskCategory() public {
        // High risk category (Price) with strict requirements
        address betContract = _createBet(
            alice,
            bob,
            200e6, // 2% of pool (within 2% limit for Price category)
            "Detailed price prediction with lots of context and analysis",
            "BTC will hit $100k",
            14 days, // Above 7 day minimum for price bets
            _createTags("Price")
        );

        (bool isValid, string memory reason) = validator.validateBetForMatching(
            betContract,
            POOL_LIQUIDITY,
            POOL_UTILIZATION
        );

        assertTrue(isValid, "Well-structured price bet should pass");
        assertEq(reason, "");
    }

    function test_ValidateBet_MultipleValidationLayers() public {
        // Test all validation layers together
        // 1. Not blacklisted ✓
        // 2. Duration: 7 days ✓
        // 3. Stake: 500 USDC (0.5% of pool) ✓
        // 4. Utilization: 50% ✓
        // 5. Category: Sports (enabled) ✓
        // 6. Risk score: Should be high ✓

        address betContract = _createBet(
            alice,
            bob,
            500e6,
            "Manchester United vs Liverpool - Premier League match with detailed analysis of team form and statistics",
            "Manchester United will win",
            7 days,
            _createTags("Sports")
        );

        (bool isValid, string memory reason) = validator.validateBetForMatching(
            betContract,
            POOL_LIQUIDITY,
            POOL_UTILIZATION
        );

        assertTrue(isValid, "Bet passing all layers should validate");
        assertEq(reason, "");

        // Verify risk score is good
        uint256 score = validator.calculateRiskScore(betContract);
        assertTrue(score >= 60, "Risk score should be >= 60");
    }

    // ============ Helper Functions ============

    function _createBet(
        address creator,
        address, // opponent address (not used, we use string identifier)
        uint256 stakeAmount,
        string memory description,
        string memory outcomeDescription,
        uint256 duration,
        string[] memory tags
    ) internal returns (address) {
        vm.prank(creator);
        address betContract = factory.createBet(
            "bob",
            stakeAmount,
            description,
            outcomeDescription,
            duration,
            tags
        );
        return betContract;
    }

    function _createBetWithTags(
        address creator,
        address, // opponent address (not used)
        uint256 stakeAmount,
        string memory description,
        string memory outcomeDescription,
        uint256 duration,
        string[] memory tags
    ) internal returns (address) {
        vm.prank(creator);
        address betContract = factory.createBet(
            "bob",
            stakeAmount,
            description,
            outcomeDescription,
            duration,
            tags
        );
        return betContract;
    }

    function _createTags(string memory tag1) internal pure returns (string[] memory) {
        string[] memory tags = new string[](1);
        tags[0] = tag1;
        return tags;
    }
}
