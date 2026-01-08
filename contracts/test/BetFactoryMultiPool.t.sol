// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/core/BetFactory.sol";
import "../src/core/Bet.sol";
import "../src/core/UsernameRegistry.sol";
import "../src/core/BetYieldVault.sol";
import "../src/liquidity/CDOPoolFactory.sol";
import "../src/liquidity/CDOPool.sol";
import "../src/liquidity/CDOToken.sol";
import "../src/liquidity/BetRiskValidator.sol";
import "../src/mocks/MockUSDC.sol";

/**
 * @title BetFactoryMultiPoolTest
 * @notice Integration tests for multi-pool bet routing
 */
contract BetFactoryMultiPoolTest is Test {
    BetFactory betFactory;
    CDOPoolFactory poolFactory;
    BetRiskValidator riskValidator;
    BetYieldVault yieldVault;
    UsernameRegistry usernameRegistry;
    MockUSDC usdc;

    uint256 sportsPoolId;
    uint256 cryptoPoolId;
    uint256 politicsPoolId;
    uint256 generalPoolId;

    address owner = address(this);
    address alice = address(0x1);
    address bob = address(0x2);
    address carol = address(0x3);

    function setUp() public {
        // Deploy core contracts
        usdc = new MockUSDC();
        usernameRegistry = new UsernameRegistry();
        yieldVault = new BetYieldVault(address(usdc), owner, address(0));
        riskValidator = new BetRiskValidator();

        // Deploy BetFactory
        betFactory = new BetFactory(address(usdc), address(usernameRegistry));
        betFactory.setYieldVault(address(yieldVault));
        betFactory.setRiskValidator(address(riskValidator));

        // Deploy CDOPoolFactory
        poolFactory = new CDOPoolFactory(
            address(usdc),
            address(yieldVault),
            address(riskValidator)
        );

        // Create category-specific pools
        sportsPoolId = poolFactory.createPool(
            "Sports Pool - NBA",
            "CDO-NBA",
            "Sports",
            "NBA",
            CDOPoolFactory.CategoryConfig({
                description: "NBA basketball bets",
                riskTier: CDOPoolFactory.RiskTier.MEDIUM,
                minStake: 10e6,
                maxStake: 10000e6,
                maxUtilization: 8000,
                requiresAIValidation: true
            })
        );

        cryptoPoolId = poolFactory.createPool(
            "Crypto Pool - BTC",
            "CDO-BTC",
            "Crypto",
            "BTC",
            CDOPoolFactory.CategoryConfig({
                description: "Bitcoin price predictions",
                riskTier: CDOPoolFactory.RiskTier.HIGH,
                minStake: 5e6,
                maxStake: 5000e6,
                maxUtilization: 7000,
                requiresAIValidation: true
            })
        );

        politicsPoolId = poolFactory.createPool(
            "Politics Pool",
            "CDO-POLITICS",
            "Politics",
            "Elections",
            CDOPoolFactory.CategoryConfig({
                description: "Political predictions",
                riskTier: CDOPoolFactory.RiskTier.LOW,
                minStake: 20e6,
                maxStake: 20000e6,
                maxUtilization: 9000,
                requiresAIValidation: true
            })
        );

        generalPoolId = poolFactory.createPool(
            "General Pool",
            "CDO-GENERAL",
            "General",
            "Misc",
            CDOPoolFactory.CategoryConfig({
                description: "General bets",
                riskTier: CDOPoolFactory.RiskTier.MEDIUM,
                minStake: 10e6,
                maxStake: 5000e6,
                maxUtilization: 8000,
                requiresAIValidation: true
            })
        );

        // Configure BetFactory to use multi-pool system
        betFactory.setCDOPoolFactory(address(poolFactory));
        betFactory.setDefaultPool(generalPoolId);

        // Authorize BetFactory on all pools
        address[] memory allPools = poolFactory.getAllPools();
        for (uint i = 0; i < allPools.length; i++) {
            CDOPool(allPools[i]).setAuthorizedMatcher(address(betFactory), true);
        }

        // Add liquidity to all pools
        _fundPool(sportsPoolId, 100000e6);
        _fundPool(cryptoPoolId, 50000e6);
        _fundPool(politicsPoolId, 75000e6);
        _fundPool(generalPoolId, 80000e6);

        // Setup category risk limits in riskValidator
        // setCategoryRisk(category, enabled, riskLevel, minDuration, maxStakePercentage)
        riskValidator.setCategoryRisk(
            "Sports-NBA",
            true,     // enabled
            5,        // riskLevel (1-10)
            1 hours,  // minDuration
            100       // maxStakePercentage (100 = 10%)
        );

        riskValidator.setCategoryRisk(
            "Crypto-BTC",
            true,
            7,        // Higher risk
            1 hours,
            50        // 5% max stake
        );

        riskValidator.setCategoryRisk(
            "Politics-Elections",
            true,
            3,        // Lower risk
            1 days,
            200       // 20% max stake
        );

        riskValidator.setCategoryRisk(
            "General-Misc",
            true,
            5,
            1 hours,
            100
        );
    }

    // ============ Routing Tests ============

    function test_HouseBetRoutesToSportsPool() public {
        string[] memory tags = new string[](1);
        tags[0] = "Sports-NBA";

        vm.startPrank(alice);
        usdc.mint(alice, 100e6);
        usdc.approve(address(betFactory), 100e6);

        address betContract = betFactory.createBet(
            "HOUSE",
            100e6,
            "Lakers win tonight",
            "Check NBA official results",
            7 days,
            tags
        );
        vm.stopPrank();

        // Verify bet was matched with Sports pool
        CDOPoolFactory.PoolMetadata memory metadata = poolFactory.getPoolMetadata(sportsPoolId);
        CDOPool sportsPool = CDOPool(metadata.poolAddress);

        assertEq(sportsPool.matchedBetAmounts(betContract), 100e6);
        assertTrue(betFactory.isHouseMatch(betContract));
    }

    function test_HouseBetRoutesToCryptoPool() public {
        string[] memory tags = new string[](1);
        tags[0] = "Crypto-BTC";

        vm.startPrank(alice);
        usdc.mint(alice, 50e6);
        usdc.approve(address(betFactory), 50e6);

        address betContract = betFactory.createBet(
            "HOUSE",
            50e6,
            "Bitcoin reaches $100k",
            "Check Coinbase price",
            30 days,
            tags
        );
        vm.stopPrank();

        // Verify bet was matched with Crypto pool
        CDOPoolFactory.PoolMetadata memory metadata = poolFactory.getPoolMetadata(cryptoPoolId);
        CDOPool cryptoPool = CDOPool(metadata.poolAddress);

        assertEq(cryptoPool.matchedBetAmounts(betContract), 50e6);
    }

    function test_HouseBetRoutesToPoliticsPool() public {
        string[] memory tags = new string[](1);
        tags[0] = "Politics-Elections";

        vm.startPrank(alice);
        usdc.mint(alice, 200e6);
        usdc.approve(address(betFactory), 200e6);

        address betContract = betFactory.createBet(
            "HOUSE",
            200e6,
            "Candidate X wins election",
            "Check official election results",
            60 days,
            tags
        );
        vm.stopPrank();

        // Verify bet was matched with Politics pool
        CDOPoolFactory.PoolMetadata memory metadata = poolFactory.getPoolMetadata(politicsPoolId);
        CDOPool politicsPool = CDOPool(metadata.poolAddress);

        assertEq(politicsPool.matchedBetAmounts(betContract), 200e6);
    }

    function test_HouseBetRoutesToDefaultPoolForUnknownCategory() public {
        string[] memory tags = new string[](1);
        tags[0] = "Unknown-Category";

        vm.startPrank(alice);
        usdc.mint(alice, 100e6);
        usdc.approve(address(betFactory), 100e6);

        address betContract = betFactory.createBet(
            "HOUSE",
            100e6,
            "Random bet",
            "TBD",
            7 days,
            tags
        );
        vm.stopPrank();

        // Verify bet was matched with General (default) pool
        CDOPoolFactory.PoolMetadata memory metadata = poolFactory.getPoolMetadata(generalPoolId);
        CDOPool generalPool = CDOPool(metadata.poolAddress);

        assertEq(generalPool.matchedBetAmounts(betContract), 100e6);
    }

    function test_HouseBetRoutesToDefaultPoolForNoTags() public {
        string[] memory tags = new string[](0);

        vm.startPrank(alice);
        usdc.mint(alice, 100e6);
        usdc.approve(address(betFactory), 100e6);

        address betContract = betFactory.createBet(
            "HOUSE",
            100e6,
            "Bet with no tags",
            "TBD",
            7 days,
            tags
        );
        vm.stopPrank();

        // Verify bet was matched with General (default) pool
        CDOPoolFactory.PoolMetadata memory metadata = poolFactory.getPoolMetadata(generalPoolId);
        CDOPool generalPool = CDOPool(metadata.poolAddress);

        assertEq(generalPool.matchedBetAmounts(betContract), 100e6);
    }

    // ============ Pool Isolation Tests ============

    function test_MultipleBetsIsolatedByPool() public {
        // Create sports bet
        string[] memory sportsTags = new string[](1);
        sportsTags[0] = "Sports-NBA";

        vm.startPrank(alice);
        usdc.mint(alice, 100e6);
        usdc.approve(address(betFactory), 100e6);
        address sportsBet = betFactory.createBet(
            "HOUSE",
            100e6,
            "Lakers win",
            "NBA results",
            7 days,
            sportsTags
        );
        vm.stopPrank();

        // Create crypto bet
        string[] memory cryptoTags = new string[](1);
        cryptoTags[0] = "Crypto-BTC";

        vm.startPrank(bob);
        usdc.mint(bob, 50e6);
        usdc.approve(address(betFactory), 50e6);
        address cryptoBet = betFactory.createBet(
            "HOUSE",
            50e6,
            "BTC reaches $100k",
            "Coinbase price",
            30 days,
            cryptoTags
        );
        vm.stopPrank();

        // Verify pools are isolated
        CDOPoolFactory.PoolMetadata memory sportsMetadata = poolFactory.getPoolMetadata(sportsPoolId);
        CDOPoolFactory.PoolMetadata memory cryptoMetadata = poolFactory.getPoolMetadata(cryptoPoolId);

        CDOPool sportsPool = CDOPool(sportsMetadata.poolAddress);
        CDOPool cryptoPool = CDOPool(cryptoMetadata.poolAddress);

        // Sports pool should only have sports bet
        assertEq(sportsPool.matchedBetAmounts(sportsBet), 100e6);
        assertEq(sportsPool.matchedBetAmounts(cryptoBet), 0);

        // Crypto pool should only have crypto bet
        assertEq(cryptoPool.matchedBetAmounts(cryptoBet), 50e6);
        assertEq(cryptoPool.matchedBetAmounts(sportsBet), 0);
    }

    function test_PoolUtilizationIndependent() public {
        // Get initial stats
        CDOPoolFactory.PoolStats memory initialSportsStats = poolFactory.getPoolStats(sportsPoolId);
        CDOPoolFactory.PoolStats memory initialCryptoStats = poolFactory.getPoolStats(cryptoPoolId);

        // Create large sports bet (affects sports pool utilization)
        string[] memory sportsTags = new string[](1);
        sportsTags[0] = "Sports-NBA";

        vm.startPrank(alice);
        usdc.mint(alice, 10000e6);
        usdc.approve(address(betFactory), 10000e6);
        betFactory.createBet(
            "HOUSE",
            10000e6,
            "Lakers win championship",
            "NBA results",
            90 days,
            sportsTags
        );
        vm.stopPrank();

        // Check updated stats
        CDOPoolFactory.PoolStats memory updatedSportsStats = poolFactory.getPoolStats(sportsPoolId);
        CDOPoolFactory.PoolStats memory updatedCryptoStats = poolFactory.getPoolStats(cryptoPoolId);

        // Sports pool utilization should increase
        assertTrue(updatedSportsStats.utilization > initialSportsStats.utilization);

        // Crypto pool utilization should remain unchanged
        assertEq(updatedCryptoStats.utilization, initialCryptoStats.utilization);
    }

    // ============ Backward Compatibility Tests ============

    function test_LegacySinglePoolStillWorks() public {
        // Create a new BetFactory instance
        BetFactory legacyFactory = new BetFactory(address(usdc), address(usernameRegistry));
        legacyFactory.setYieldVault(address(yieldVault));
        legacyFactory.setRiskValidator(address(riskValidator));

        // Use legacy setCDOPool (not poolFactory)
        CDOPoolFactory.PoolMetadata memory metadata = poolFactory.getPoolMetadata(sportsPoolId);
        CDOPool sportsPool = CDOPool(metadata.poolAddress);

        legacyFactory.setCDOPool(address(sportsPool));
        sportsPool.setAuthorizedMatcher(address(legacyFactory), true);

        // Create bet
        string[] memory tags = new string[](1);
        tags[0] = "Sports-NBA";

        vm.startPrank(alice);
        usdc.mint(alice, 100e6);
        usdc.approve(address(legacyFactory), 100e6);

        address betContract = legacyFactory.createBet(
            "HOUSE",
            100e6,
            "Test bet",
            "TBD",
            7 days,
            tags
        );
        vm.stopPrank();

        // Should still work with legacy single pool
        assertEq(sportsPool.matchedBetAmounts(betContract), 100e6);
    }

    // ============ Error Cases ============

    function test_RevertsWhenNoPoolForCategory() public {
        // Deactivate all pools
        poolFactory.deactivatePool(sportsPoolId);
        poolFactory.deactivatePool(cryptoPoolId);
        poolFactory.deactivatePool(politicsPoolId);
        poolFactory.deactivatePool(generalPoolId);

        string[] memory tags = new string[](1);
        tags[0] = "Sports-NBA";

        vm.startPrank(alice);
        usdc.mint(alice, 100e6);
        usdc.approve(address(betFactory), 100e6);

        vm.expectRevert(BetFactory.NoPoolForCategory.selector);
        betFactory.createBet(
            "HOUSE",
            100e6,
            "Test bet",
            "TBD",
            7 days,
            tags
        );
        vm.stopPrank();
    }

    function test_RevertsWhenInsufficientPoolLiquidity() public {
        // Create bet larger than pool balance
        string[] memory tags = new string[](1);
        tags[0] = "Sports-NBA";

        vm.startPrank(alice);
        usdc.mint(alice, 200000e6); // More than pool has
        usdc.approve(address(betFactory), 200000e6);

        vm.expectRevert(BetFactory.InsufficientPoolLiquidity.selector);
        betFactory.createBet(
            "HOUSE",
            200000e6,
            "Huge bet",
            "TBD",
            7 days,
            tags
        );
        vm.stopPrank();
    }

    // ============ Fuzz Tests ============

    function testFuzz_RoutingWithRandomCategories(uint8 categoryIndex) public {
        string[] memory categories = new string[](4);
        categories[0] = "Sports-NBA";
        categories[1] = "Crypto-BTC";
        categories[2] = "Politics-Elections";
        categories[3] = "General-Misc";

        uint256 index = uint256(categoryIndex) % 4;
        string[] memory tags = new string[](1);
        tags[0] = categories[index];

        vm.startPrank(alice);
        usdc.mint(alice, 100e6);
        usdc.approve(address(betFactory), 100e6);

        address betContract = betFactory.createBet(
            "HOUSE",
            100e6,
            "Random bet",
            "TBD",
            7 days,
            tags
        );
        vm.stopPrank();

        // Verify bet was created and matched
        assertTrue(betFactory.isHouseMatch(betContract));
    }

    // ============ Helper Functions ============

    function _fundPool(uint256 poolId, uint256 amount) internal {
        CDOPoolFactory.PoolMetadata memory metadata = poolFactory.getPoolMetadata(poolId);

        usdc.mint(carol, amount);
        vm.startPrank(carol);
        usdc.approve(metadata.poolAddress, amount);
        CDOPool(metadata.poolAddress).deposit(amount, 0);
        vm.stopPrank();
    }
}
