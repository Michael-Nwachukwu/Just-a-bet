// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/liquidity/CDOPool.sol";
import "../src/liquidity/CDOToken.sol";
import "../src/liquidity/BetRiskValidator.sol";
import "../src/core/BetYieldVault.sol";
import "../src/mocks/MockUSDC.sol";

contract CDOPoolTest is Test {
    CDOPool public pool;
    CDOToken public cdoToken;
    BetRiskValidator public riskValidator;
    BetYieldVault public yieldVault;
    MockUSDC public usdc;

    address public owner;
    address public alice;
    address public bob;
    address public carol;
    address public treasury;

    uint256 constant USDC_DECIMALS = 6;
    uint256 constant INITIAL_BALANCE = 100_000 * 10**USDC_DECIMALS; // 100k USDC

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

    function setUp() public {
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        carol = makeAddr("carol");
        treasury = makeAddr("treasury");

        // Deploy contracts
        usdc = new MockUSDC();
        cdoToken = new CDOToken("Just-a-Bet CDO", "JAB-CDO");
        yieldVault = new BetYieldVault(address(usdc), treasury);
        riskValidator = new BetRiskValidator();
        pool = new CDOPool(address(usdc), address(cdoToken), address(yieldVault), address(riskValidator));

        // Set pool in CDO token
        cdoToken.setPool(address(pool));

        // Mint USDC to test accounts
        usdc.mint(alice, INITIAL_BALANCE);
        usdc.mint(bob, INITIAL_BALANCE);
        usdc.mint(carol, INITIAL_BALANCE);

        // Approve pool to spend USDC
        vm.prank(alice);
        usdc.approve(address(pool), type(uint256).max);

        vm.prank(bob);
        usdc.approve(address(pool), type(uint256).max);

        vm.prank(carol);
        usdc.approve(address(pool), type(uint256).max);
    }

    // ============ Deployment Tests ============

    function test_Deployment() public view {
        assertEq(address(pool.usdc()), address(usdc));
        assertEq(address(pool.cdoToken()), address(cdoToken));
        assertEq(pool.owner(), owner);

        // Check default config
        (
            uint256 minDeposit,
            uint256 maxPoolSize,
            uint256 utilizationTarget,
            uint256 minLockPeriod,
            uint256 maxLockPeriod,
            uint256 earlyWithdrawalFee,
            bool depositsEnabled,
            bool withdrawalsEnabled
        ) = pool.config();

        assertEq(minDeposit, 10 * 10**USDC_DECIMALS);
        assertEq(maxPoolSize, 1_000_000 * 10**USDC_DECIMALS);
        assertEq(utilizationTarget, 8000); // 80%
        assertEq(minLockPeriod, 0);
        assertEq(maxLockPeriod, 365 days);
        assertEq(earlyWithdrawalFee, 500); // 5%
        assertTrue(depositsEnabled);
        assertTrue(withdrawalsEnabled);
    }

    function test_TierConfiguration() public view {
        // Tier 0: Flexible
        (uint256 duration0, uint256 boost0, string memory name0) = pool.tiers(0);
        assertEq(duration0, 0);
        assertEq(boost0, 0);
        assertEq(name0, "Flexible");

        // Tier 1: 30-day
        (uint256 duration1, uint256 boost1, string memory name1) = pool.tiers(1);
        assertEq(duration1, 30 days);
        assertEq(boost1, 200); // +2%
        assertEq(name1, "30-Day Lock");

        // Tier 2: 90-day
        (uint256 duration2, uint256 boost2, string memory name2) = pool.tiers(2);
        assertEq(duration2, 90 days);
        assertEq(boost2, 500); // +5%
        assertEq(name2, "90-Day Lock");

        // Tier 3: 365-day
        (uint256 duration3, uint256 boost3, string memory name3) = pool.tiers(3);
        assertEq(duration3, 365 days);
        assertEq(boost3, 1000); // +10%
        assertEq(name3, "365-Day Lock");
    }

    // ============ Deposit Tests ============

    function test_Deposit_Flexible() public {
        uint256 depositAmount = 1000 * 10**USDC_DECIMALS;

        vm.expectEmit(true, true, true, true);
        emit Deposited(alice, 0, depositAmount, depositAmount, 0, block.timestamp, block.timestamp);

        vm.prank(alice);
        (uint256 positionId, uint256 shares) = pool.deposit(depositAmount, 0);

        assertEq(positionId, 0);
        assertEq(shares, depositAmount);

        // Check position
        CDOPool.Position memory position = pool.getPosition(alice, 0);
        assertEq(position.depositAmount, depositAmount);
        assertEq(position.shares, shares);
        assertEq(position.tier, 0);
        assertEq(position.lockUntil, block.timestamp); // No lock

        // Check balances
        assertEq(usdc.balanceOf(alice), INITIAL_BALANCE - depositAmount);
        // USDC is held in pool contract (CDOPool manages its own liquidity)
        assertEq(usdc.balanceOf(address(pool)), depositAmount);
        assertEq(cdoToken.balanceOf(alice), shares);

        // Check stats
        (
            uint256 totalDeposits,
            uint256 totalBetsMatched,
            uint256 totalVolumeMatched,
            uint256 totalYieldDistributed,
            uint256 poolBalance,
            uint256 activeMatchedAmount,
            uint256 totalShares
        ) = pool.stats();

        assertEq(totalDeposits, depositAmount);
        assertEq(poolBalance, depositAmount);
        assertEq(totalShares, shares);
        assertEq(totalBetsMatched, 0);
        assertEq(totalVolumeMatched, 0);
        assertEq(activeMatchedAmount, 0);
    }

    function test_Deposit_LockedTier() public {
        uint256 depositAmount = 5000 * 10**USDC_DECIMALS;
        uint256 tier = 2; // 90-day lock

        vm.prank(alice);
        (uint256 positionId, uint256 shares) = pool.deposit(depositAmount, tier);

        CDOPool.Position memory position = pool.getPosition(alice, positionId);
        assertEq(position.tier, tier);
        assertEq(position.lockUntil, block.timestamp + 90 days);
    }

    function test_Deposit_MultiplePositions() public {
        vm.startPrank(alice);

        // First deposit: Flexible
        pool.deposit(1000 * 10**USDC_DECIMALS, 0);

        // Second deposit: 30-day lock
        pool.deposit(2000 * 10**USDC_DECIMALS, 1);

        // Third deposit: 365-day lock
        pool.deposit(3000 * 10**USDC_DECIMALS, 3);

        vm.stopPrank();

        CDOPool.Position[] memory positions = pool.getUserPositions(alice);
        assertEq(positions.length, 3);
        assertEq(positions[0].depositAmount, 1000 * 10**USDC_DECIMALS);
        assertEq(positions[1].depositAmount, 2000 * 10**USDC_DECIMALS);
        assertEq(positions[2].depositAmount, 3000 * 10**USDC_DECIMALS);
    }

    function test_Deposit_RevertIfBelowMinimum() public {
        uint256 depositAmount = 5 * 10**USDC_DECIMALS; // Below 10 USDC minimum

        vm.prank(alice);
        vm.expectRevert(CDOPool.BelowMinDeposit.selector);
        pool.deposit(depositAmount, 0);
    }

    function test_Deposit_RevertIfExceedsPoolCap() public {
        uint256 depositAmount = 1_000_001 * 10**USDC_DECIMALS; // Above 1M cap

        // Mint enough USDC
        usdc.mint(alice, depositAmount);

        vm.prank(alice);
        vm.expectRevert(CDOPool.PoolCapReached.selector);
        pool.deposit(depositAmount, 0);
    }

    function test_Deposit_RevertIfInvalidTier() public {
        vm.prank(alice);
        vm.expectRevert(CDOPool.InvalidTier.selector);
        pool.deposit(1000 * 10**USDC_DECIMALS, 4); // Invalid tier
    }

    function test_Deposit_RevertIfDepositsDisabled() public {
        pool.setDepositsEnabled(false);

        vm.prank(alice);
        vm.expectRevert(CDOPool.DepositsDisabled.selector);
        pool.deposit(1000 * 10**USDC_DECIMALS, 0);
    }

    // ============ Withdrawal Tests ============

    function test_Withdraw_FlexibleTier() public {
        uint256 depositAmount = 1000 * 10**USDC_DECIMALS;

        // Deposit
        vm.prank(alice);
        pool.deposit(depositAmount, 0);

        // Fast forward time (no yield without bet profits in new model)
        vm.warp(block.timestamp + 30 days);

        // Withdraw
        vm.prank(alice);
        (uint256 amount, uint256 yieldEarned) = pool.withdraw(0);

        // Should receive only principal (no yield without bet profits)
        assertEq(amount, depositAmount);
        assertEq(yieldEarned, 0);

        // Check balances
        assertEq(usdc.balanceOf(alice), INITIAL_BALANCE);
        assertEq(cdoToken.balanceOf(alice), 0); // CDO tokens burned
    }

    function test_Withdraw_WithYield() public {
        // Setup: Authorize this test contract as a matcher
        pool.setAuthorizedMatcher(address(this), true);
        pool.setRiskValidator(address(0)); // Disable risk validation for fake bet

        uint256 depositAmount = 10_000 * 10**USDC_DECIMALS;

        vm.prank(alice);
        pool.deposit(depositAmount, 0);

        // Simulate bet profit: pool matches a bet and wins
        address betContract = makeAddr("betContract");
        uint256 matchAmount = 1000 * 10**USDC_DECIMALS;
        pool.matchBet(betContract, matchAmount);

        // Pool wins the bet, returns 2x (profit = 1000 USDC)
        uint256 finalAmount = matchAmount * 2;
        usdc.mint(address(this), finalAmount);
        usdc.transfer(address(pool), finalAmount);
        pool.settleBet(betContract, finalAmount, true);

        // Now withdraw - should get share of profit
        vm.prank(alice);
        (uint256 amount, uint256 yieldEarned) = pool.withdraw(0);

        // Yield should be approximately 1000 USDC (the profit)
        assertGt(yieldEarned, 0);
        assertEq(amount, depositAmount + yieldEarned);
    }

    function test_Withdraw_LockedPosition_WithPenalty() public {
        uint256 depositAmount = 5000 * 10**USDC_DECIMALS;
        uint256 tier = 2; // 90-day lock

        vm.prank(alice);
        pool.deposit(depositAmount, tier);

        // Try to withdraw before lock expires (after 30 days)
        vm.warp(block.timestamp + 30 days);

        uint256 balanceBefore = usdc.balanceOf(alice);

        vm.prank(alice);
        (uint256 amount, uint256 yieldEarned) = pool.withdraw(0);

        // Should have penalty applied (5%)
        assertLt(usdc.balanceOf(alice) - balanceBefore, depositAmount + yieldEarned);

        // Penalty should be approximately 5% of (principal + yield)
        uint256 expectedPenalty = ((depositAmount + yieldEarned) * 500) / 10000;
        assertApproxEqAbs(
            depositAmount + yieldEarned - amount,
            expectedPenalty,
            1 * 10**USDC_DECIMALS
        );
    }

    function test_Withdraw_LockedPosition_NoPenaltyAfterExpiry() public {
        uint256 depositAmount = 5000 * 10**USDC_DECIMALS;
        uint256 tier = 1; // 30-day lock

        vm.prank(alice);
        pool.deposit(depositAmount, tier);

        // Wait for lock to expire
        vm.warp(block.timestamp + 31 days);

        vm.prank(alice);
        (uint256 amount, uint256 yieldEarned) = pool.withdraw(0);

        // No penalty after lock expiry
        assertEq(amount, depositAmount + yieldEarned);
    }

    function test_Withdraw_RevertIfPositionNotFound() public {
        vm.prank(alice);
        vm.expectRevert(CDOPool.PositionNotFound.selector);
        pool.withdraw(0); // No position exists
    }

    function test_Withdraw_RevertIfAlreadyWithdrawn() public {
        vm.prank(alice);
        pool.deposit(1000 * 10**USDC_DECIMALS, 0);

        vm.prank(alice);
        pool.withdraw(0);

        // Try to withdraw again
        vm.prank(alice);
        vm.expectRevert(CDOPool.PositionNotFound.selector);
        pool.withdraw(0);
    }

    function test_Withdraw_RevertIfWithdrawalsDisabled() public {
        vm.prank(alice);
        pool.deposit(1000 * 10**USDC_DECIMALS, 0);

        pool.setWithdrawalsEnabled(false);

        vm.prank(alice);
        vm.expectRevert(CDOPool.WithdrawalsDisabled.selector);
        pool.withdraw(0);
    }

    function test_WithdrawAll() public {
        vm.startPrank(alice);

        // Create 3 positions, all flexible
        pool.deposit(1000 * 10**USDC_DECIMALS, 0);
        pool.deposit(2000 * 10**USDC_DECIMALS, 0);
        pool.deposit(3000 * 10**USDC_DECIMALS, 0);

        vm.stopPrank();

        // Fast forward (no yield without bet profits)
        vm.warp(block.timestamp + 30 days);

        // Withdraw all
        vm.prank(alice);
        (uint256 totalAmount, uint256 totalYield) = pool.withdrawAll();

        // Should withdraw only principal (no profits)
        assertEq(totalAmount, 6000 * 10**USDC_DECIMALS);
        assertEq(totalYield, 0);
        assertEq(cdoToken.balanceOf(alice), 0);
    }

    function test_WithdrawAll_SkipsLockedPositions() public {
        vm.startPrank(alice);

        // Flexible position
        pool.deposit(1000 * 10**USDC_DECIMALS, 0);

        // Locked position (90 days)
        pool.deposit(2000 * 10**USDC_DECIMALS, 2);

        vm.stopPrank();

        // Fast forward only 30 days
        vm.warp(block.timestamp + 30 days);

        // Withdraw all (should only withdraw flexible)
        vm.prank(alice);
        (uint256 totalAmount, uint256 totalYield) = pool.withdrawAll();

        // Should have withdrawn only the flexible position
        assertLt(totalAmount, 2000 * 10**USDC_DECIMALS);

        // CDO tokens from locked position should remain
        assertGt(cdoToken.balanceOf(alice), 0);
    }

    // ============ Yield Calculation Tests ============

    function test_YieldCalculation_NoProfits() public {
        uint256 depositAmount = 10_000 * 10**USDC_DECIMALS;

        vm.prank(alice);
        pool.deposit(depositAmount, 0);

        // Fast forward time (no yield without bet profits)
        vm.warp(block.timestamp + 365 days);

        uint256 pendingYield = pool.calculatePendingYield(alice, 0);

        // No yield without bet profits
        assertEq(pendingYield, 0);
    }

    function test_YieldCalculation_WithBetProfits() public {
        pool.setAuthorizedMatcher(address(this), true);
        pool.setRiskValidator(address(0)); // Disable risk validation for fake bet

        uint256 depositAmount = 10_000 * 10**USDC_DECIMALS;

        vm.prank(alice);
        pool.deposit(depositAmount, 0);

        // Pool matches and wins a bet
        address betContract = makeAddr("betContract");
        uint256 matchAmount = 1000 * 10**USDC_DECIMALS;
        pool.matchBet(betContract, matchAmount);

        // Pool wins 2x
        uint256 finalAmount = matchAmount * 2;
        usdc.mint(address(this), finalAmount);
        usdc.transfer(address(pool), finalAmount);
        pool.settleBet(betContract, finalAmount, true);

        uint256 pendingYield = pool.calculatePendingYield(alice, 0);

        // Should have yield from bet profit
        // Pool matched 1000 USDC, won 2000 USDC back, so profit = 1000 USDC
        // Alice owns 100% of the pool, so she gets 100% of the profit
        assertGt(pendingYield, 0);
        assertApproxEqAbs(pendingYield, 1000 * 10**USDC_DECIMALS, 10 * 10**USDC_DECIMALS);
    }

    function test_YieldCalculation_MultipleUsers() public {
        pool.setAuthorizedMatcher(address(this), true);
        pool.setRiskValidator(address(0)); // Disable risk validation for fake bet

        // Two users deposit equal amounts
        vm.prank(alice);
        pool.deposit(5000 * 10**USDC_DECIMALS, 0);

        vm.prank(bob);
        pool.deposit(5000 * 10**USDC_DECIMALS, 0);

        // Pool wins a bet
        address betContract = makeAddr("betContract");
        uint256 matchAmount = 1000 * 10**USDC_DECIMALS;
        pool.matchBet(betContract, matchAmount);

        uint256 finalAmount = matchAmount * 2;
        usdc.mint(address(this), finalAmount);
        usdc.transfer(address(pool), finalAmount);
        pool.settleBet(betContract, finalAmount, true);

        // Both users should get equal share of profit
        uint256 aliceYield = pool.calculatePendingYield(alice, 0);
        uint256 bobYield = pool.calculatePendingYield(bob, 0);

        // Total profit = 1000 USDC, each user owns 50% of pool, so each gets 500 USDC
        assertApproxEqAbs(aliceYield, 500 * 10**USDC_DECIMALS, 10 * 10**USDC_DECIMALS);
        assertApproxEqAbs(bobYield, 500 * 10**USDC_DECIMALS, 10 * 10**USDC_DECIMALS);
    }

    // ============ Bet Matching Tests ============

    function test_MatchBet() public {
        // Setup: Authorize this test contract as a matcher
        pool.setAuthorizedMatcher(address(this), true);

        // Disable risk validation for this test (using fake bet address)
        pool.setRiskValidator(address(0));

        // Alice deposits liquidity
        vm.prank(alice);
        pool.deposit(10_000 * 10**USDC_DECIMALS, 0);

        address betContract = makeAddr("betContract");
        uint256 matchAmount = 1000 * 10**USDC_DECIMALS;

        // Match bet
        bool success = pool.matchBet(betContract, matchAmount);

        assertTrue(success);
        // NOTE: With immediate YieldVault deposits, USDC stays in vault (not transferred to bet)
        // This is just record-keeping, funds remain in YieldVault earning yield
        assertEq(usdc.balanceOf(betContract), 0); // No transfer to bet contract

        // Check stats
        (
            ,
            uint256 totalBetsMatched,
            uint256 totalVolumeMatched,
            ,
            uint256 poolBalance,
            uint256 activeMatchedAmount,
        ) = pool.stats();

        assertEq(totalBetsMatched, 1);
        assertEq(totalVolumeMatched, matchAmount);
        assertEq(activeMatchedAmount, matchAmount);
        // Pool balance stays same (funds in YieldVault, just tracking active vs available)
        assertEq(poolBalance, 10_000 * 10**USDC_DECIMALS);
    }

    function test_MatchBet_RevertIfUnauthorized() public {
        vm.prank(alice);
        pool.deposit(10_000 * 10**USDC_DECIMALS, 0);

        address betContract = makeAddr("betContract");

        // Try to match without authorization
        vm.expectRevert(CDOPool.Unauthorized.selector);
        pool.matchBet(betContract, 1000 * 10**USDC_DECIMALS);
    }

    function test_MatchBet_RevertIfInsufficientLiquidity() public {
        pool.setAuthorizedMatcher(address(this), true);

        vm.prank(alice);
        pool.deposit(10_000 * 10**USDC_DECIMALS, 0);

        // Try to match more than available (considering utilization target)
        uint256 excessiveAmount = 15_000 * 10**USDC_DECIMALS;

        vm.expectRevert(CDOPool.InsufficientPoolLiquidity.selector);
        pool.matchBet(makeAddr("bet"), excessiveAmount);
    }

    function test_SettleBet_Win() public {
        pool.setAuthorizedMatcher(address(this), true);
        pool.setRiskValidator(address(0)); // Disable risk validation for fake bet

        vm.prank(alice);
        pool.deposit(10_000 * 10**USDC_DECIMALS, 0);

        address betContract = makeAddr("betContract");
        uint256 matchAmount = 1000 * 10**USDC_DECIMALS;

        // Match bet
        pool.matchBet(betContract, matchAmount);

        // Mint USDC to simulate bet winnings
        uint256 finalAmount = matchAmount * 2; // Pool wins
        usdc.mint(address(this), finalAmount);
        usdc.transfer(address(pool), finalAmount);

        // Settle bet
        pool.settleBet(betContract, finalAmount, true);

        // Check pool balance increased
        (, , , , uint256 poolBalance, uint256 activeMatchedAmount, ) = pool.stats();

        assertEq(activeMatchedAmount, 0);
        assertGt(poolBalance, 10_000 * 10**USDC_DECIMALS); // Profit added
    }

    function test_SettleBet_Loss() public {
        pool.setAuthorizedMatcher(address(this), true);
        pool.setRiskValidator(address(0)); // Disable risk validation for fake bet

        vm.prank(alice);
        pool.deposit(10_000 * 10**USDC_DECIMALS, 0);

        address betContract = makeAddr("betContract");
        uint256 matchAmount = 1000 * 10**USDC_DECIMALS;

        // Match bet
        pool.matchBet(betContract, matchAmount);

        // Pool loses bet (returns 0)
        uint256 finalAmount = 0;

        // Settle bet
        pool.settleBet(betContract, finalAmount, false);

        (, , , , uint256 poolBalance, uint256 activeMatchedAmount, ) = pool.stats();

        assertEq(activeMatchedAmount, 0);
        assertLt(poolBalance, 10_000 * 10**USDC_DECIMALS); // Loss deducted
    }

    // ============ Admin Tests ============

    function test_UpdateConfig() public {
        pool.updateConfig(
            20 * 10**USDC_DECIMALS,  // minDeposit
            2_000_000 * 10**USDC_DECIMALS,  // maxPoolSize
            9000,  // utilizationTarget (90%)
            300    // earlyWithdrawalFee (3%)
        );

        (
            uint256 minDeposit,
            uint256 maxPoolSize,
            uint256 utilizationTarget,
            ,
            ,
            uint256 earlyWithdrawalFee,
            ,
        ) = pool.config();

        assertEq(minDeposit, 20 * 10**USDC_DECIMALS);
        assertEq(maxPoolSize, 2_000_000 * 10**USDC_DECIMALS);
        assertEq(utilizationTarget, 9000);
        assertEq(earlyWithdrawalFee, 300);
    }

    function test_SetAuthorizedMatcher() public {
        address matcher = makeAddr("matcher");

        pool.setAuthorizedMatcher(matcher, true);
        assertTrue(pool.authorizedMatchers(matcher));

        pool.setAuthorizedMatcher(matcher, false);
        assertFalse(pool.authorizedMatchers(matcher));
    }

    function test_PauseDeposits() public {
        pool.setDepositsEnabled(false);

        vm.prank(alice);
        vm.expectRevert(CDOPool.DepositsDisabled.selector);
        pool.deposit(1000 * 10**USDC_DECIMALS, 0);

        pool.setDepositsEnabled(true);

        vm.prank(alice);
        pool.deposit(1000 * 10**USDC_DECIMALS, 0);
    }

    function test_PauseWithdrawals() public {
        vm.prank(alice);
        pool.deposit(1000 * 10**USDC_DECIMALS, 0);

        pool.setWithdrawalsEnabled(false);

        vm.prank(alice);
        vm.expectRevert(CDOPool.WithdrawalsDisabled.selector);
        pool.withdraw(0);

        pool.setWithdrawalsEnabled(true);

        vm.prank(alice);
        pool.withdraw(0);
    }

    // ============ View Function Tests ============

    function test_GetUtilizationRate() public {
        pool.setAuthorizedMatcher(address(this), true);
        pool.setRiskValidator(address(0)); // Disable risk validation for fake bet

        vm.prank(alice);
        pool.deposit(10_000 * 10**USDC_DECIMALS, 0);

        // No bets matched yet
        assertEq(pool.getUtilizationRate(), 0);

        // Match a bet
        pool.matchBet(makeAddr("bet1"), 2000 * 10**USDC_DECIMALS);

        // Utilization should be 20%
        uint256 rate = pool.getUtilizationRate();
        assertEq(rate, 2000); // 20% in basis points
    }

    function test_GetUserTotalValue() public {
        vm.startPrank(alice);

        pool.deposit(5000 * 10**USDC_DECIMALS, 0);
        pool.deposit(3000 * 10**USDC_DECIMALS, 1);

        vm.stopPrank();

        // Fast forward
        vm.warp(block.timestamp + 30 days);

        uint256 totalValue = pool.getUserTotalValue(alice);

        // Should equal principal (no yield without bet profits)
        assertEq(totalValue, 8000 * 10**USDC_DECIMALS);
    }

    function test_GetAvailableLiquidity() public {
        vm.prank(alice);
        pool.deposit(10_000 * 10**USDC_DECIMALS, 0);

        uint256 available = pool.getAvailableLiquidity();

        // With 80% utilization target, should have 20% available
        // 20% of 10,000 = 2,000 USDC
        assertApproxEqAbs(available, 2000 * 10**USDC_DECIMALS, 1 * 10**USDC_DECIMALS);
    }

    // ============ Fuzz Tests ============

    function testFuzz_Deposit(uint256 amount, uint8 tier) public {
        // Bound inputs
        amount = bound(amount, 10 * 10**USDC_DECIMALS, 100_000 * 10**USDC_DECIMALS);
        tier = uint8(bound(tier, 0, 3));

        vm.prank(alice);
        (uint256 positionId, uint256 shares) = pool.deposit(amount, tier);

        assertEq(positionId, 0);
        assertEq(shares, amount);

        CDOPool.Position memory position = pool.getPosition(alice, positionId);
        assertEq(position.depositAmount, amount);
        assertEq(position.tier, tier);
    }

    function testFuzz_DepositAndWithdraw(uint256 amount, uint256 timeElapsed) public {
        // Bound inputs
        amount = bound(amount, 10 * 10**USDC_DECIMALS, 50_000 * 10**USDC_DECIMALS);
        timeElapsed = bound(timeElapsed, 1 days, 365 days);

        vm.prank(alice);
        pool.deposit(amount, 0);

        vm.warp(block.timestamp + timeElapsed);

        vm.prank(alice);
        (uint256 withdrawnAmount, uint256 yieldEarned) = pool.withdraw(0);

        // No yield without bet profits
        assertEq(withdrawnAmount, amount);
        assertEq(yieldEarned, 0);
    }
}
