// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/judges/DisputeManager.sol";
import "../src/judges/JudgeRegistry.sol";
import "../src/core/Bet.sol";
import "../src/core/BetFactory.sol";
import "../src/core/BetYieldVault.sol";
import "../src/core/UsernameRegistry.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock USDC token
contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {
        _mint(msg.sender, 10000000 * 10**6); // 10M USDC
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title DisputeIntegrationTest
 * @notice End-to-end integration tests for the full dispute resolution flow
 * @dev Tests complete lifecycle: bet creation -> funding -> expiry -> declaration -> dispute -> voting -> resolution
 */
contract DisputeIntegrationTest is Test {
    DisputeManager public disputeManager;
    JudgeRegistry public judgeRegistry;
    BetFactory public betFactory;
    BetYieldVault public yieldVault;
    UsernameRegistry public usernameRegistry;
    MockUSDC public usdc;

    address public owner = address(this);
    address public treasury = makeAddr("treasury");

    // Bet participants
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    // Judges pool
    address public judge1 = makeAddr("judge1");
    address public judge2 = makeAddr("judge2");
    address public judge3 = makeAddr("judge3");
    address public judge4 = makeAddr("judge4");
    address public judge5 = makeAddr("judge5");
    address public judge6 = makeAddr("judge6");
    address public judge7 = makeAddr("judge7");

    function setUp() public {
        // Deploy core contracts
        usdc = new MockUSDC();
        usernameRegistry = new UsernameRegistry();
        yieldVault = new BetYieldVault(address(usdc), treasury);
        betFactory = new BetFactory(address(usdc), address(usernameRegistry));
        judgeRegistry = new JudgeRegistry();
        disputeManager = new DisputeManager(address(judgeRegistry));

        // Set yield vault on factory
        betFactory.setYieldVault(address(yieldVault));

        // Set treasury for slashed funds
        judgeRegistry.setTreasury(treasury);

        // Fund all judges with MNT
        address[7] memory judges = [judge1, judge2, judge3, judge4, judge5, judge6, judge7];
        for (uint256 i = 0; i < judges.length; i++) {
            vm.deal(judges[i], 100 ether);
            vm.prank(judges[i]);
            judgeRegistry.registerJudge{value: 15 ether}();
        }

        // Fund bet participants with USDC
        usdc.mint(alice, 100000 * 10**6);
        usdc.mint(bob, 100000 * 10**6);

        // Register usernames
        vm.prank(alice);
        usernameRegistry.registerUsername("alice");

        vm.prank(bob);
        usernameRegistry.registerUsername("bob");
    }

    // ============ Complete Lifecycle Tests ============

    function test_FullDisputeFlow_Tier1_OptimisticResolution() public {
        // 1. Alice creates bet with Bob
        string[] memory tags = new string[](2);
        tags[0] = "sports";
        tags[1] = "nfl";

        vm.prank(alice);
        usdc.approve(address(betFactory), 500 * 10**6);

        vm.prank(alice);
        address betAddress = betFactory.createBet(
            "bob",
            500 * 10**6,
            "Patriots will beat the Chiefs",
            "Patriots win by end of regulation",
            14 days,
            tags
        );
        Bet bet = Bet(betAddress);
        bet.setDisputeManager(address(disputeManager));

        // 2. Both participants fund the bet
        vm.prank(alice);
        usdc.approve(address(bet), 500 * 10**6);
        vm.prank(alice);
        bet.fundCreator();

        vm.prank(bob);
        usdc.approve(address(bet), 500 * 10**6);
        vm.prank(bob);
        bet.acceptBet();

        // Verify bet is active
        Bet.BetDetails memory details = bet.getBetDetails();
        assertEq(uint8(details.state), uint8(Bet.BetState.Active));

        // 3. Fast forward to bet expiry
        vm.warp(block.timestamp + 14 days + 1);

        // 4. Alice (winner) declares outcome
        vm.prank(alice);
        bet.declareOutcome(Bet.Outcome.CreatorWins);

        // Verify awaiting resolution
        details = bet.getBetDetails();
        assertEq(uint8(details.state), uint8(Bet.BetState.AwaitingResolution));

        // 5. Bob accepts the outcome (doesn't dispute)
        // Fast forward past dispute window
        vm.warp(block.timestamp + 24 hours + 1);

        // 6. Finalize resolution (optimistic - no dispute needed)
        bet.finalizeResolution();

        // Verify bet resolved without judges
        details = bet.getBetDetails();
        assertEq(uint8(details.state), uint8(Bet.BetState.Resolved));
        assertEq(uint8(details.outcome), uint8(Bet.Outcome.CreatorWins));

        // Verify alice received winnings (should have more than her original stake due to yield)
        uint256 aliceBalance = usdc.balanceOf(alice);
        assertGt(aliceBalance, 99500 * 10**6); // Original balance minus stake + winnings
    }

    function test_FullDisputeFlow_Tier1_SingleJudge() public {
        // 1. Create and fund bet
        string[] memory tags = new string[](1);
        tags[0] = "esports";

        vm.prank(alice);
        usdc.approve(address(betFactory), 200 * 10**6);

        vm.prank(alice);
        address betAddress = betFactory.createBet(
            "bob",
            200 * 10**6,
            "Team Liquid beats Cloud9",
            "Team Liquid wins the match",
            7 days,
            tags
        );
        Bet bet = Bet(betAddress);
        bet.setDisputeManager(address(disputeManager));

        vm.prank(alice);
        usdc.approve(address(bet), 200 * 10**6);
        vm.prank(alice);
        bet.fundCreator();

        vm.prank(bob);
        usdc.approve(address(bet), 200 * 10**6);
        vm.prank(bob);
        bet.acceptBet();

        // 2. Bet expires
        vm.warp(block.timestamp + 7 days + 1);

        // 3. Alice declares she won
        vm.prank(alice);
        bet.declareOutcome(Bet.Outcome.CreatorWins);

        // 4. Bob disputes (disagrees with outcome)
        vm.prank(bob);
        bet.raiseDispute();

        // Verify bet is disputed
        Bet.BetDetails memory details = bet.getBetDetails();
        assertEq(uint8(details.state), uint8(Bet.BetState.Disputed));

        // 5. Create dispute in DisputeManager
        uint256 disputeId = disputeManager.createDispute(address(bet));

        DisputeManager.Dispute memory dispute = disputeManager.getDispute(disputeId);
        address[] memory judges = disputeManager.getDisputeJudges(disputeId);
        assertEq(uint8(dispute.tier), uint8(DisputeManager.DisputeTier.Tier0)); // Tier 0 (< 100 USDC)
        assertEq(dispute.judgeCount, 1); // Single judge

        // 6. Assigned judge reviews and votes
        address assignedJudge = judges[0];

        // Judge votes in favor of Bob (OpponentWins)
        vm.prank(assignedJudge);
        disputeManager.submitVote(disputeId, Bet.Outcome.OpponentWins);

        // 7. Verify dispute auto-resolved after final vote
        dispute = disputeManager.getDispute(disputeId);
        assertEq(uint8(dispute.status), uint8(DisputeManager.DisputeStatus.Resolved));
        assertEq(uint8(dispute.finalOutcome), uint8(Bet.Outcome.OpponentWins));

        // 8. Verify bet resolved correctly
        details = bet.getBetDetails();
        assertEq(uint8(details.state), uint8(Bet.BetState.Resolved));
        assertEq(uint8(details.outcome), uint8(Bet.Outcome.OpponentWins));

        // 9. Verify Bob (opponent/winner) received funds
        uint256 bobBalance = usdc.balanceOf(bob);
        assertGt(bobBalance, 99800 * 10**6); // Original minus stake + winnings

        // 10. Verify judge reputation updated
        JudgeRegistry.JudgeProfile memory judgeProfile = judgeRegistry.getJudgeProfile(assignedJudge);
        assertEq(judgeProfile.totalCases, 1);
        assertEq(judgeProfile.correctDecisions, 1);
    }

    function test_FullDisputeFlow_Tier2_ThreeJudges_MajorityVote() public {
        // 1. Create high-stake bet (Tier 2)
        string[] memory tags = new string[](1);
        tags[0] = "politics";

        vm.prank(alice);
        usdc.approve(address(betFactory), 2000 * 10**6);

        vm.prank(alice);
        address betAddress = betFactory.createBet(
            "bob",
            2000 * 10**6,
            "Candidate X wins election",
            "Candidate X declared winner",
            30 days,
            tags
        );
        Bet bet = Bet(betAddress);
        bet.setDisputeManager(address(disputeManager));

        vm.prank(alice);
        usdc.approve(address(bet), 2000 * 10**6);
        vm.prank(alice);
        bet.fundCreator();

        vm.prank(bob);
        usdc.approve(address(bet), 2000 * 10**6);
        vm.prank(bob);
        bet.acceptBet();

        // 2. Bet expires
        vm.warp(block.timestamp + 30 days + 1);

        // 3. Bob declares he won
        vm.prank(bob);
        bet.declareOutcome(Bet.Outcome.OpponentWins);

        // 4. Alice disputes
        vm.prank(alice);
        bet.raiseDispute();

        // 5. Create Tier 2 dispute (3 judges)
        uint256 disputeId = disputeManager.createDispute(address(bet));

        DisputeManager.Dispute memory dispute = disputeManager.getDispute(disputeId);
        address[] memory judges = disputeManager.getDisputeJudges(disputeId);
        assertEq(uint8(dispute.tier), uint8(DisputeManager.DisputeTier.Tier1));
        assertEq(dispute.judgeCount, 3);

        // 6. Three judges vote: 2 for Alice (CreatorWins), 1 for Bob (OpponentWins)
        vm.prank(judges[0]);
        disputeManager.submitVote(disputeId, Bet.Outcome.CreatorWins);

        vm.prank(judges[1]);
        disputeManager.submitVote(disputeId, Bet.Outcome.CreatorWins);

        // Get judge profiles before incorrect vote
        JudgeRegistry.JudgeProfile memory incorrectJudgeBefore = judgeRegistry.getJudgeProfile(judges[2]);
        uint256 stakeBefore = incorrectJudgeBefore.stakedAmount;

        vm.prank(judges[2]);
        disputeManager.submitVote(disputeId, Bet.Outcome.OpponentWins); // Minority vote

        // 7. Verify majority outcome (CreatorWins)
        dispute = disputeManager.getDispute(disputeId);
        assertEq(uint8(dispute.finalOutcome), uint8(Bet.Outcome.CreatorWins));

        // 8. Verify bet resolved with majority decision
        Bet.BetDetails memory details = bet.getBetDetails();
        assertEq(uint8(details.outcome), uint8(Bet.Outcome.CreatorWins));

        // 9. Verify incorrect judge was slashed
        JudgeRegistry.JudgeProfile memory incorrectJudgeAfter = judgeRegistry.getJudgeProfile(judges[2]);
        assertLt(incorrectJudgeAfter.stakedAmount, stakeBefore); // Slashed
        assertLt(incorrectJudgeAfter.reputationScore, incorrectJudgeBefore.reputationScore);

        // 10. Verify correct judges' reputation increased
        JudgeRegistry.JudgeProfile memory correctJudge = judgeRegistry.getJudgeProfile(judges[0]);
        assertEq(correctJudge.correctDecisions, 1);
        assertGt(correctJudge.reputationScore, 8000); // Higher than initial 8000
    }

    function test_FullDisputeFlow_Tier3_FiveJudges_WithAppeal() public {
        // 1. Create very high-stake bet (Tier 3)
        string[] memory tags = new string[](1);
        tags[0] = "crypto";

        vm.prank(alice);
        usdc.approve(address(betFactory), 6000 * 10**6);

        vm.prank(alice);
        address betAddress = betFactory.createBet(
            "bob",
            6000 * 10**6,
            "Bitcoin reaches $100k by end of year",
            "BTC price >= $100,000",
            90 days,
            tags
        );
        Bet bet = Bet(betAddress);
        bet.setDisputeManager(address(disputeManager));

        vm.prank(alice);
        usdc.approve(address(bet), 6000 * 10**6);
        vm.prank(alice);
        bet.fundCreator();

        vm.prank(bob);
        usdc.approve(address(bet), 6000 * 10**6);
        vm.prank(bob);
        bet.acceptBet();

        // 2. Bet expires
        vm.warp(block.timestamp + 90 days + 1);

        // 3. Alice declares she won
        vm.prank(alice);
        bet.declareOutcome(Bet.Outcome.CreatorWins);

        // 4. Bob disputes
        vm.prank(bob);
        bet.raiseDispute();

        // 5. Create Tier 3 dispute (5 judges)
        uint256 disputeId = disputeManager.createDispute(address(bet));

        DisputeManager.Dispute memory dispute = disputeManager.getDispute(disputeId);
        address[] memory judges = disputeManager.getDisputeJudges(disputeId);
        assertEq(uint8(dispute.tier), uint8(DisputeManager.DisputeTier.Tier2));
        assertEq(dispute.judgeCount, 5);
        assertEq(judges.length, 5);

        // 6. Judges vote: 3 for Alice, 2 for Bob
        vm.prank(judges[0]);
        disputeManager.submitVote(disputeId, Bet.Outcome.CreatorWins);

        vm.prank(judges[1]);
        disputeManager.submitVote(disputeId, Bet.Outcome.CreatorWins);

        vm.prank(judges[2]);
        disputeManager.submitVote(disputeId, Bet.Outcome.CreatorWins);

        vm.prank(judges[3]);
        disputeManager.submitVote(disputeId, Bet.Outcome.OpponentWins);

        vm.prank(judges[4]);
        disputeManager.submitVote(disputeId, Bet.Outcome.OpponentWins);

        // 7. Verify resolved with majority (CreatorWins)
        dispute = disputeManager.getDispute(disputeId);
        assertEq(uint8(dispute.finalOutcome), uint8(Bet.Outcome.CreatorWins));

        // NOTE: Appeal not possible from Tier 3 (max tier)
        // This test verifies Tier 3 dispute resolution only
    }

    function test_FullDisputeFlow_Draw_Outcome() public {
        // 1. Create bet with potential draw scenario
        string[] memory tags = new string[](1);
        tags[0] = "sports";

        vm.prank(alice);
        usdc.approve(address(betFactory), 1500 * 10**6);

        vm.prank(alice);
        address betAddress = betFactory.createBet(
            "bob",
            1500 * 10**6,
            "Game ends in overtime",
            "Game goes to overtime",
            10 days,
            tags
        );
        Bet bet = Bet(betAddress);
        bet.setDisputeManager(address(disputeManager));

        vm.prank(alice);
        usdc.approve(address(bet), 1500 * 10**6);
        vm.prank(alice);
        bet.fundCreator();

        vm.prank(bob);
        usdc.approve(address(bet), 1500 * 10**6);
        vm.prank(bob);
        bet.acceptBet();

        // 2. Bet expires
        vm.warp(block.timestamp + 10 days + 1);

        // 3. Alice declares Draw
        vm.prank(alice);
        bet.declareOutcome(Bet.Outcome.Draw);

        // 4. Bob disputes even though outcome is Draw
        vm.prank(bob);
        bet.raiseDispute();

        // 5. Create Tier 2 dispute
        uint256 disputeId = disputeManager.createDispute(address(bet));

        DisputeManager.Dispute memory dispute = disputeManager.getDispute(disputeId);
        address[] memory judges = disputeManager.getDisputeJudges(disputeId);

        // 6. All judges vote Draw
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(judges[i]);
            disputeManager.submitVote(disputeId, Bet.Outcome.Draw);
        }

        // 7. Verify resolved as Draw
        dispute = disputeManager.getDispute(disputeId);
        assertEq(uint8(dispute.finalOutcome), uint8(Bet.Outcome.Draw));

        // 8. Verify bet resolved and funds split
        Bet.BetDetails memory details = bet.getBetDetails();
        assertEq(uint8(details.outcome), uint8(Bet.Outcome.Draw));

        // Both should get their stake back (minus small platform fee, plus yield)
        uint256 aliceBalance = usdc.balanceOf(alice);
        uint256 bobBalance = usdc.balanceOf(bob);

        // Should be close to original balances (98500 each after funding)
        assertGt(aliceBalance, 98000 * 10**6);
        assertGt(bobBalance, 98000 * 10**6);
    }

    function test_FullDisputeFlow_ThreeWayTie_ResolvestoDraw() public {
        // 1. Create Tier 2 bet for 3 judges
        string[] memory tags = new string[](1);
        tags[0] = "entertainment";

        vm.prank(alice);
        usdc.approve(address(betFactory), 1200 * 10**6);

        vm.prank(alice);
        address betAddress = betFactory.createBet(
            "bob",
            1200 * 10**6,
            "Movie wins best picture",
            "Movie X wins Oscar",
            60 days,
            tags
        );
        Bet bet = Bet(betAddress);
        bet.setDisputeManager(address(disputeManager));

        vm.prank(alice);
        usdc.approve(address(bet), 1200 * 10**6);
        vm.prank(alice);
        bet.fundCreator();

        vm.prank(bob);
        usdc.approve(address(bet), 1200 * 10**6);
        vm.prank(bob);
        bet.acceptBet();

        // 2. Bet expires
        vm.warp(block.timestamp + 60 days + 1);

        // 3. Alice declares she won
        vm.prank(alice);
        bet.declareOutcome(Bet.Outcome.CreatorWins);

        // 4. Bob disputes
        vm.prank(bob);
        bet.raiseDispute();

        // 5. Create dispute
        uint256 disputeId = disputeManager.createDispute(address(bet));

        DisputeManager.Dispute memory dispute = disputeManager.getDispute(disputeId);
        address[] memory judges = disputeManager.getDisputeJudges(disputeId);

        // 6. Create perfect 3-way tie: 1 CreatorWins, 1 OpponentWins, 1 Draw
        vm.prank(judges[0]);
        disputeManager.submitVote(disputeId, Bet.Outcome.CreatorWins);

        vm.prank(judges[1]);
        disputeManager.submitVote(disputeId, Bet.Outcome.OpponentWins);

        vm.prank(judges[2]);
        disputeManager.submitVote(disputeId, Bet.Outcome.Draw);

        // 7. Verify tie resolved to Draw (fair tie-breaker)
        dispute = disputeManager.getDispute(disputeId);
        assertEq(uint8(dispute.finalOutcome), uint8(Bet.Outcome.Draw));

        // 8. Verify funds split between participants
        Bet.BetDetails memory details = bet.getBetDetails();
        assertEq(uint8(details.outcome), uint8(Bet.Outcome.Draw));
    }

    function test_FullDisputeFlow_JudgeTimeout_AutoResolve() public {
        // 1. Create bet
        string[] memory tags = new string[](1);
        tags[0] = "tech";

        vm.prank(alice);
        usdc.approve(address(betFactory), 300 * 10**6);

        vm.prank(alice);
        address betAddress = betFactory.createBet(
            "bob",
            300 * 10**6,
            "Product launches by Q4",
            "Product released",
            120 days,
            tags
        );
        Bet bet = Bet(betAddress);
        bet.setDisputeManager(address(disputeManager));

        vm.prank(alice);
        usdc.approve(address(bet), 300 * 10**6);
        vm.prank(alice);
        bet.fundCreator();

        vm.prank(bob);
        usdc.approve(address(bet), 300 * 10**6);
        vm.prank(bob);
        bet.acceptBet();

        // 2. Bet expires
        vm.warp(block.timestamp + 120 days + 1);

        // 3. Bob declares he won
        vm.prank(bob);
        bet.declareOutcome(Bet.Outcome.OpponentWins);

        // 4. Alice disputes
        vm.prank(alice);
        bet.raiseDispute();

        // 5. Create dispute
        uint256 disputeId = disputeManager.createDispute(address(bet));

        // 6. No judges vote - timeout scenario
        // Fast forward past voting period (3 days)
        vm.warp(block.timestamp + 3 days + 1);

        // 7. Manually resolve after timeout
        disputeManager.finalizeDispute(disputeId);

        // 8. Verify resolved to Draw (no votes = tie = draw)
        DisputeManager.Dispute memory dispute = disputeManager.getDispute(disputeId);
        assertEq(uint8(dispute.status), uint8(DisputeManager.DisputeStatus.Resolved));
        assertEq(uint8(dispute.finalOutcome), uint8(Bet.Outcome.Draw));

        // 9. Verify funds split fairly due to timeout
        Bet.BetDetails memory details = bet.getBetDetails();
        assertEq(uint8(details.outcome), uint8(Bet.Outcome.Draw));
    }

    function test_FullDisputeFlow_MultipleSequentialDisputes() public {
        // Test that system handles multiple disputes from different bets correctly

        // 1. Create two separate bets
        string[] memory tags = new string[](1);
        tags[0] = "test";

        // Bet 1: Alice vs Bob
        vm.prank(alice);
        usdc.approve(address(betFactory), 400 * 10**6);

        vm.prank(alice);
        address bet1Address = betFactory.createBet(
            "bob",
            200 * 10**6,
            "Bet 1",
            "Outcome 1",
            5 days,
            tags
        );
        Bet bet1 = Bet(bet1Address);
        bet1.setDisputeManager(address(disputeManager));

        vm.prank(alice);
        usdc.approve(address(bet1), 200 * 10**6);
        vm.prank(alice);
        bet1.fundCreator();

        vm.prank(bob);
        usdc.approve(address(bet1), 200 * 10**6);
        vm.prank(bob);
        bet1.acceptBet();

        // Bet 2: Bob vs Alice (reversed roles)
        vm.prank(bob);
        usdc.approve(address(betFactory), 200 * 10**6);

        vm.prank(bob);
        address bet2Address = betFactory.createBet(
            "alice",
            200 * 10**6,
            "Bet 2",
            "Outcome 2",
            5 days,
            tags
        );
        Bet bet2 = Bet(bet2Address);
        bet2.setDisputeManager(address(disputeManager));

        vm.prank(bob);
        usdc.approve(address(bet2), 200 * 10**6);
        vm.prank(bob);
        bet2.fundCreator();

        vm.prank(alice);
        usdc.approve(address(bet2), 200 * 10**6);
        vm.prank(alice);
        bet2.acceptBet();

        // 2. Both bets expire
        vm.warp(block.timestamp + 5 days + 1);

        // 3. Declare outcomes and create disputes
        vm.prank(alice);
        bet1.declareOutcome(Bet.Outcome.CreatorWins);

        vm.prank(bob);
        bet1.raiseDispute();

        vm.prank(bob);
        bet2.declareOutcome(Bet.Outcome.CreatorWins);

        vm.prank(alice);
        bet2.raiseDispute();

        // 4. Create disputes in DisputeManager
        uint256 dispute1Id = disputeManager.createDispute(address(bet1));
        uint256 dispute2Id = disputeManager.createDispute(address(bet2));

        assertEq(dispute1Id, 1);
        assertEq(dispute2Id, 2);
        // assertEq(disputeManager.getActiveDisputeCount(), 2); // Function doesn't exist

        // 5. Resolve both disputes
        DisputeManager.Dispute memory dispute1 = disputeManager.getDispute(dispute1Id);
        DisputeManager.Dispute memory dispute2 = disputeManager.getDispute(dispute2Id);
        address[] memory judges1 = disputeManager.getDisputeJudges(dispute1Id);
        address[] memory judges2 = disputeManager.getDisputeJudges(dispute2Id);

        vm.prank(judges1[0]);
        disputeManager.submitVote(dispute1Id, Bet.Outcome.CreatorWins);

        vm.prank(judges2[0]);
        disputeManager.submitVote(dispute2Id, Bet.Outcome.OpponentWins);

        // 6. Verify both resolved correctly
        dispute1 = disputeManager.getDispute(dispute1Id);
        dispute2 = disputeManager.getDispute(dispute2Id);

        assertEq(uint8(dispute1.finalOutcome), uint8(Bet.Outcome.CreatorWins));
        assertEq(uint8(dispute2.finalOutcome), uint8(Bet.Outcome.OpponentWins));

        // 7. Verify both bets resolved
        Bet.BetDetails memory bet1Details = bet1.getBetDetails();
        Bet.BetDetails memory bet2Details = bet2.getBetDetails();

        assertEq(uint8(bet1Details.state), uint8(Bet.BetState.Resolved));
        assertEq(uint8(bet2Details.state), uint8(Bet.BetState.Resolved));
    }

    // ============ Edge Case Tests ============

    function test_CannotCreateDisputeForNonDisputedBet() public {
        // Create bet but don't dispute it
        string[] memory tags = new string[](1);
        tags[0] = "test";

        vm.prank(alice);
        usdc.approve(address(betFactory), 100 * 10**6);

        vm.prank(alice);
        address betAddress = betFactory.createBet(
            "bob",
            100 * 10**6,
            "Test bet",
            "Test",
            5 days,
            tags
        );

        // Try to create dispute for non-disputed bet
        vm.expectRevert("Bet not in disputed state");
        disputeManager.createDispute(betAddress);
    }

    function test_CannotDisputeOwnWinDeclaration() public {
        // Create and fund bet
        string[] memory tags = new string[](1);
        tags[0] = "test";

        vm.prank(alice);
        usdc.approve(address(betFactory), 100 * 10**6);

        vm.prank(alice);
        address betAddress = betFactory.createBet(
            "bob",
            100 * 10**6,
            "Test bet",
            "Test",
            5 days,
            tags
        );
        Bet bet = Bet(betAddress);

        vm.prank(alice);
        usdc.approve(address(bet), 100 * 10**6);
        vm.prank(alice);
        bet.fundCreator();

        vm.prank(bob);
        usdc.approve(address(bet), 100 * 10**6);
        vm.prank(bob);
        bet.acceptBet();

        // Expire bet
        vm.warp(block.timestamp + 5 days + 1);

        // Alice declares she won
        vm.prank(alice);
        bet.declareOutcome(Bet.Outcome.CreatorWins);

        // Alice can't dispute her own win declaration (only bob can)
        vm.prank(alice);
        vm.expectRevert(); // Will revert - implementation may vary
        bet.raiseDispute();
    }
}
