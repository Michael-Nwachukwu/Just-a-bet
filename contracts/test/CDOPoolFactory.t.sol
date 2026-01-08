// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/liquidity/CDOPoolFactory.sol";
import "../src/liquidity/CDOPool.sol";
import "../src/liquidity/CDOToken.sol";
import "../src/liquidity/BetRiskValidator.sol";
import "../src/core/BetYieldVault.sol";
import "../src/mocks/MockUSDC.sol";

contract CDOPoolFactoryTest is Test {
    CDOPoolFactory factory;
    MockUSDC usdc;
    BetYieldVault yieldVault;
    BetRiskValidator riskValidator;

    address owner = address(this);
    address alice = address(0x1);
    address bob = address(0x2);

    event PoolCreated(
        uint256 indexed poolId,
        string category,
        string subcategory,
        address poolAddress,
        address tokenAddress,
        uint256 timestamp
    );

    event CategoryConfigUpdated(
        uint256 indexed poolId,
        string category,
        CDOPoolFactory.CategoryConfig config,
        uint256 timestamp
    );

    function setUp() public {
        // Deploy mock USDC
        usdc = new MockUSDC();

        // Deploy yield vault (requires 3 params: usdc, platformFeeReceiver, initialStrategy)
        yieldVault = new BetYieldVault(address(usdc), owner, address(0));

        // Deploy risk validator
        riskValidator = new BetRiskValidator();

        // Deploy factory
        factory = new CDOPoolFactory(
            address(usdc),
            address(yieldVault),
            address(riskValidator)
        );
    }

    // ============ Constructor Tests ============

    function test_Constructor() public view {
        assertEq(factory.USDC(), address(usdc));
        assertEq(factory.yieldVault(), address(yieldVault));
        assertEq(factory.riskValidator(), address(riskValidator));
        assertEq(factory.nextPoolId(), 0);
    }

    function test_ConstructorRevertsOnZeroAddress() public {
        vm.expectRevert("Invalid USDC");
        new CDOPoolFactory(address(0), address(yieldVault), address(riskValidator));

        vm.expectRevert("Invalid yield vault");
        new CDOPoolFactory(address(usdc), address(0), address(riskValidator));

        vm.expectRevert("Invalid risk validator");
        new CDOPoolFactory(address(usdc), address(yieldVault), address(0));
    }

    // ============ Pool Creation Tests ============

    function test_CreatePool() public {
        CDOPoolFactory.CategoryConfig memory config = CDOPoolFactory.CategoryConfig({
            description: "NBA basketball games",
            riskTier: CDOPoolFactory.RiskTier.MEDIUM,
            minStake: 10e6,
            maxStake: 10000e6,
            maxUtilization: 8000,
            requiresAIValidation: true
        });

        vm.expectEmit(false, false, false, false);
        emit PoolCreated(0, "Sports", "NBA", address(0), address(0), block.timestamp);

        uint256 poolId = factory.createPool(
            "Sports Pool - NBA",
            "CDO-NBA",
            "Sports",
            "NBA",
            config
        );

        assertEq(poolId, 0);
        assertEq(factory.nextPoolId(), 1);

        CDOPoolFactory.PoolMetadata memory metadata = factory.getPoolMetadata(0);
        assertEq(metadata.name, "Sports Pool - NBA");
        assertEq(metadata.symbol, "CDO-NBA");
        assertEq(metadata.category, "Sports");
        assertEq(metadata.subcategory, "NBA");
        assertTrue(metadata.isActive);
        assertTrue(metadata.poolAddress != address(0));
        assertTrue(metadata.tokenAddress != address(0));
    }

    function test_CreateMultiplePools() public {
        // Create Sports pool
        uint256 sportsId = _createDefaultPool("Sports", "NBA");

        // Create Crypto pool
        uint256 cryptoId = _createDefaultPool("Crypto", "BTC");

        assertEq(sportsId, 0);
        assertEq(cryptoId, 1);
        assertEq(factory.nextPoolId(), 2);
        assertEq(factory.getTotalPools(), 2);

        // Verify pools are different
        CDOPoolFactory.PoolMetadata memory sports = factory.getPoolMetadata(0);
        CDOPoolFactory.PoolMetadata memory crypto = factory.getPoolMetadata(1);

        assertTrue(sports.poolAddress != crypto.poolAddress);
        assertTrue(sports.tokenAddress != crypto.tokenAddress);
    }

    function test_CreatePoolOnlyOwner() public {
        CDOPoolFactory.CategoryConfig memory config = _getDefaultConfig();

        vm.prank(alice);
        vm.expectRevert();
        factory.createPool("Sports Pool", "CDO-SPORTS", "Sports", "NBA", config);
    }

    function test_CreatePoolRevertsOnInvalidRiskConfig() public {
        // minStake >= maxStake
        CDOPoolFactory.CategoryConfig memory invalidConfig = CDOPoolFactory.CategoryConfig({
            description: "Invalid",
            riskTier: CDOPoolFactory.RiskTier.MEDIUM,
            minStake: 10000e6,
            maxStake: 100e6, // Less than minStake
            maxUtilization: 8000,
            requiresAIValidation: true
        });

        vm.expectRevert(CDOPoolFactory.InvalidRiskConfig.selector);
        factory.createPool("Invalid Pool", "CDO-INVALID", "Invalid", "Test", invalidConfig);

        // maxUtilization > 100%
        invalidConfig.minStake = 10e6;
        invalidConfig.maxStake = 10000e6;
        invalidConfig.maxUtilization = 15000; // 150%

        vm.expectRevert(CDOPoolFactory.InvalidRiskConfig.selector);
        factory.createPool("Invalid Pool", "CDO-INVALID", "Invalid", "Test", invalidConfig);
    }

    function test_CreatePoolBindsTokenToPool() public {
        uint256 poolId = _createDefaultPool("Sports", "NBA");
        CDOPoolFactory.PoolMetadata memory metadata = factory.getPoolMetadata(poolId);

        CDOToken token = CDOToken(metadata.tokenAddress);

        // Verify token is bound to pool
        assertEq(token.pool(), metadata.poolAddress);

        // Verify pool owns token
        assertEq(token.owner(), metadata.poolAddress);
    }

    // ============ Category Lookup Tests ============

    function test_GetPoolByCategory() public {
        uint256 poolId = _createDefaultPool("Sports", "NBA");
        CDOPoolFactory.PoolMetadata memory metadata = factory.getPoolMetadata(poolId);

        address poolAddress = factory.getPoolByCategory("Sports-NBA");
        assertEq(poolAddress, metadata.poolAddress);
    }

    function test_GetPoolByCategoryReturnsZeroForNonexistent() public {
        address poolAddress = factory.getPoolByCategory("NonExistent-Category");
        assertEq(poolAddress, address(0));
    }

    function test_GetPoolByCategoryReturnsZeroForInactive() public {
        uint256 poolId = _createDefaultPool("Sports", "NBA");

        // Deactivate pool
        factory.deactivatePool(poolId);

        // Should return address(0) for inactive pool
        address poolAddress = factory.getPoolByCategory("Sports-NBA");
        assertEq(poolAddress, address(0));
    }

    function test_IsCategoryActive() public {
        assertFalse(factory.isCategoryActive("Sports-NBA"));

        _createDefaultPool("Sports", "NBA");

        assertTrue(factory.isCategoryActive("Sports-NBA"));
    }

    // ============ Pool Management Tests ============

    function test_UpdateCategoryConfig() public {
        uint256 poolId = _createDefaultPool("Sports", "NBA");

        CDOPoolFactory.CategoryConfig memory newConfig = CDOPoolFactory.CategoryConfig({
            description: "Updated description",
            riskTier: CDOPoolFactory.RiskTier.HIGH,
            minStake: 20e6,
            maxStake: 20000e6,
            maxUtilization: 7000,
            requiresAIValidation: false
        });

        vm.expectEmit(true, false, false, false);
        emit CategoryConfigUpdated(poolId, "Sports", newConfig, block.timestamp);

        factory.updateCategoryConfig(poolId, newConfig);

        CDOPoolFactory.PoolMetadata memory metadata = factory.getPoolMetadata(poolId);
        assertEq(metadata.config.description, "Updated description");
        assertEq(uint(metadata.config.riskTier), uint(CDOPoolFactory.RiskTier.HIGH));
        assertEq(metadata.config.minStake, 20e6);
        assertEq(metadata.config.maxStake, 20000e6);
        assertEq(metadata.config.maxUtilization, 7000);
        assertFalse(metadata.config.requiresAIValidation);
    }

    function test_UpdateCategoryConfigOnlyOwner() public {
        uint256 poolId = _createDefaultPool("Sports", "NBA");
        CDOPoolFactory.CategoryConfig memory newConfig = _getDefaultConfig();

        vm.prank(alice);
        vm.expectRevert();
        factory.updateCategoryConfig(poolId, newConfig);
    }

    function test_UpdateCategoryConfigRevertsOnInvalidPoolId() public {
        CDOPoolFactory.CategoryConfig memory config = _getDefaultConfig();

        vm.expectRevert(CDOPoolFactory.PoolNotFound.selector);
        factory.updateCategoryConfig(999, config);
    }

    function test_DeactivatePool() public {
        uint256 poolId = _createDefaultPool("Sports", "NBA");

        factory.deactivatePool(poolId);

        CDOPoolFactory.PoolMetadata memory metadata = factory.getPoolMetadata(poolId);
        assertFalse(metadata.isActive);
    }

    function test_ReactivatePool() public {
        uint256 poolId = _createDefaultPool("Sports", "NBA");
        factory.deactivatePool(poolId);

        factory.reactivatePool(poolId);

        CDOPoolFactory.PoolMetadata memory metadata = factory.getPoolMetadata(poolId);
        assertTrue(metadata.isActive);
    }

    function test_DeactivatePoolOnlyOwner() public {
        uint256 poolId = _createDefaultPool("Sports", "NBA");

        vm.prank(alice);
        vm.expectRevert();
        factory.deactivatePool(poolId);
    }

    // ============ View Functions Tests ============

    function test_GetAllPools() public {
        _createDefaultPool("Sports", "NBA");
        _createDefaultPool("Crypto", "BTC");
        _createDefaultPool("Politics", "Elections");

        address[] memory allPools = factory.getAllPools();
        assertEq(allPools.length, 3);
        assertTrue(allPools[0] != address(0));
        assertTrue(allPools[1] != address(0));
        assertTrue(allPools[2] != address(0));
    }

    function test_GetTotalPools() public {
        assertEq(factory.getTotalPools(), 0);

        _createDefaultPool("Sports", "NBA");
        assertEq(factory.getTotalPools(), 1);

        _createDefaultPool("Crypto", "BTC");
        assertEq(factory.getTotalPools(), 2);
    }

    function test_GetCategoryConfig() public {
        CDOPoolFactory.CategoryConfig memory originalConfig = _getDefaultConfig();
        _createDefaultPool("Sports", "NBA");

        CDOPoolFactory.CategoryConfig memory retrievedConfig = factory.getCategoryConfig("Sports-NBA");

        assertEq(retrievedConfig.description, originalConfig.description);
        assertEq(uint(retrievedConfig.riskTier), uint(originalConfig.riskTier));
        assertEq(retrievedConfig.minStake, originalConfig.minStake);
        assertEq(retrievedConfig.maxStake, originalConfig.maxStake);
    }

    function test_GetPoolStats() public {
        uint256 poolId = _createDefaultPool("Sports", "NBA");
        CDOPoolFactory.PoolMetadata memory metadata = factory.getPoolMetadata(poolId);

        // Deposit some liquidity to the pool
        usdc.mint(alice, 10000e6);
        vm.startPrank(alice);
        usdc.approve(metadata.poolAddress, 10000e6);
        CDOPool(metadata.poolAddress).deposit(10000e6, 0);
        vm.stopPrank();

        CDOPoolFactory.PoolStats memory stats = factory.getPoolStats(poolId);

        assertEq(stats.poolId, poolId);
        assertEq(stats.name, "Default Pool");
        assertEq(stats.category, "Sports-NBA");
        assertEq(stats.totalLiquidity, 10000e6);
        assertEq(stats.availableLiquidity, 10000e6);
        assertEq(stats.activeBets, 0);
        assertEq(uint(stats.riskTier), uint(CDOPoolFactory.RiskTier.MEDIUM));
    }

    // ============ Integration Tests ============

    function test_PoolIsolation() public {
        uint256 sportsId = _createDefaultPool("Sports", "NBA");
        uint256 cryptoId = _createDefaultPool("Crypto", "BTC");

        CDOPoolFactory.PoolMetadata memory sportsMetadata = factory.getPoolMetadata(sportsId);
        CDOPoolFactory.PoolMetadata memory cryptoMetadata = factory.getPoolMetadata(cryptoId);

        // Deposit to sports pool
        usdc.mint(alice, 5000e6);
        vm.startPrank(alice);
        usdc.approve(sportsMetadata.poolAddress, 5000e6);
        CDOPool(sportsMetadata.poolAddress).deposit(5000e6, 0);
        vm.stopPrank();

        // Verify crypto pool is unaffected
        (,,,, uint256 cryptoPoolBalance,,) = CDOPool(cryptoMetadata.poolAddress).stats();
        assertEq(cryptoPoolBalance, 0);

        // Verify sports pool has balance
        (,,,, uint256 sportsPoolBalance,,) = CDOPool(sportsMetadata.poolAddress).stats();
        assertEq(sportsPoolBalance, 5000e6);
    }

    function test_TokenIsolation() public {
        uint256 sportsId = _createDefaultPool("Sports", "NBA");
        uint256 cryptoId = _createDefaultPool("Crypto", "BTC");

        CDOPoolFactory.PoolMetadata memory sportsMetadata = factory.getPoolMetadata(sportsId);
        CDOPoolFactory.PoolMetadata memory cryptoMetadata = factory.getPoolMetadata(cryptoId);

        CDOToken sportsToken = CDOToken(sportsMetadata.tokenAddress);
        CDOToken cryptoToken = CDOToken(cryptoMetadata.tokenAddress);

        // Verify tokens are bound to different pools
        assertEq(sportsToken.pool(), sportsMetadata.poolAddress);
        assertEq(cryptoToken.pool(), cryptoMetadata.poolAddress);

        // Verify tokens are different
        assertTrue(address(sportsToken) != address(cryptoToken));
    }

    // ============ Fuzz Tests ============

    function testFuzz_CreatePools(uint8 numPools) public {
        vm.assume(numPools > 0 && numPools <= 20); // Limit to reasonable number

        for (uint8 i = 0; i < numPools; i++) {
            string memory category = string(abi.encodePacked("Category", vm.toString(i)));
            string memory subcategory = string(abi.encodePacked("Sub", vm.toString(i)));

            uint256 poolId = factory.createPool(
                string(abi.encodePacked("Pool ", vm.toString(i))),
                string(abi.encodePacked("CDO-", vm.toString(i))),
                category,
                subcategory,
                _getDefaultConfig()
            );

            assertEq(poolId, i);
        }

        assertEq(factory.getTotalPools(), numPools);
    }

    function testFuzz_UpdateCategoryConfig(
        uint256 minStake,
        uint256 maxStake,
        uint16 maxUtilization
    ) public {
        vm.assume(minStake > 0 && minStake < maxStake);
        vm.assume(maxStake <= 1_000_000e6);
        vm.assume(maxUtilization > 0 && maxUtilization <= 10000);

        uint256 poolId = _createDefaultPool("Sports", "NBA");

        CDOPoolFactory.CategoryConfig memory newConfig = CDOPoolFactory.CategoryConfig({
            description: "Updated",
            riskTier: CDOPoolFactory.RiskTier.HIGH,
            minStake: minStake,
            maxStake: maxStake,
            maxUtilization: maxUtilization,
            requiresAIValidation: true
        });

        factory.updateCategoryConfig(poolId, newConfig);

        CDOPoolFactory.PoolMetadata memory metadata = factory.getPoolMetadata(poolId);
        assertEq(metadata.config.minStake, minStake);
        assertEq(metadata.config.maxStake, maxStake);
        assertEq(metadata.config.maxUtilization, maxUtilization);
    }

    // ============ Helper Functions ============

    function _createDefaultPool(string memory category, string memory subcategory)
        internal
        returns (uint256 poolId)
    {
        return factory.createPool(
            "Default Pool",
            "CDO-DEFAULT",
            category,
            subcategory,
            _getDefaultConfig()
        );
    }

    function _getDefaultConfig()
        internal
        pure
        returns (CDOPoolFactory.CategoryConfig memory)
    {
        return CDOPoolFactory.CategoryConfig({
            description: "Default pool description",
            riskTier: CDOPoolFactory.RiskTier.MEDIUM,
            minStake: 10e6,
            maxStake: 10000e6,
            maxUtilization: 8000,
            requiresAIValidation: true
        });
    }
}
