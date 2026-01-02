// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./CDOToken.sol";
import "./BetRiskValidator.sol";
import "../core/BetYieldVault.sol";

/**
 * @title CDOPool
 * @notice Collateralized Debt Obligation pool for automated liquidity provision
 * @dev Liquidity providers deposit USDC, receive CDO tokens, earn yield from bet matching
 *      Pool automatically matches with bets when one party is missing (acting as house)
 *      Features time-locked positions, tiered yields based on lock duration, and risk-based returns
 */
contract CDOPool is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Structs ============

    struct PoolConfig {
        uint256 minDepositAmount;        // Minimum USDC deposit (e.g., 10 USDC)
        uint256 maxPoolSize;             // Maximum total pool size (e.g., 1M USDC)
        uint256 utilizationTarget;       // Target utilization rate (basis points, e.g., 8000 = 80%)
        uint256 minLockPeriod;           // Minimum lock period (e.g., 7 days)
        uint256 maxLockPeriod;           // Maximum lock period (e.g., 365 days)
        uint256 earlyWithdrawalFee;      // Early withdrawal penalty (basis points, e.g., 500 = 5%)
        bool depositsEnabled;            // Emergency pause for deposits
        bool withdrawalsEnabled;         // Emergency pause for withdrawals
    }

    struct Position {
        uint256 depositAmount;           // Original USDC deposited
        uint256 shares;                  // CDO tokens minted
        uint256 depositedAt;             // Deposit timestamp
        uint256 lockUntil;               // Lock expiration timestamp
        uint256 tier;                    // Lock tier (0 = flexible, 1 = 30d, 2 = 90d, 3 = 365d)
    }

    struct PoolStats {
        uint256 totalDeposits;           // Total USDC deposited
        uint256 totalBetsMatched;        // Total number of bets matched
        uint256 totalVolumeMatched;      // Total USDC volume matched
        uint256 totalYieldDistributed;   // Total yield paid out
        uint256 poolBalance;             // Available USDC in pool
        uint256 activeMatchedAmount;     // USDC currently in active bets
        uint256 totalShares;             // Total CDO tokens in circulation
    }

    struct TierConfig {
        uint256 lockDuration;            // Lock period in seconds
        uint256 yieldBoostBps;           // Yield boost in basis points (e.g., 500 = +5% APY)
        string name;                     // Tier name
    }

    // ============ State Variables ============

    IERC20 public immutable usdc;
    CDOToken public immutable cdoToken;
    BetYieldVault public immutable yieldVault;
    BetRiskValidator public riskValidator;

    PoolConfig public config;
    PoolStats public stats;

    // 4 tiers: Flexible (no lock), 30-day, 90-day, 365-day
    TierConfig[4] public tiers;

    mapping(address => Position[]) public userPositions;
    mapping(address => uint256) public userTotalShares;

    // Bet matching state
    mapping(address => bool) public authorizedMatchers; // BetFactory and other authorized contracts
    mapping(address => uint256) public matchedBetAmounts; // betContract => amount matched
    address[] public activeBets;

    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant BASE_APY = 500; // 5% base APY in basis points

    // ============ Events ============

    event Deposited(
        address indexed user,
        uint256 positionId,
        uint256 amount,
        uint256 shares,
        uint256 tier,
        uint256 lockUntil,
        uint256 timestamp
    );

    event Withdrawn(
        address indexed user,
        uint256 positionId,
        uint256 amount,
        uint256 shares,
        uint256 yieldEarned,
        uint256 penalty,
        uint256 timestamp
    );

    event BetMatched(
        address indexed betContract,
        uint256 amount,
        uint256 timestamp
    );

    event BetSettled(
        address indexed betContract,
        uint256 amount,
        uint256 profit,
        bool won,
        uint256 timestamp
    );

    event YieldUpdated(
        address indexed user,
        uint256 positionId,
        uint256 yieldAmount,
        uint256 timestamp
    );

    event ConfigUpdated(string parameter, uint256 timestamp);
    event AuthorizedMatcherUpdated(address indexed matcher, bool authorized, uint256 timestamp);
    event ValidationFailed(address indexed betContract, string reason, uint256 timestamp);
    event RiskValidatorUpdated(address indexed oldValidator, address indexed newValidator, uint256 timestamp);

    // ============ Errors ============

    error DepositsDisabled();
    error WithdrawalsDisabled();
    error InvalidAmount();
    error BelowMinDeposit();
    error PoolCapReached();
    error InvalidLockPeriod();
    error PositionLocked();
    error PositionNotFound();
    error InsufficientPoolLiquidity();
    error Unauthorized();
    error InvalidTier();
    error BetRiskValidationFailed();
    error RiskValidatorNotSet();

    // ============ Constructor ============

    constructor(
        address _usdc,
        address _cdoToken,
        address _yieldVault,
        address _riskValidator
    ) Ownable(msg.sender) {
        require(_usdc != address(0), "Invalid USDC");
        require(_cdoToken != address(0), "Invalid CDO token");
        require(_yieldVault != address(0), "Invalid yield vault");

        usdc = IERC20(_usdc);
        cdoToken = CDOToken(_cdoToken);
        yieldVault = BetYieldVault(_yieldVault);
        riskValidator = BetRiskValidator(_riskValidator);

        // Set default configuration
        config = PoolConfig({
            minDepositAmount: 10 * 10**6,        // 10 USDC
            maxPoolSize: 1_000_000 * 10**6,      // 1M USDC
            utilizationTarget: 8000,              // 80%
            minLockPeriod: 0,                     // No minimum for flexible tier
            maxLockPeriod: 365 days,
            earlyWithdrawalFee: 500,              // 5%
            depositsEnabled: true,
            withdrawalsEnabled: true
        });

        // Initialize lock tiers
        tiers[0] = TierConfig({
            lockDuration: 0,                      // Flexible (no lock)
            yieldBoostBps: 0,                     // No boost (base APY)
            name: "Flexible"
        });

        tiers[1] = TierConfig({
            lockDuration: 30 days,
            yieldBoostBps: 200,                   // +2% APY boost
            name: "30-Day Lock"
        });

        tiers[2] = TierConfig({
            lockDuration: 90 days,
            yieldBoostBps: 500,                   // +5% APY boost
            name: "90-Day Lock"
        });

        tiers[3] = TierConfig({
            lockDuration: 365 days,
            yieldBoostBps: 1000,                  // +10% APY boost
            name: "365-Day Lock"
        });
    }

    // ============ External Functions - Liquidity Provision ============

    /**
     * @notice Deposit USDC into the pool
     * @param amount Amount of USDC to deposit (6 decimals)
     * @param tier Lock tier (0-3)
     * @return positionId ID of the created position
     * @return shares Amount of CDO tokens minted
     */
    function deposit(uint256 amount, uint256 tier)
        external
        nonReentrant
        returns (uint256 positionId, uint256 shares)
    {
        if (!config.depositsEnabled) revert DepositsDisabled();
        if (amount == 0) revert InvalidAmount();
        if (amount < config.minDepositAmount) revert BelowMinDeposit();
        if (tier > 3) revert InvalidTier();
        if (stats.totalDeposits + amount > config.maxPoolSize) revert PoolCapReached();

        // Transfer USDC from user
        usdc.safeTransferFrom(msg.sender, address(this), amount);

        // Immediately deposit to YieldVault to start earning yield
        usdc.approve(address(yieldVault), amount);
        yieldVault.depositForBet(address(this), amount);

        // Calculate shares (1:1 ratio for simplicity, could use total supply formula)
        shares = _calculateShares(amount);

        // Determine lock period
        uint256 lockUntil = block.timestamp + tiers[tier].lockDuration;

        // Create position
        Position memory position = Position({
            depositAmount: amount,
            shares: shares,
            depositedAt: block.timestamp,
            lockUntil: lockUntil,
            tier: tier
        });

        positionId = userPositions[msg.sender].length;
        userPositions[msg.sender].push(position);
        userTotalShares[msg.sender] += shares;

        // Update pool stats
        stats.totalDeposits += amount;
        stats.poolBalance += amount;
        stats.totalShares += shares;

        // Mint CDO tokens
        cdoToken.mint(msg.sender, shares);

        emit Deposited(
            msg.sender,
            positionId,
            amount,
            shares,
            tier,
            lockUntil,
            block.timestamp
        );

        return (positionId, shares);
    }

    /**
     * @notice Withdraw USDC from a specific position
     * @param positionId ID of the position to withdraw
     * @return amount Amount of USDC withdrawn
     * @return yieldEarned Yield earned on the position
     */
    function withdraw(uint256 positionId)
        external
        nonReentrant
        returns (uint256 amount, uint256 yieldEarned)
    {
        if (!config.withdrawalsEnabled) revert WithdrawalsDisabled();
        if (positionId >= userPositions[msg.sender].length) revert PositionNotFound();

        Position storage position = userPositions[msg.sender][positionId];
        if (position.shares == 0) revert PositionNotFound(); // Already withdrawn

        uint256 principal = position.depositAmount;
        uint256 shares = position.shares;
        uint256 penalty = 0;

        // Calculate user's share of total pool value
        // Their value = (their shares / total shares) * (pool balance + active bets)
        uint256 totalPoolValue = stats.poolBalance + stats.activeMatchedAmount;
        uint256 userValue = (shares * totalPoolValue) / stats.totalShares;

        // Yield = user value - principal
        uint256 earnedYield = userValue > principal ? userValue - principal : 0;

        uint256 totalAmount = principal + earnedYield;

        // Check if position is locked
        bool isLocked = block.timestamp < position.lockUntil;

        if (isLocked) {
            // Apply early withdrawal penalty
            penalty = (totalAmount * config.earlyWithdrawalFee) / BASIS_POINTS;
            totalAmount -= penalty;
        }

        // Ensure pool has enough available liquidity (not locked in bets)
        if (totalAmount > stats.poolBalance) revert InsufficientPoolLiquidity();

        // Update state BEFORE withdrawal (protect against reentrancy)
        stats.poolBalance -= totalAmount;
        stats.totalShares -= shares;
        userTotalShares[msg.sender] -= shares;

        // Mark position as withdrawn
        position.shares = 0;
        position.depositAmount = 0;

        // Burn CDO tokens
        cdoToken.burn(msg.sender, shares);

        // Withdraw from YieldVault and transfer to user
        // Note: YieldVault withdraws directly to the recipient
        yieldVault.withdrawForBet(address(this), msg.sender);

        emit Withdrawn(
            msg.sender,
            positionId,
            totalAmount,
            shares,
            earnedYield,
            penalty,
            block.timestamp
        );

        return (totalAmount, earnedYield);
    }

    /**
     * @notice Withdraw all positions for a user
     * @return totalAmount Total USDC withdrawn
     * @return totalYield Total yield earned
     */
    function withdrawAll()
        external
        nonReentrant
        returns (uint256 totalAmount, uint256 totalYield)
    {
        if (!config.withdrawalsEnabled) revert WithdrawalsDisabled();

        uint256 positionCount = userPositions[msg.sender].length;

        for (uint256 i = 0; i < positionCount; i++) {
            Position storage position = userPositions[msg.sender][i];

            // Skip already withdrawn positions
            if (position.shares == 0) continue;

            // Skip locked positions
            if (block.timestamp < position.lockUntil) continue;

            uint256 principal = position.depositAmount;
            uint256 shares = position.shares;

            // Calculate user's value for this position (recalculate each time)
            uint256 totalPoolValue = stats.poolBalance + stats.activeMatchedAmount;
            uint256 userValue = (shares * totalPoolValue) / stats.totalShares;
            uint256 earnedYield = userValue > principal ? userValue - principal : 0;
            uint256 amount = principal + earnedYield;

            if (amount > stats.poolBalance) break; // Stop if insufficient liquidity

            // Update state
            totalAmount += amount;
            totalYield += earnedYield;
            stats.poolBalance -= amount;
            stats.totalShares -= shares;
            userTotalShares[msg.sender] -= shares;

            // Mark as withdrawn
            position.shares = 0;
            position.depositAmount = 0;

            // Burn CDO tokens
            cdoToken.burn(msg.sender, shares);

            emit Withdrawn(
                msg.sender,
                i,
                amount,
                shares,
                earnedYield,
                0,
                block.timestamp
            );
        }

        if (totalAmount > 0) {
            // Withdraw from YieldVault
            yieldVault.withdrawForBet(address(this), msg.sender);
        }

        return (totalAmount, totalYield);
    }

    // ============ External Functions - Bet Matching ============

    /**
     * @notice Match pool liquidity with a bet (called by authorized contracts like BetFactory)
     * @param betContract Address of bet contract
     * @param amount Amount to match
     * @return success Whether matching succeeded
     */
    function matchBet(address betContract, uint256 amount)
        external
        nonReentrant
        returns (bool success)
    {
        if (!authorizedMatchers[msg.sender]) revert Unauthorized();
        if (amount == 0) revert InvalidAmount();

        // Check if pool has enough available liquidity
        uint256 availableLiquidity = _calculateAvailableLiquidity();
        if (amount > availableLiquidity) revert InsufficientPoolLiquidity();

        // LAYER 1: Risk validation
        if (address(riskValidator) != address(0)) {
            uint256 currentUtilization = this.getUtilizationRate();

            (bool isValid, string memory reason) = riskValidator.validateBetForMatching(
                betContract,
                availableLiquidity,
                currentUtilization
            );

            if (!isValid) {
                emit ValidationFailed(betContract, reason, block.timestamp);
                revert BetRiskValidationFailed();
            }
        }

        // NO USDC TRANSFER - funds are already in YieldVault earning yield!
        // Just update accounting records

        // Update state
        stats.activeMatchedAmount += amount;
        stats.totalBetsMatched++;
        stats.totalVolumeMatched += amount;
        matchedBetAmounts[betContract] = amount;
        activeBets.push(betContract);

        emit BetMatched(betContract, amount, block.timestamp);

        return true;
    }

    /**
     * @notice Settle a matched bet (called by bet contract or authorized matcher)
     * @param betContract Address of bet contract
     * @param finalAmount Amount returned to pool
     * @param won Whether pool won the bet
     */
    function settleBet(address betContract, uint256 finalAmount, bool won)
        external
        nonReentrant
    {
        if (!authorizedMatchers[msg.sender]) revert Unauthorized();

        uint256 matchedAmount = matchedBetAmounts[betContract];
        require(matchedAmount > 0, "Bet not matched");

        // Calculate profit/loss
        uint256 profit = 0;
        if (finalAmount > matchedAmount) {
            profit = finalAmount - matchedAmount;
            stats.poolBalance += finalAmount;
        } else {
            // Loss scenario
            stats.poolBalance += finalAmount;
        }

        // Update state
        stats.activeMatchedAmount -= matchedAmount;
        delete matchedBetAmounts[betContract];

        emit BetSettled(betContract, matchedAmount, profit, won, block.timestamp);
    }

    // ============ Internal Functions - Yield Calculation ============

    /**
     * @dev Calculate shares to mint for a deposit
     * @param amount USDC amount
     * @return shares Number of shares
     */
    function _calculateShares(uint256 amount) internal view returns (uint256 shares) {
        // For simplicity: 1:1 ratio
        // In production: shares = (amount * totalShares) / totalAssets
        if (stats.totalShares == 0) {
            return amount;
        }

        uint256 totalAssets = stats.poolBalance + stats.activeMatchedAmount;
        if (totalAssets == 0) {
            return amount;
        }

        shares = (amount * stats.totalShares) / totalAssets;
        return shares;
    }


    /**
     * @dev Calculate available liquidity for bet matching
     * @return available Available USDC for matching
     */
    function _calculateAvailableLiquidity() internal view returns (uint256 available) {
        // Keep some liquidity for withdrawals (based on utilization target)
        uint256 targetAvailable = (stats.poolBalance * (BASIS_POINTS - config.utilizationTarget)) / BASIS_POINTS;

        return targetAvailable;
    }

    // ============ Owner Functions ============

    /**
     * @notice Update pool configuration
     */
    function updateConfig(
        uint256 _minDepositAmount,
        uint256 _maxPoolSize,
        uint256 _utilizationTarget,
        uint256 _earlyWithdrawalFee
    ) external onlyOwner {
        require(_utilizationTarget <= BASIS_POINTS, "Invalid utilization");
        require(_earlyWithdrawalFee <= 1000, "Fee too high"); // Max 10%

        config.minDepositAmount = _minDepositAmount;
        config.maxPoolSize = _maxPoolSize;
        config.utilizationTarget = _utilizationTarget;
        config.earlyWithdrawalFee = _earlyWithdrawalFee;

        emit ConfigUpdated("config", block.timestamp);
    }

    /**
     * @notice Set authorized bet matcher
     * @param matcher Address to authorize/deauthorize
     * @param authorized Authorization status
     */
    function setAuthorizedMatcher(address matcher, bool authorized) external onlyOwner {
        require(matcher != address(0), "Invalid matcher");

        authorizedMatchers[matcher] = authorized;

        emit AuthorizedMatcherUpdated(matcher, authorized, block.timestamp);
    }

    /**
     * @notice Pause/unpause deposits
     */
    function setDepositsEnabled(bool enabled) external onlyOwner {
        config.depositsEnabled = enabled;
        emit ConfigUpdated("depositsEnabled", block.timestamp);
    }

    /**
     * @notice Pause/unpause withdrawals
     */
    function setWithdrawalsEnabled(bool enabled) external onlyOwner {
        config.withdrawalsEnabled = enabled;
        emit ConfigUpdated("withdrawalsEnabled", block.timestamp);
    }

    /**
     * @notice Update risk validator contract
     * @param newValidator Address of new risk validator
     */
    function setRiskValidator(address newValidator) external onlyOwner {
        address oldValidator = address(riskValidator);
        riskValidator = BetRiskValidator(newValidator);
        emit RiskValidatorUpdated(oldValidator, newValidator, block.timestamp);
    }

    // ============ View Functions ============

    /**
     * @notice Get user's positions
     * @param user User address
     * @return positions Array of positions
     */
    function getUserPositions(address user) external view returns (Position[] memory) {
        return userPositions[user];
    }

    /**
     * @notice Get specific position details
     * @param user User address
     * @param positionId Position ID
     * @return position Position details
     */
    function getPosition(address user, uint256 positionId) external view returns (Position memory) {
        require(positionId < userPositions[user].length, "Invalid position");
        return userPositions[user][positionId];
    }

    /**
     * @notice Calculate current yield for a position (view function)
     * @param user User address
     * @param positionId Position ID
     * @return pendingYield Pending yield based on share value
     */
    function calculatePendingYield(address user, uint256 positionId)
        external
        view
        returns (uint256 pendingYield)
    {
        if (positionId >= userPositions[user].length) return 0;

        Position memory position = userPositions[user][positionId];
        if (position.shares == 0) return 0;

        // Calculate current value based on shares
        uint256 totalPoolValue = stats.poolBalance + stats.activeMatchedAmount;
        if (stats.totalShares == 0) return 0;

        uint256 userValue = (position.shares * totalPoolValue) / stats.totalShares;
        pendingYield = userValue > position.depositAmount ? userValue - position.depositAmount : 0;

        return pendingYield;
    }

    /**
     * @notice Get pool utilization rate
     * @return utilizationRate Utilization in basis points
     */
    function getUtilizationRate() external view returns (uint256 utilizationRate) {
        if (stats.totalDeposits == 0) return 0;
        return (stats.activeMatchedAmount * BASIS_POINTS) / stats.totalDeposits;
    }

    /**
     * @notice Get available liquidity for matching
     * @return available Available USDC
     */
    function getAvailableLiquidity() external view returns (uint256 available) {
        return _calculateAvailableLiquidity();
    }

    /**
     * @notice Get tier configuration
     * @param tier Tier index (0-3)
     * @return config Tier configuration
     */
    function getTierConfig(uint256 tier) external view returns (TierConfig memory) {
        require(tier <= 3, "Invalid tier");
        return tiers[tier];
    }

    /**
     * @notice Get total user value (deposits + yield)
     * @param user User address
     * @return totalValue Total value across all positions
     */
    function getUserTotalValue(address user) external view returns (uint256 totalValue) {
        uint256 positionCount = userPositions[user].length;
        uint256 totalPoolValue = stats.poolBalance + stats.activeMatchedAmount;

        if (stats.totalShares == 0) return 0;

        for (uint256 i = 0; i < positionCount; i++) {
            Position memory position = userPositions[user][i];
            if (position.shares == 0) continue;

            // Calculate current value based on shares
            uint256 userValue = (position.shares * totalPoolValue) / stats.totalShares;
            totalValue += userValue;
        }

        return totalValue;
    }
}
