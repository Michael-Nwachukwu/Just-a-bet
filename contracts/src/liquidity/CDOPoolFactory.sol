// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./CDOPool.sol";
import "./CDOToken.sol";
import "./BetRiskValidator.sol";
import "../core/BetYieldVault.sol";

/**
 * @title CDOPoolFactory
 * @notice Factory contract for creating and managing category-specific liquidity pools
 * @dev Each betting category (Sports, Crypto, Politics, etc.) gets its own isolated pool
 *      Only admin can create new pools to prevent category proliferation
 */
contract CDOPoolFactory is Ownable, ReentrancyGuard {

    // ============ Enums ============

    enum RiskTier { LOW, MEDIUM, HIGH }

    // ============ Structs ============

    struct CategoryConfig {
        string description;              // "NBA basketball games and player performance bets"
        RiskTier riskTier;              // LOW, MEDIUM, HIGH
        uint256 minStake;               // Minimum bet stake (e.g., 10 USDC = 10e6)
        uint256 maxStake;               // Maximum bet stake (e.g., 10,000 USDC = 10000e6)
        uint256 maxUtilization;         // Max % pool can be in active bets (basis points, e.g., 8000 = 80%)
        bool requiresAIValidation;      // Must pass AI validation
    }

    struct PoolMetadata {
        string name;                    // "Sports Pool - NBA"
        string symbol;                  // "CDO-NBA"
        address poolAddress;            // CDOPool contract address
        address tokenAddress;           // CDOToken contract address
        string category;                // Primary category: "Sports"
        string subcategory;             // Subcategory: "NBA"
        CategoryConfig config;          // Risk configuration
        uint256 createdAt;              // Creation timestamp
        bool isActive;                  // Active status
    }

    struct PoolStats {
        uint256 poolId;
        string name;
        string category;
        uint256 totalLiquidity;         // Total USDC in pool
        uint256 availableLiquidity;     // USDC available for matching
        uint256 activeBets;             // Number of active bets
        uint256 utilization;            // Current utilization % (basis points)
        uint256 apy;                    // Current APY (basis points)
        RiskTier riskTier;
    }

    // ============ State Variables ============

    // Shared contracts (all pools use same instances)
    address public immutable USDC;
    address public immutable yieldVault;
    address public immutable riskValidator;

    // Pool management
    uint256 public nextPoolId;
    mapping(uint256 => PoolMetadata) public pools;           // poolId => metadata
    mapping(string => uint256) public categoryToPoolId;      // "Sports-NBA" => poolId
    address[] public allPoolAddresses;                       // Array of all pool addresses

    // ============ Events ============

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
        CategoryConfig config,
        uint256 timestamp
    );

    event PoolDeactivated(uint256 indexed poolId, uint256 timestamp);
    event PoolReactivated(uint256 indexed poolId, uint256 timestamp);

    // ============ Errors ============

    error PoolNotFound();
    error CategoryAlreadyExists();
    error InvalidCategory();
    error PoolNotActive();
    error InvalidRiskConfig();

    // ============ Constructor ============

    /**
     * @notice Initialize factory with shared contract addresses
     * @param _usdc USDC token address
     * @param _yieldVault BetYieldVault address
     * @param _riskValidator BetRiskValidator address
     */
    constructor(
        address _usdc,
        address _yieldVault,
        address _riskValidator
    ) Ownable(msg.sender) {
        require(_usdc != address(0), "Invalid USDC");
        require(_yieldVault != address(0), "Invalid yield vault");
        require(_riskValidator != address(0), "Invalid risk validator");

        USDC = _usdc;
        yieldVault = _yieldVault;
        riskValidator = _riskValidator;
    }

    // ============ External Functions - Pool Creation ============

    /**
     * @notice Create a new category-specific pool (admin only)
     * @param name Pool name ("Sports Pool - NBA")
     * @param symbol CDO token symbol ("CDO-NBA")
     * @param category Primary category ("Sports")
     * @param subcategory Subcategory ("NBA")
     * @param categoryConfig Risk configuration for this category
     * @return poolId The ID of the newly created pool
     */
    function createPool(
        string memory name,
        string memory symbol,
        string memory category,
        string memory subcategory,
        CategoryConfig memory categoryConfig
    ) external onlyOwner nonReentrant returns (uint256 poolId) {
        // Validate category
        string memory categoryKey = string.concat(category, "-", subcategory);
        if (categoryToPoolId[categoryKey] != 0 ||
            (nextPoolId > 0 && keccak256(bytes(pools[categoryToPoolId[categoryKey]].category)) == keccak256(bytes(category)))) {
            // Check if category already has a pool
            uint256 existingPoolId = categoryToPoolId[categoryKey];
            if (existingPoolId > 0 && pools[existingPoolId].isActive) {
                revert CategoryAlreadyExists();
            }
        }

        // Validate risk configuration
        if (categoryConfig.minStake >= categoryConfig.maxStake) revert InvalidRiskConfig();
        if (categoryConfig.maxUtilization > 10000) revert InvalidRiskConfig(); // Max 100%

        // 1. Deploy new CDOToken
        CDOToken token = new CDOToken(name, symbol);

        // 2. Deploy new CDOPool
        CDOPool pool = new CDOPool(
            USDC,
            address(token),
            yieldVault,
            riskValidator
        );

        // 3. Bind token to pool (one-time operation)
        token.setPool(address(pool));

        // 4. Transfer token ownership to pool
        token.transferOwnership(address(pool));

        // 5. Store pool metadata
        poolId = nextPoolId++;

        pools[poolId] = PoolMetadata({
            name: name,
            symbol: symbol,
            poolAddress: address(pool),
            tokenAddress: address(token),
            category: category,
            subcategory: subcategory,
            config: categoryConfig,
            createdAt: block.timestamp,
            isActive: true
        });

        // 6. Register category mapping
        categoryToPoolId[categoryKey] = poolId;
        allPoolAddresses.push(address(pool));

        emit PoolCreated(
            poolId,
            category,
            subcategory,
            address(pool),
            address(token),
            block.timestamp
        );

        return poolId;
    }

    // ============ External Functions - Pool Management ============

    /**
     * @notice Update category configuration for existing pool
     * @param poolId Pool ID to update
     * @param newConfig New category configuration
     */
    function updateCategoryConfig(
        uint256 poolId,
        CategoryConfig memory newConfig
    ) external onlyOwner {
        if (poolId >= nextPoolId) revert PoolNotFound();
        if (newConfig.minStake >= newConfig.maxStake) revert InvalidRiskConfig();
        if (newConfig.maxUtilization > 10000) revert InvalidRiskConfig();

        PoolMetadata storage metadata = pools[poolId];
        metadata.config = newConfig;

        emit CategoryConfigUpdated(
            poolId,
            metadata.category,
            newConfig,
            block.timestamp
        );
    }

    /**
     * @notice Deactivate a pool (prevents new bets from routing to it)
     * @param poolId Pool ID to deactivate
     */
    function deactivatePool(uint256 poolId) external onlyOwner {
        if (poolId >= nextPoolId) revert PoolNotFound();

        pools[poolId].isActive = false;
        emit PoolDeactivated(poolId, block.timestamp);
    }

    /**
     * @notice Reactivate a pool
     * @param poolId Pool ID to reactivate
     */
    function reactivatePool(uint256 poolId) external onlyOwner {
        if (poolId >= nextPoolId) revert PoolNotFound();

        pools[poolId].isActive = true;
        emit PoolReactivated(poolId, block.timestamp);
    }

    // ============ View Functions - Pool Lookup ============

    /**
     * @notice Get pool address by category
     * @param categoryKey Category string ("Sports-NBA")
     * @return Pool address (address(0) if not found or inactive)
     */
    function getPoolByCategory(string memory categoryKey)
        external
        view
        returns (address)
    {
        uint256 poolId = categoryToPoolId[categoryKey];

        if (poolId >= nextPoolId) return address(0);

        PoolMetadata memory metadata = pools[poolId];

        // Return address(0) if pool is inactive
        if (!metadata.isActive) return address(0);

        return metadata.poolAddress;
    }

    /**
     * @notice Get pool metadata by ID
     * @param poolId Pool ID
     * @return Pool metadata struct
     */
    function getPoolMetadata(uint256 poolId)
        external
        view
        returns (PoolMetadata memory)
    {
        if (poolId >= nextPoolId) revert PoolNotFound();
        return pools[poolId];
    }

    /**
     * @notice Get all active pool addresses
     * @return Array of pool addresses
     */
    function getAllPools() external view returns (address[] memory) {
        return allPoolAddresses;
    }

    /**
     * @notice Get total number of pools (including inactive)
     * @return Total pool count
     */
    function getTotalPools() external view returns (uint256) {
        return nextPoolId;
    }

    /**
     * @notice Get pool statistics for frontend display
     * @param poolId Pool ID
     * @return stats PoolStats struct with current metrics
     */
    function getPoolStats(uint256 poolId)
        external
        view
        returns (PoolStats memory stats)
    {
        if (poolId >= nextPoolId) revert PoolNotFound();

        PoolMetadata memory metadata = pools[poolId];
        CDOPool pool = CDOPool(metadata.poolAddress);

        // Get pool stats (stats is a public variable, not a function)
        (
            uint256 totalDeposits,
            uint256 totalBetsMatched,
            uint256 totalVolumeMatched,
            uint256 totalYieldDistributed,
            uint256 poolBalance,
            uint256 activeMatchedAmount,
            uint256 totalShares
        ) = pool.stats();

        // Create PoolStats struct manually
        CDOPool.PoolStats memory poolStats = CDOPool.PoolStats({
            totalDeposits: totalDeposits,
            totalBetsMatched: totalBetsMatched,
            totalVolumeMatched: totalVolumeMatched,
            totalYieldDistributed: totalYieldDistributed,
            poolBalance: poolBalance,
            activeMatchedAmount: activeMatchedAmount,
            totalShares: totalShares
        });

        // Calculate utilization (basis points)
        uint256 utilization = 0;
        if (poolStats.poolBalance > 0) {
            utilization = (poolStats.activeMatchedAmount * 10000) / poolStats.poolBalance;
        }

        // Calculate APY (simplified - in production, use time-weighted calculations)
        uint256 apy = _calculateAPY(poolStats);

        stats = PoolStats({
            poolId: poolId,
            name: metadata.name,
            category: string.concat(metadata.category, "-", metadata.subcategory),
            totalLiquidity: poolStats.poolBalance,
            availableLiquidity: poolStats.poolBalance > poolStats.activeMatchedAmount
                ? poolStats.poolBalance - poolStats.activeMatchedAmount
                : 0,
            activeBets: poolStats.totalBetsMatched,
            utilization: utilization,
            apy: apy,
            riskTier: metadata.config.riskTier
        });

        return stats;
    }

    /**
     * @notice Check if a category exists and is active
     * @param categoryKey Category string ("Sports-NBA")
     * @return bool True if category has an active pool
     */
    function isCategoryActive(string memory categoryKey)
        external
        view
        returns (bool)
    {
        uint256 poolId = categoryToPoolId[categoryKey];
        if (poolId >= nextPoolId) return false;
        return pools[poolId].isActive;
    }

    /**
     * @notice Get category configuration
     * @param categoryKey Category string ("Sports-NBA")
     * @return CategoryConfig struct
     */
    function getCategoryConfig(string memory categoryKey)
        external
        view
        returns (CategoryConfig memory)
    {
        uint256 poolId = categoryToPoolId[categoryKey];
        if (poolId >= nextPoolId) revert PoolNotFound();
        return pools[poolId].config;
    }

    // ============ Pool Authorization ============

    /**
     * @notice Authorize a matcher contract on a pool
     * @param poolAddress The pool address to authorize on
     * @param matcher The matcher contract address
     * @param authorized Whether to authorize or deauthorize
     */
    function authorizeMatcherOnPool(
        address poolAddress,
        address matcher,
        bool authorized
    ) external onlyOwner {
        require(poolAddress != address(0), "Invalid pool address");
        require(matcher != address(0), "Invalid matcher address");

        CDOPool(poolAddress).setAuthorizedMatcher(matcher, authorized);
    }

    /**
     * @notice Transfer pool ownership to a new owner
     * @param poolAddress The pool address
     * @param newOwner The new owner address
     */
    function transferPoolOwnership(
        address poolAddress,
        address newOwner
    ) external onlyOwner {
        require(poolAddress != address(0), "Invalid pool address");
        require(newOwner != address(0), "Invalid new owner");

        CDOPool(poolAddress).transferOwnership(newOwner);
    }

    // ============ Internal Functions ============

    /**
     * @dev Calculate approximate APY based on pool performance
     * @param poolStats Pool statistics
     * @return APY in basis points
     */
    function _calculateAPY(CDOPool.PoolStats memory poolStats)
        internal
        pure
        returns (uint256)
    {
        // Base APY: 5% (500 basis points)
        uint256 baseAPY = 500;

        // Boost based on utilization (higher utilization = higher risk = higher APY)
        // For each 10% utilization, add 0.5% APY
        uint256 utilization = 0;
        if (poolStats.poolBalance > 0) {
            utilization = (poolStats.activeMatchedAmount * 10000) / poolStats.poolBalance;
        }

        uint256 utilizationBoost = (utilization / 1000) * 50; // 0.5% per 10% utilization

        // Boost based on historical yield
        uint256 yieldBoost = 0;
        if (poolStats.totalDeposits > 0 && poolStats.totalYieldDistributed > 0) {
            yieldBoost = (poolStats.totalYieldDistributed * 10000) / poolStats.totalDeposits;
        }

        // Total APY (cap at 50% = 5000 basis points)
        uint256 totalAPY = baseAPY + utilizationBoost + yieldBoost;
        if (totalAPY > 5000) totalAPY = 5000;

        return totalAPY;
    }

    /**
     * @dev Get pool ID from category (internal helper)
     */
    function _getPoolIdByCategory(string memory categoryKey)
        internal
        view
        returns (uint256)
    {
        return categoryToPoolId[categoryKey];
    }
}
