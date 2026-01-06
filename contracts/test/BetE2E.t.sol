// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/core/Bet.sol";
import "../src/core/BetFactory.sol";
import "../src/core/BetYieldVault.sol";
import "../src/core/UsernameRegistry.sol";
import "../src/strategies/MockYieldStrategy.sol";
import "../src/mocks/MockUSDC.sol";

/**
 * @title BetE2E
 * @notice End-to-end tests for the entire betting system with yield generation
 */
contract BetE2ETest is Test {
    // Contracts
    MockUSDC public usdc;
    UsernameRegistry public registry;
    MockYieldStrategy public yieldStrategy;
    BetYieldVault public yieldVault;
    BetFactory public betFactory;

    // Test accounts
    address public alice;
    address public bob;
    address public platformFeeReceiver;

    // Constants
    uint256 constant INITIAL_USDC = 100_000 * 10**6; // 100k USDC
    uint256 constant BET_STAKE = 1000 * 10**6;       // 1000 USDC
    uint256 constant BET_DURATION = 7 days;

    function setUp() public {
        // Create test accounts
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        platformFeeReceiver = makeAddr("platformFeeReceiver");

        // Deploy contracts
        usdc = new MockUSDC();
        registry = new UsernameRegistry();
        yieldStrategy = new MockYieldStrategy(address(usdc));
        yieldVault = new BetYieldVault(address(usdc), platformFeeReceiver, address(yieldStrategy));
        betFactory = new BetFactory(address(usdc), address(registry));

        // Configure vault with yield strategy
        yieldVault.updateYieldStrategy(address(yieldStrategy));

        // Set yield vault in factory
        betFactory.setYieldVault(address(yieldVault));

        // Register usernames
        vm.prank(alice);
        registry.registerUsername("alice");

        vm.prank(bob);
        registry.registerUsername("bob");

        // Fund test accounts with USDC
        usdc.mint(alice, INITIAL_USDC);
        usdc.mint(bob, INITIAL_USDC);

        // Fund yield strategy to simulate yield payouts
        usdc.mint(address(this), 10_000 * 10**6);
        usdc.approve(address(yieldStrategy), 10_000 * 10**6);
        yieldStrategy.fundStrategy(10_000 * 10**6);

        // Label addresses for better trace output
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(address(usdc), "USDC");
        vm.label(address(yieldVault), "YieldVault");
        vm.label(address(yieldStrategy), "YieldStrategy");
    }

    // ============ Happy Path Tests ============

    function test_FullBetLifecycle_WithYield_CreatorWins() public {
        // 1. Alice creates bet
        vm.startPrank(alice);

        string[] memory tags = new string[](2);
        tags[0] = "sports";
        tags[1] = "NBA";

        address betAddr = betFactory.createBet(
            "bob",
            BET_STAKE,
            "Lakers will win the championship",
            "Official NBA announcement",
            BET_DURATION,
            tags
        );

        Bet bet = Bet(betAddr);

        // Approve and fund creator's stake
        usdc.approve(betAddr, BET_STAKE);
        bet.fundCreator();
        vm.stopPrank();

        // 2. Bob accepts and funds
        vm.startPrank(bob);
        usdc.approve(betAddr, BET_STAKE);
        bet.acceptBet();
        vm.stopPrank();

        // Verify bet is active and both funded
        assertTrue(bet.isBothFunded());
        (,,,,,,,,Bet.BetState state,) = bet.betDetails();
        assertEq(uint(state), uint(Bet.BetState.Active));

        // 3. Warp time to end of bet (7 days)
        vm.warp(block.timestamp + BET_DURATION + 1);

        // 4. Verify yield has been generated
        (uint256 totalYield, uint256 platformFee, uint256 netYield) = yieldVault.calculateYieldForBet(betAddr);
        console.log("Total Yield Generated:", totalYield);
        console.log("Platform Fee (5%):", platformFee);
        console.log("Net Yield to Winner:", netYield);

        assertGt(totalYield, 0, "Yield should be generated");
        assertEq(platformFee, totalYield * 500 / 10000, "Platform fee should be 5%");

        // 5. Alice declares outcome (Alice wins) - Winner declares victory
        vm.prank(alice);
        bet.declareOutcome(Bet.Outcome.CreatorWins);

        // 6. Warp past dispute window (24 hours)
        vm.warp(block.timestamp + 24 hours + 1);

        // 7. Finalize resolution
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);
        bet.finalizeResolution();
        uint256 aliceBalanceAfter = usdc.balanceOf(alice);

        // 8. Verify Alice received stake + yield
        uint256 aliceWinnings = aliceBalanceAfter - aliceBalanceBefore;
        
        // Calculate net yield from winnings (winnings - 2*stake)
        uint256 netYieldReceived = aliceWinnings > BET_STAKE * 2 ? aliceWinnings - BET_STAKE * 2 : 0;
        uint256 expectedWinnings = BET_STAKE * 2 + netYield;

        console.log("Alice's Winnings:", aliceWinnings);
        console.log("Expected Winnings:", expectedWinnings);

        // Allow small rounding difference (yield increases over time, so actual may be higher)
        assertApproxEqRel(aliceWinnings, expectedWinnings, 0.05e18); // 5% tolerance to account for additional yield during dispute window

        // 9. Verify platform fees collected (5% of total yield)
        uint256 actualPlatformFee = yieldVault.getYieldConfig().totalPlatformFees;
        // Platform fee = 5% of total yield, where totalYield = netYield / 0.95
        // So: platformFee = (netYieldReceived / 0.95) * 0.05 = netYieldReceived * 5 / 95
        if (netYieldReceived > 0) {
            uint256 expectedPlatformFee = netYieldReceived * 500 / 9500;
            assertApproxEqRel(actualPlatformFee, expectedPlatformFee, 0.1e18, "Platform fee should be approximately 5% of yield");
        }
        assertGt(actualPlatformFee, 0, "Platform fees should be collected");

        // 10. Verify bet is resolved
        (,,,,,,,,state,) = bet.betDetails();
        assertEq(uint(state), uint(Bet.BetState.Resolved));
    }

    function test_FullBetLifecycle_WithYield_OpponentWins() public {
        // Create bet
        vm.startPrank(alice);
        string[] memory tags = new string[](1);
        tags[0] = "crypto";

        address betAddr = betFactory.createBet(
            "bob",
            BET_STAKE,
            "Bitcoin will reach $100k",
            "CoinGecko price",
            BET_DURATION,
            tags
        );

        Bet bet = Bet(betAddr);
        usdc.approve(betAddr, BET_STAKE);
        bet.fundCreator();
        vm.stopPrank();

        // Bob accepts
        vm.startPrank(bob);
        usdc.approve(betAddr, BET_STAKE);
        bet.acceptBet();
        vm.stopPrank();

        // Warp to end
        vm.warp(block.timestamp + BET_DURATION + 1);

        // Bob declares Bob wins (winner declares victory)
        vm.prank(bob);
        bet.declareOutcome(Bet.Outcome.OpponentWins);

        // Warp past dispute window
        vm.warp(block.timestamp + 24 hours + 1);

        // Finalize
        uint256 bobBalanceBefore = usdc.balanceOf(bob);
        bet.finalizeResolution();
        uint256 bobBalanceAfter = usdc.balanceOf(bob);

        // Verify Bob won
        assertGt(bobBalanceAfter, bobBalanceBefore);
        console.log("Bob's Winnings:", bobBalanceAfter - bobBalanceBefore);
    }

    function test_Draw_SplitsFunds() public {
        // Create and fund bet
        vm.startPrank(alice);
        string[] memory tags = new string[](0);
        address betAddr = betFactory.createBet(
            "bob",
            BET_STAKE,
            "Will it rain tomorrow?",
            "Weather.com",
            BET_DURATION,
            tags
        );

        Bet bet = Bet(betAddr);
        usdc.approve(betAddr, BET_STAKE);
        bet.fundCreator();
        vm.stopPrank();

        vm.startPrank(bob);
        usdc.approve(betAddr, BET_STAKE);
        bet.acceptBet();
        vm.stopPrank();

        // Warp to end
        vm.warp(block.timestamp + BET_DURATION + 1);

        // Alice declares draw
        vm.prank(alice);
        bet.declareOutcome(Bet.Outcome.Draw);

        // Warp past dispute window
        vm.warp(block.timestamp + 24 hours + 1);

        // Finalize
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);
        uint256 bobBalanceBefore = usdc.balanceOf(bob);

        bet.finalizeResolution();

        uint256 aliceBalanceAfter = usdc.balanceOf(alice);
        uint256 bobBalanceAfter = usdc.balanceOf(bob);

        // Both should get their stake back + half of yield
        console.log("Alice received:", aliceBalanceAfter - aliceBalanceBefore);
        console.log("Bob received:", bobBalanceAfter - bobBalanceBefore);

        // They should receive approximately equal amounts
        assertApproxEqRel(
            aliceBalanceAfter - aliceBalanceBefore,
            bobBalanceAfter - bobBalanceBefore,
            0.05e18 // 5% tolerance
        );
    }

    // ============ Dispute Tests ============

    function test_DisputeRaised() public {
        // Create and fund bet
        vm.startPrank(alice);
        string[] memory tags = new string[](0);
        address betAddr = betFactory.createBet(
            "bob",
            BET_STAKE,
            "Test bet",
            "Outcome",
            BET_DURATION,
            tags
        );

        Bet bet = Bet(betAddr);
        usdc.approve(betAddr, BET_STAKE);
        bet.fundCreator();
        vm.stopPrank();

        vm.startPrank(bob);
        usdc.approve(betAddr, BET_STAKE);
        bet.acceptBet();
        vm.stopPrank();

        // Warp to end
        vm.warp(block.timestamp + BET_DURATION + 1);

        // Alice declares Alice wins (winner declares victory)
        vm.prank(alice);
        bet.declareOutcome(Bet.Outcome.CreatorWins);

        // Bob disputes (loser disputes if they disagree)
        vm.prank(bob);
        bet.raiseDispute();

        // Verify bet is disputed
        (,,,,,,,,Bet.BetState state,) = bet.betDetails();
        assertEq(uint(state), uint(Bet.BetState.Disputed));
    }

    function test_CannotDisputeAfterDeadline() public {
        // Create and fund bet
        vm.startPrank(alice);
        string[] memory tags = new string[](0);
        address betAddr = betFactory.createBet(
            "bob",
            BET_STAKE,
            "Test bet",
            "Outcome",
            BET_DURATION,
            tags
        );

        Bet bet = Bet(betAddr);
        usdc.approve(betAddr, BET_STAKE);
        bet.fundCreator();
        vm.stopPrank();

        vm.startPrank(bob);
        usdc.approve(betAddr, BET_STAKE);
        bet.acceptBet();
        vm.stopPrank();

        // Warp to end
        vm.warp(block.timestamp + BET_DURATION + 1);

        // Alice declares she won
        vm.prank(alice);
        bet.declareOutcome(Bet.Outcome.CreatorWins);

        // Warp past dispute window
        vm.warp(block.timestamp + 24 hours + 2);

        // Bob tries to dispute - should fail (too late)
        vm.prank(bob);
        vm.expectRevert(Bet.DisputeWindowExpired.selector);
        bet.raiseDispute();
    }

    // ============ Yield Calculation Tests ============

    function test_YieldIncreasesWithTime() public {
        // Create and fund bet
        vm.startPrank(alice);
        string[] memory tags = new string[](0);
        address betAddr = betFactory.createBet(
            "bob",
            BET_STAKE,
            "Test bet",
            "Outcome",
            30 days, // Longer duration for more yield
            tags
        );

        Bet bet = Bet(betAddr);
        usdc.approve(betAddr, BET_STAKE);
        bet.fundCreator();
        vm.stopPrank();

        vm.startPrank(bob);
        usdc.approve(betAddr, BET_STAKE);
        bet.acceptBet();
        vm.stopPrank();

        // Check yield at different time points
        (uint256 yield1,,) = yieldVault.calculateYieldForBet(betAddr);
        console.log("Yield at T+0:", yield1);

        vm.warp(block.timestamp + 7 days);
        (uint256 yield2,,) = yieldVault.calculateYieldForBet(betAddr);
        console.log("Yield at T+7 days:", yield2);

        vm.warp(block.timestamp + 7 days); // T+14 days
        (uint256 yield3,,) = yieldVault.calculateYieldForBet(betAddr);
        console.log("Yield at T+14 days:", yield3);

        // Yield should increase over time
        assertGt(yield2, yield1);
        assertGt(yield3, yield2);
    }

    function test_PlatformFeesAccumulate() public {
        uint256 initialPlatformFees = yieldVault.getYieldConfig().totalPlatformFees;

        // Create and resolve multiple bets
        for (uint i = 0; i < 3; i++) {
            vm.startPrank(alice);
            string[] memory tags = new string[](0);
            address betAddr = betFactory.createBet(
                "bob",
                BET_STAKE,
                string(abi.encodePacked("Bet #", vm.toString(i))),
                "Outcome",
                BET_DURATION,
                tags
            );

            Bet bet = Bet(betAddr);
            usdc.approve(betAddr, BET_STAKE);
            bet.fundCreator();
            vm.stopPrank();

            vm.startPrank(bob);
            usdc.approve(betAddr, BET_STAKE);
            bet.acceptBet();
            vm.stopPrank();

            vm.warp(block.timestamp + BET_DURATION + 1);

            vm.prank(alice);
            bet.declareOutcome(Bet.Outcome.CreatorWins);

            vm.warp(block.timestamp + 24 hours + 1);
            bet.finalizeResolution();
        }

        uint256 finalPlatformFees = yieldVault.getYieldConfig().totalPlatformFees;
        console.log("Platform Fees Accumulated:", finalPlatformFees - initialPlatformFees);

        assertGt(finalPlatformFees, initialPlatformFees, "Platform fees should accumulate");
    }

    // ============ Factory Tests ============

    function test_Factory_TracksUserBets() public {
        // Alice creates bet
        vm.startPrank(alice);
        string[] memory tags = new string[](0);
        betFactory.createBet(
            "bob",
            BET_STAKE,
            "Bet 1",
            "Outcome",
            BET_DURATION,
            tags
        );
        vm.stopPrank();

        // Check Alice's bets
        address[] memory aliceBets = betFactory.getBetsForUser(alice);
        assertEq(aliceBets.length, 1);

        // Check Bob's bets (as opponent)
        address[] memory bobBets = betFactory.getBetsForUser(bob);
        assertEq(bobBets.length, 1);

        // Should be the same bet
        assertEq(aliceBets[0], bobBets[0]);
    }

    function test_Factory_EnforcesMinStake() public {
        vm.startPrank(alice);
        string[] memory tags = new string[](0);

        vm.expectRevert(BetFactory.InvalidStakeAmount.selector);
        betFactory.createBet(
            "bob",
            0.5 * 10**6, // Less than 1 USDC minimum
            "Small bet",
            "Outcome",
            BET_DURATION,
            tags
        );
        vm.stopPrank();
    }

    function test_Factory_ResolvesUsernameToAddress() public {
        vm.startPrank(alice);
        string[] memory tags = new string[](0);

        address betAddr = betFactory.createBet(
            "bob", // Using username instead of address
            BET_STAKE,
            "Test username resolution",
            "Outcome",
            BET_DURATION,
            tags
        );

        Bet bet = Bet(betAddr);
        (,address opponent,,,,,,,,) = bet.betDetails();

        assertEq(opponent, bob, "Opponent should be Bob's address");
        vm.stopPrank();
    }

    // ============ Edge Cases ============

    function test_CannotDeclareOutcomeBeforeExpiry() public {
        vm.startPrank(alice);
        string[] memory tags = new string[](0);
        address betAddr = betFactory.createBet(
            "bob",
            BET_STAKE,
            "Test bet",
            "Outcome",
            BET_DURATION,
            tags
        );

        Bet bet = Bet(betAddr);
        usdc.approve(betAddr, BET_STAKE);
        bet.fundCreator();
        vm.stopPrank();

        vm.startPrank(bob);
        usdc.approve(betAddr, BET_STAKE);
        bet.acceptBet();
        vm.stopPrank();

        // Try to declare outcome before expiry - should fail
        vm.prank(alice);
        vm.expectRevert(Bet.BetNotExpired.selector);
        bet.declareOutcome(Bet.Outcome.CreatorWins);
    }

    function test_CanCancelBeforeBothFunded() public {
        vm.startPrank(alice);
        string[] memory tags = new string[](0);
        address betAddr = betFactory.createBet(
            "bob",
            BET_STAKE,
            "Test bet",
            "Outcome",
            BET_DURATION,
            tags
        );

        Bet bet = Bet(betAddr);
        usdc.approve(betAddr, BET_STAKE);
        bet.fundCreator();

        uint256 balanceBefore = usdc.balanceOf(alice);

        // Cancel bet
        bet.cancelBet();

        uint256 balanceAfter = usdc.balanceOf(alice);

        // Alice should get her stake back
        assertEq(balanceAfter - balanceBefore, BET_STAKE);

        // Bet should be cancelled
        (,,,,,,,,Bet.BetState state,) = bet.betDetails();
        assertEq(uint(state), uint(Bet.BetState.Cancelled));
        vm.stopPrank();
    }
}
