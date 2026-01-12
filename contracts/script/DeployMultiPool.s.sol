// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/liquidity/CDOPoolFactory.sol";
import "../src/liquidity/CDOPool.sol";
import "../src/liquidity/CDOToken.sol";
import "../src/core/BetFactory.sol";
import "../src/core/BetYieldVault.sol";
import "../src/liquidity/BetRiskValidator.sol";

/**
 * @title DeployMultiPool
 * @notice Configuration script for multi-pool CDO system (uses already deployed contracts)
 * @dev Run with: forge script script/DeployMultiPool.s.sol --rpc-url https://rpc.sepolia.mantle.xyz --broadcast --legacy
 *
 * This script:
 * 1. Uses deployed CDOPoolFactory
 * 2. Creates category-specific pools (Sports-NBA, Crypto-BTC, Politics, General)
 * 3. Configures BetFactory to use multi-pool system
 * 4. Authorizes BetFactory on all pools
 */
contract DeployMultiPool is Script {

    // Deployed contract addresses from deployed-addresses.m
    address constant USDC = 0xA1103E6490ab174036392EbF5c798C9DaBAb24EE;
    address constant YIELD_VAULT = 0x12ccF0F4A22454d53aBdA56a796a08e93E947256;
    address constant RISK_VALIDATOR = 0x4d0884D03f2fA409370D0F97c6AbC4dA4A8F03d6;
    address constant BET_FACTORY = 0x07ecE77248D4E3f295fdFaeC1C86e257098A434a;
    address constant CDO_POOL_FACTORY = 0xc616918154D7a9dB5D78480d1d53820d4423b298;

    function run() external {
        // Get deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("==============================================");
        console.log("Configuring Multi-Pool CDO System");
        console.log("Deployer:", deployer);
        console.log("==============================================");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // ============ Step 1: Use Deployed CDOPoolFactory ============
        console.log("\n1. Using deployed CDOPoolFactory...");
        CDOPoolFactory factory = CDOPoolFactory(CDO_POOL_FACTORY);
        console.log("   CDOPoolFactory address:", address(factory));

        // ============ Step 2: Create Category-Specific Pools ============
        /*
        console.log("\n2. Creating category-specific pools...");

        // Sports Pool - NBA
        console.log("   Creating Sports Pool - NBA...");
        uint256 nbaPoolId = factory.createPool(
            "Sports Pool - NBA",
            "CDO-NBA",
            "Sports",
            "NBA",
            CDOPoolFactory.CategoryConfig({
                description: "NBA basketball games and player performance bets",
                riskTier: CDOPoolFactory.RiskTier.MEDIUM,
                minStake: 10 * 10**6,      // 10 USDC
                maxStake: 10000 * 10**6,   // 10,000 USDC
                maxUtilization: 8000,      // 80%
                requiresAIValidation: true
            })
        );
        CDOPoolFactory.PoolMetadata memory nbaPool = factory.getPoolMetadata(nbaPoolId);
        console.log("     Pool ID:", nbaPoolId);
        console.log("     Pool Address:", nbaPool.poolAddress);
        console.log("     Token Address:", nbaPool.tokenAddress);

        // Crypto Pool - BTC Price
        console.log("   Creating Crypto Pool - BTC...");
        uint256 btcPoolId = factory.createPool(
            "Crypto Pool - BTC",
            "CDO-BTC",
            "Crypto",
            "BTC",
            CDOPoolFactory.CategoryConfig({
                description: "Bitcoin price predictions and crypto market bets",
                riskTier: CDOPoolFactory.RiskTier.HIGH,
                minStake: 5 * 10**6,       // 5 USDC
                maxStake: 5000 * 10**6,    // 5,000 USDC
                maxUtilization: 7000,      // 70% (higher risk = lower utilization)
                requiresAIValidation: true
            })
        );
        CDOPoolFactory.PoolMetadata memory btcPool = factory.getPoolMetadata(btcPoolId);
        console.log("     Pool ID:", btcPoolId);
        console.log("     Pool Address:", btcPool.poolAddress);
        console.log("     Token Address:", btcPool.tokenAddress);

        // Politics Pool
        console.log("   Creating Politics Pool...");
        uint256 politicsPoolId = factory.createPool(
            "Politics Pool",
            "CDO-POLITICS",
            "Politics",
            "Elections",
            CDOPoolFactory.CategoryConfig({
                description: "Political elections and government predictions",
                riskTier: CDOPoolFactory.RiskTier.LOW,
                minStake: 20 * 10**6,      // 20 USDC
                maxStake: 20000 * 10**6,   // 20,000 USDC
                maxUtilization: 9000,      // 90% (low risk = high utilization)
                requiresAIValidation: true
            })
        );
        CDOPoolFactory.PoolMetadata memory politicsPool = factory.getPoolMetadata(politicsPoolId);
        console.log("     Pool ID:", politicsPoolId);
        console.log("     Pool Address:", politicsPool.poolAddress);
        console.log("     Token Address:", politicsPool.tokenAddress);

        // General Pool (default fallback)
        console.log("   Creating General Pool...");
        uint256 generalPoolId = factory.createPool(
            "General Pool",
            "CDO-GENERAL",
            "General",
            "Misc",
            CDOPoolFactory.CategoryConfig({
                description: "Miscellaneous bets that don't fit other categories",
                riskTier: CDOPoolFactory.RiskTier.MEDIUM,
                minStake: 10 * 10**6,
                maxStake: 5000 * 10**6,
                maxUtilization: 8000,
                requiresAIValidation: true
            })
        );
        CDOPoolFactory.PoolMetadata memory generalPool = factory.getPoolMetadata(generalPoolId);
        console.log("     Pool ID:", generalPoolId);
        console.log("     Pool Address:", generalPool.poolAddress);
        console.log("     Token Address:", generalPool.tokenAddress);
        */
        uint256 generalPoolId = 3; // Hardcoded from deployed-addresses.m

        // ============ Step 3: Configure BetFactory ============
        console.log("\n3. Configuring BetFactory...");
        BetFactory betFactory = BetFactory(BET_FACTORY);

        console.log("   Setting pool factory...");
        betFactory.setCDOPoolFactory(address(factory));

        console.log("   Setting default pool (General)...");
        betFactory.setDefaultPool(generalPoolId);

        // ============ Step 4: Authorize BetFactory on All Pools ============
        console.log("\n4. Authorizing BetFactory on all pools...");
        console.log("   Note: Using factory to authorize since it owns the pools...");

        address[] memory allPools = factory.getAllPools();
        for (uint i = 0; i < allPools.length; i++) {
            console.log("   Authorizing BetFactory on pool", i, ":", allPools[i]);
            factory.authorizeMatcherOnPool(allPools[i], BET_FACTORY, true);
        }

        // Stop broadcasting
        vm.stopBroadcast();

        // ============ Deployment Summary ============
        console.log("\n==============================================");
        console.log("CONFIGURATION SUMMARY");
        console.log("==============================================");
        console.log("CDOPoolFactory:", address(factory));
        /*
        console.log("\nCreated Pools:");
        console.log("  [0] Sports-NBA:    ", nbaPool.poolAddress);
        console.log("      Token:         ", nbaPool.tokenAddress);
        console.log("  [1] Crypto-BTC:    ", btcPool.poolAddress);
        console.log("      Token:         ", btcPool.tokenAddress);
        console.log("  [2] Politics:      ", politicsPool.poolAddress);
        console.log("      Token:         ", politicsPool.tokenAddress);
        console.log("  [3] General:       ", generalPool.poolAddress);
        console.log("      Token:         ", generalPool.tokenAddress);
        */
        console.log("\nBetFactory Config:");
        console.log("  Factory Set:       ", address(factory));
        console.log("  Default Pool ID:   ", generalPoolId);
        // console.log("  Authorized Pools:  ", allPools.length);
        console.log("==============================================");

        console.log("\nNext steps:");
        console.log("1. Save all contract addresses to frontend config");
        console.log("2. Update frontend to use poolFactory address");
        console.log("3. Test pool creation and bet routing");
        console.log("4. Add liquidity to each pool");
        console.log("5. Create test bets in each category");
        /*
        console.log("\nCategory Mapping:");
        console.log("  'Sports-NBA' -> Pool", nbaPoolId);
        console.log("  'Crypto-BTC' -> Pool", btcPoolId);
        console.log("  'Politics-Elections' -> Pool", politicsPoolId);
        // console.log("  'General-Misc' -> Pool", generalPoolId);
        */
        console.log("");
    }

    /**
     * @notice Deploy with existing contracts (alternative entry point)
     * @dev Use this if you already have deployed contracts
     */
    function deployWithExistingContracts(
        address _usdc,
        address _yieldVault,
        address _riskValidator,
        address _betFactory
    ) public {
        console.log("Deploying with existing contracts...");
        console.log("USDC:", _usdc);
        console.log("YieldVault:", _yieldVault);
        console.log("RiskValidator:", _riskValidator);
        console.log("BetFactory:", _betFactory);

        // Deploy factory
        CDOPoolFactory factory = new CDOPoolFactory(
            _usdc,
            _yieldVault,
            _riskValidator
        );

        console.log("CDOPoolFactory deployed:", address(factory));
    }
}
