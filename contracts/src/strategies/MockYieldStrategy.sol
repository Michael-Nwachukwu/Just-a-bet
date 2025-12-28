// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IYieldStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title MockYieldStrategy
 * @notice Mock yield strategy for testing on Mantle Testnet
 * @dev Simulates yield generation with time-based APY calculation on USDC
 *      Used for testnet only - replace with real Lendle/Bybit integration on mainnet
 */
contract MockYieldStrategy is IYieldStrategy, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Constants ============

    uint256 public constant ANNUAL_APY = 500; // 5% APY in basis points
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    // ============ State Variables ============

    IERC20 public immutable usdc;

    struct Deposit {
        uint256 amount;          // Principal deposited (USDC)
        uint256 shares;          // Shares issued
        uint256 depositTime;     // Weighted average deposit time
        uint256 totalDeposited;  // Track total deposited for weighted average
    }

    mapping(address => Deposit) public deposits;
    uint256 public totalDeposited;
    uint256 public totalSharesIssued;

    // ============ Events ============

    event Deposited(address indexed depositor, uint256 amount, uint256 shares, uint256 timestamp);
    event Withdrawn(address indexed depositor, uint256 amount, uint256 yield, uint256 timestamp);

    // ============ Errors ============

    error NoDeposit();
    error InsufficientShares();
    error TransferFailed();

    // ============ Constructor ============

    constructor(address _usdc) Ownable(msg.sender) {
        require(_usdc != address(0), "Invalid USDC address");
        usdc = IERC20(_usdc);
    }

    // ============ External Functions ============

    /**
     * @notice Deposit USDC into the mock strategy
     * @param amount Amount of USDC to deposit
     * @return shares Amount of shares issued (1:1 for simplicity)
     */
    function deposit(uint256 amount) external override nonReentrant returns (uint256 shares) {
        require(amount > 0, "Cannot deposit 0");

        // Transfer USDC from depositor
        usdc.safeTransferFrom(msg.sender, address(this), amount);

        // For simplicity, shares = amount (1:1 ratio)
        shares = amount;

        Deposit storage userDeposit = deposits[msg.sender];

        // Calculate weighted average deposit time to preserve yield history
        uint256 oldAmount = userDeposit.amount;
        uint256 newTotalAmount = oldAmount + amount;

        if (oldAmount > 0) {
            // Weighted average: (oldAmount * oldTime + newAmount * newTime) / totalAmount
            userDeposit.depositTime = (oldAmount * userDeposit.depositTime + amount * block.timestamp) / newTotalAmount;
        } else {
            // First deposit
            userDeposit.depositTime = block.timestamp;
        }

        userDeposit.amount = newTotalAmount;
        userDeposit.shares += shares;
        userDeposit.totalDeposited += amount;

        totalDeposited += amount;
        totalSharesIssued += shares;

        emit Deposited(msg.sender, amount, shares, block.timestamp);
        return shares;
    }

    /**
     * @notice Withdraw USDC with simulated yield
     * @param shares Amount of shares to redeem
     * @return amount Amount of USDC returned (principal + yield)
     */
    function withdraw(uint256 shares) external override nonReentrant returns (uint256 amount) {
        Deposit storage userDeposit = deposits[msg.sender];
        if (userDeposit.shares == 0) revert NoDeposit();
        if (userDeposit.shares < shares) revert InsufficientShares();

        // Calculate principal portion
        uint256 principal = (userDeposit.amount * shares) / userDeposit.shares;

        // Calculate yield based on time elapsed
        uint256 timeElapsed = block.timestamp - userDeposit.depositTime;
        uint256 yieldEarned = _calculateYield(principal, timeElapsed);

        // Total amount to return
        amount = principal + yieldEarned;

        // Safety check: ensure contract has enough USDC to pay out
        uint256 contractBalance = usdc.balanceOf(address(this));
        if (contractBalance < amount) {
            // Cap yield to available balance
            amount = contractBalance;
            yieldEarned = amount > principal ? amount - principal : 0;
        }

        // Update state
        userDeposit.amount -= principal;
        userDeposit.shares -= shares;
        totalDeposited -= principal;
        totalSharesIssued -= shares;

        // If fully withdrawn, reset deposit time
        if (userDeposit.shares == 0) {
            userDeposit.depositTime = 0;
            userDeposit.totalDeposited = 0;
        }

        // Transfer USDC (including simulated yield from contract balance)
        usdc.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount, yieldEarned, block.timestamp);
        return amount;
    }

    /**
     * @notice Calculate current yield for a depositor
     * @param depositor Address to calculate yield for
     * @return yield Amount of yield earned (not principal)
     */
    function calculateYield(address depositor) external view override returns (uint256 yield) {
        Deposit memory userDeposit = deposits[depositor];
        if (userDeposit.amount == 0) return 0;

        uint256 timeElapsed = block.timestamp - userDeposit.depositTime;
        return _calculateYield(userDeposit.amount, timeElapsed);
    }

    /**
     * @notice Get total assets in the strategy
     * @return totalAssets Total deposited USDC amount (excludes yield)
     */
    function totalAssets() external view override returns (uint256) {
        return totalDeposited;
    }

    /**
     * @notice Get user's share balance
     * @param depositor Address to query
     * @return balance Share balance
     */
    function balanceOf(address depositor) external view override returns (uint256) {
        return deposits[depositor].shares;
    }

    // ============ Internal Functions ============

    /**
     * @dev Calculate yield: principal * APY * timeElapsed / (365 days * 10000)
     * @param principal Principal amount
     * @param timeElapsed Time elapsed since deposit
     * @return yield Calculated yield amount
     */
    function _calculateYield(uint256 principal, uint256 timeElapsed) internal pure returns (uint256) {
        // yield = (principal * APY * timeElapsed) / (SECONDS_PER_YEAR * BASIS_POINTS)
        return (principal * ANNUAL_APY * timeElapsed) / (SECONDS_PER_YEAR * BASIS_POINTS);
    }

    // ============ Owner Functions ============

    /**
     * @notice Fund the contract with USDC to simulate yield payouts
     * @param amount Amount of USDC to fund
     * @dev In production, yield comes from real DeFi protocols
     */
    function fundStrategy(uint256 amount) external onlyOwner {
        usdc.safeTransferFrom(msg.sender, address(this), amount);
    }

    /**
     * @notice Emergency withdraw (owner only)
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(uint256 amount) external onlyOwner {
        usdc.safeTransfer(msg.sender, amount);
    }
}
