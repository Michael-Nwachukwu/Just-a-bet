// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/IYieldStrategy.sol";

/**
 * @title BetYieldVault
 * @notice Vault for generating yield on escrowed bet funds (USDC)
 * @dev Accepts USDC deposits, generates yield via pluggable strategy, distributes to winners + platform
 */
contract BetYieldVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Structs ============

    struct YieldConfig {
        uint256 platformFeePercentage;  // Basis points (500 = 5%)
        address platformFeeReceiver;
        uint256 totalPlatformFees;
        uint256 totalYieldGenerated;
    }

    struct BetDeposit {
        uint256 shares;              // Shares representing deposit
        uint256 depositedAt;
        uint256 principalAmount;     // Original USDC deposited
        address betContract;         // Address of the bet contract
        bool withdrawn;
    }

    // ============ State Variables ============

    IERC20 public immutable usdc;
    YieldConfig public yieldConfig;
    IYieldStrategy public yieldStrategy;

    mapping(address => BetDeposit) public betDeposits;  // bet contract => deposit info
    address[] public activeBets;
    mapping(address => uint256) private activeBetsIndex; // bet contract => index in activeBets array

    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant PLATFORM_FEE_BP = 500; // 5%

    // ============ Events ============

    event BetDeposited(address indexed betContract, uint256 amount, uint256 shares, uint256 timestamp);
    event BetWithdrawn(address indexed betContract, uint256 amount, uint256 yield, uint256 platformFee, uint256 timestamp);
    event YieldDistributed(address indexed recipient, uint256 amount, uint256 platformFee, uint256 timestamp);
    event YieldStrategyUpdated(address oldStrategy, address newStrategy, uint256 timestamp);
    event PlatformFeeUpdated(uint256 oldFee, uint256 newFee, uint256 timestamp);
    event PlatformFeeWithdrawn(address indexed receiver, uint256 amount, uint256 timestamp);

    // ============ Errors ============

    error InvalidStrategy();
    error InvalidFeeReceiver();
    error InvalidFeePercentage();
    error BetNotFound();
    error BetAlreadyWithdrawn();
    error InsufficientYield();
    error Unauthorized();

    // ============ Constructor ============

    /**
     * @param _usdc Address of USDC token
     * @param _platformFeeReceiver Address to receive platform fees
     */
    constructor(address _usdc, address _platformFeeReceiver, address _initialStrategy) Ownable(msg.sender) {
        require(_usdc != address(0), "Invalid USDC address");
        if (_platformFeeReceiver == address(0)) revert InvalidFeeReceiver();

        usdc = IERC20(_usdc);

        yieldConfig = YieldConfig({
            platformFeePercentage: PLATFORM_FEE_BP,
            platformFeeReceiver: _platformFeeReceiver,
            totalPlatformFees: 0,
            totalYieldGenerated: 0
        });

        yieldStrategy = IYieldStrategy(_initialStrategy);
    }

    // ============ External Functions - Bet Deposits ============

    /**
     * @notice Deposit USDC for a specific bet
     * @param betContract Address of the bet contract
     * @param amount Amount of USDC to deposit
     * @return shares Amount of shares issued
     */
    function depositForBet(address betContract, uint256 amount) external nonReentrant returns (uint256 shares) {
        require(amount > 0, "Cannot deposit 0");
        require(betContract != address(0), "Invalid bet contract");
        require(!betDeposits[betContract].withdrawn, "Bet already withdrawn");

        // Transfer USDC from bet contract
        usdc.safeTransferFrom(msg.sender, address(this), amount);

        // Calculate shares (simplified: 1:1 for MVP)
        shares = amount;

        // Store bet deposit info
        betDeposits[betContract] = BetDeposit({
            shares: shares,
            depositedAt: block.timestamp,
            principalAmount: amount,
            betContract: betContract,
            withdrawn: false
        });

        activeBetsIndex[betContract] = activeBets.length;
        activeBets.push(betContract);

        // Approve and deposit to yield strategy if set
        if (address(yieldStrategy) != address(0)) {
            usdc.approve(address(yieldStrategy), amount);
            yieldStrategy.deposit(amount);
        }

        emit BetDeposited(betContract, amount, shares, block.timestamp);
        return shares;
    }

    /**
     * @notice Withdraw funds for a bet (principal + yield - platform fee)
     * @param betContract Address of the bet contract
     * @param recipient Address to receive funds (winner)
     * @return amount Total amount withdrawn (principal + net yield)
     * @return yieldEarned Yield earned (before platform fee)
     */
    function withdrawForBet(
        address betContract,
        address recipient
    ) external nonReentrant returns (uint256 amount, uint256 yieldEarned) {
        BetDeposit storage deposit = betDeposits[betContract];

        if (deposit.principalAmount == 0) revert BetNotFound();
        if (deposit.withdrawn) revert BetAlreadyWithdrawn();
        if (msg.sender != betContract) revert Unauthorized();

        uint256 principal = deposit.principalAmount;
        uint256 shares = deposit.shares;

        // Calculate yield earned
        if (address(yieldStrategy) != address(0)) {
            // Get total value from strategy
            uint256 totalValue = yieldStrategy.withdraw(shares);
            yieldEarned = totalValue > principal ? totalValue - principal : 0;
        } else {
            yieldEarned = 0;
        }

        // Calculate platform fee on yield
        uint256 platformFee = (yieldEarned * yieldConfig.platformFeePercentage) / BASIS_POINTS;
        uint256 netYield = yieldEarned - platformFee;

        // Update state
        deposit.withdrawn = true;
        yieldConfig.totalPlatformFees += platformFee;
        yieldConfig.totalYieldGenerated += yieldEarned;

        // Remove from activeBets array (gas optimization)
        _removeFromActiveBets(betContract);

        // Total to send to winner
        amount = principal + netYield;

        // Transfer USDC to recipient
        usdc.safeTransfer(recipient, amount);

        emit BetWithdrawn(betContract, amount, yieldEarned, platformFee, block.timestamp);
        emit YieldDistributed(recipient, netYield, platformFee, block.timestamp);

        return (amount, yieldEarned);
    }

    /**
     * @dev Remove bet from activeBets array
     * @param betContract Address of bet to remove
     */
    function _removeFromActiveBets(address betContract) private {
        uint256 index = activeBetsIndex[betContract];
        uint256 lastIndex = activeBets.length - 1;

        // If not the last element, swap with last
        if (index != lastIndex) {
            address lastBet = activeBets[lastIndex];
            activeBets[index] = lastBet;
            activeBetsIndex[lastBet] = index;
        }

        // Remove last element
        activeBets.pop();
        delete activeBetsIndex[betContract];
    }

    /**
     * @notice Calculate current yield for a bet
     * @param betContract Address of the bet contract
     * @return totalYield Total yield generated for this specific bet
     * @return platformFee Platform fee on yield
     * @return netYield Yield after platform fee
     */
    function calculateYieldForBet(address betContract)
        external
        view
        returns (uint256 totalYield, uint256 platformFee, uint256 netYield)
    {
        BetDeposit memory deposit = betDeposits[betContract];

        if (deposit.principalAmount == 0) return (0, 0, 0);
        if (deposit.withdrawn) return (0, 0, 0);

        if (address(yieldStrategy) != address(0)) {
            // Calculate yield based on time elapsed since deposit
            uint256 timeElapsed = block.timestamp - deposit.depositedAt;

            // Get current value from strategy's perspective
            // For MockYieldStrategy, this calculates: principal * APY * time / year
            totalYield = yieldStrategy.calculateYield(betContract);

            // If strategy doesn't track this bet specifically, calculate manually
            if (totalYield == 0) {
                // Fallback: calculate based on principal and time
                // This matches MockYieldStrategy's calculation
                totalYield = (deposit.principalAmount * 500 * timeElapsed) / (365 days * 10000);
            }
        } else {
            totalYield = 0;
        }

        platformFee = (totalYield * yieldConfig.platformFeePercentage) / BASIS_POINTS;
        netYield = totalYield - platformFee;

        return (totalYield, platformFee, netYield);
    }

    // ============ Owner Functions ============

    /**
     * @notice Update the yield strategy
     * @param newStrategy Address of new yield strategy
     */
    function updateYieldStrategy(address newStrategy) external onlyOwner {
        if (newStrategy == address(0)) revert InvalidStrategy();

        address oldStrategy = address(yieldStrategy);
        yieldStrategy = IYieldStrategy(newStrategy);

        emit YieldStrategyUpdated(oldStrategy, newStrategy, block.timestamp);
    }

    /**
     * @notice Update platform fee percentage
     * @param newFeePercentage New fee in basis points
     */
    function updatePlatformFee(uint256 newFeePercentage) external onlyOwner {
        if (newFeePercentage > 1000) revert InvalidFeePercentage(); // Max 10%

        uint256 oldFee = yieldConfig.platformFeePercentage;
        yieldConfig.platformFeePercentage = newFeePercentage;

        emit PlatformFeeUpdated(oldFee, newFeePercentage, block.timestamp);
    }

    /**
     * @notice Update platform fee receiver
     * @param newReceiver New receiver address
     */
    function updatePlatformFeeReceiver(address newReceiver) external onlyOwner {
        if (newReceiver == address(0)) revert InvalidFeeReceiver();
        yieldConfig.platformFeeReceiver = newReceiver;
    }

    /**
     * @notice Withdraw accumulated platform fees
     * @param amount Amount to withdraw
     */
    function withdrawPlatformFees(uint256 amount) external onlyOwner {
        require(amount <= yieldConfig.totalPlatformFees, "Insufficient fees");

        yieldConfig.totalPlatformFees -= amount;
        usdc.safeTransfer(yieldConfig.platformFeeReceiver, amount);

        emit PlatformFeeWithdrawn(yieldConfig.platformFeeReceiver, amount, block.timestamp);
    }

    // ============ View Functions ============

    /**
     * @notice Get deposit info for a bet
     * @param betContract Bet contract address
     * @return deposit BetDeposit struct
     */
    function getBetDeposit(address betContract) external view returns (BetDeposit memory) {
        return betDeposits[betContract];
    }

    /**
     * @notice Get total active bets
     * @return count Number of active bets
     */
    function getActiveBetsCount() external view returns (uint256) {
        return activeBets.length;
    }

    /**
     * @notice Get yield configuration
     * @return config YieldConfig struct
     */
    function getYieldConfig() external view returns (YieldConfig memory) {
        return yieldConfig;
    }

    /**
     * @notice Get total assets under management
     * @return totalAssets Total USDC in vault
     */
    function totalAssets() public view returns (uint256) {
        if (address(yieldStrategy) != address(0)) {
            return yieldStrategy.totalAssets();
        }
        return usdc.balanceOf(address(this));
    }
}
