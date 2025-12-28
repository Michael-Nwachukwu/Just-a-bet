// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/judges/JudgeRegistry.sol";

/**
 * @title JudgeRegistryTest
 * @notice Comprehensive tests for JudgeRegistry contract
 */
contract JudgeRegistryTest is Test {
    JudgeRegistry public registry;

    // Test accounts
    address public judge1;
    address public judge2;
    address public judge3;
    address public treasury;
    address public owner;

    // Constants
    uint256 constant MIN_STAKE = 1 ether; // 1 MNT
    uint256 constant INITIAL_REPUTATION = 8000; // 80%
    uint256 constant MIN_REPUTATION = 7000; // 70%
    uint256 constant WITHDRAWAL_LOCK = 30 days;
    uint256 constant SLASH_PERCENTAGE = 1000; // 10%

    event JudgeRegistered(address indexed judge, uint256 stakeAmount, uint256 timestamp);
    event JudgeStakeIncreased(address indexed judge, uint256 amount, uint256 newTotal, uint256 timestamp);
    event WithdrawalRequested(address indexed judge, uint256 availableAt, uint256 timestamp);
    event WithdrawalCompleted(address indexed judge, uint256 amount, uint256 timestamp);
    event JudgeSlashed(address indexed judge, uint256 slashedAmount, uint256 remainingStake, uint256 timestamp);
    event ReputationUpdated(address indexed judge, uint256 oldReputation, uint256 newReputation, uint256 timestamp);
    event JudgeDeactivated(address indexed judge, uint256 timestamp);

    function setUp() public {
        // Create test accounts
        owner = address(this);
        judge1 = makeAddr("judge1");
        judge2 = makeAddr("judge2");
        judge3 = makeAddr("judge3");
        treasury = makeAddr("treasury");

        // Deploy registry
        registry = new JudgeRegistry();

        // Set treasury
        registry.setTreasury(treasury);

        // Fund test judges with MNT
        vm.deal(judge1, 100 ether);
        vm.deal(judge2, 100 ether);
        vm.deal(judge3, 100 ether);

        // Label addresses for better trace output
        vm.label(judge1, "Judge1");
        vm.label(judge2, "Judge2");
        vm.label(judge3, "Judge3");
        vm.label(treasury, "Treasury");
    }

    // ============ Registration Tests ============

    function test_RegisterJudge_Success() public {
        uint256 stakeAmount = 5 ether;

        vm.startPrank(judge1);
        vm.expectEmit(true, false, false, true);
        emit JudgeRegistered(judge1, stakeAmount, block.timestamp);

        registry.registerJudge{value: stakeAmount}();
        vm.stopPrank();

        // Verify profile
        JudgeRegistry.JudgeProfile memory profile = registry.getJudgeProfile(judge1);
        assertEq(profile.stakedAmount, stakeAmount);
        assertEq(profile.reputationScore, INITIAL_REPUTATION);
        assertEq(profile.totalCases, 0);
        assertEq(profile.correctDecisions, 0);
        assertTrue(profile.isActive);
        assertEq(profile.withdrawRequestTime, 0);

        // Verify registry state
        assertEq(registry.totalJudges(), 1);
        assertEq(registry.totalStaked(), stakeAmount);
        assertEq(registry.getActiveJudgeCount(), 1);
    }

    function test_RegisterJudge_MinimumStake() public {
        vm.prank(judge1);
        registry.registerJudge{value: MIN_STAKE}();

        JudgeRegistry.JudgeProfile memory profile = registry.getJudgeProfile(judge1);
        assertEq(profile.stakedAmount, MIN_STAKE);
    }

    function test_RegisterJudge_RevertInsufficientStake() public {
        vm.prank(judge1);
        vm.expectRevert(JudgeRegistry.InsufficientStake.selector);
        registry.registerJudge{value: 0.5 ether}(); // Less than 1 MNT
    }

    function test_RegisterJudge_RevertAlreadyRegistered() public {
        vm.startPrank(judge1);
        registry.registerJudge{value: MIN_STAKE}();

        vm.expectRevert(JudgeRegistry.JudgeAlreadyRegistered.selector);
        registry.registerJudge{value: MIN_STAKE}();
        vm.stopPrank();
    }

    function test_RegisterMultipleJudges() public {
        vm.prank(judge1);
        registry.registerJudge{value: 2 ether}();

        vm.prank(judge2);
        registry.registerJudge{value: 3 ether}();

        vm.prank(judge3);
        registry.registerJudge{value: 1 ether}();

        assertEq(registry.totalJudges(), 3);
        assertEq(registry.totalStaked(), 6 ether);
        assertEq(registry.getActiveJudgeCount(), 3);
    }

    // ============ Stake Management Tests ============

    function test_IncreaseStake_Success() public {
        vm.startPrank(judge1);
        registry.registerJudge{value: 2 ether}();

        vm.expectEmit(true, false, false, true);
        emit JudgeStakeIncreased(judge1, 3 ether, 5 ether, block.timestamp);

        registry.increaseStake{value: 3 ether}();
        vm.stopPrank();

        JudgeRegistry.JudgeProfile memory profile = registry.getJudgeProfile(judge1);
        assertEq(profile.stakedAmount, 5 ether);
        assertEq(registry.totalStaked(), 5 ether);
    }

    function test_IncreaseStake_RevertNotActive() public {
        vm.prank(judge1);
        vm.expectRevert(JudgeRegistry.JudgeNotActive.selector);
        registry.increaseStake{value: 1 ether}();
    }

    function test_IncreaseStake_RevertZeroAmount() public {
        vm.startPrank(judge1);
        registry.registerJudge{value: MIN_STAKE}();

        vm.expectRevert(JudgeRegistry.InvalidAmount.selector);
        registry.increaseStake{value: 0}();
        vm.stopPrank();
    }

    // ============ Withdrawal Tests ============

    function test_RequestWithdrawal_Success() public {
        vm.startPrank(judge1);
        registry.registerJudge{value: 5 ether}();

        uint256 expectedAvailableAt = block.timestamp + WITHDRAWAL_LOCK;
        vm.expectEmit(true, false, false, true);
        emit WithdrawalRequested(judge1, expectedAvailableAt, block.timestamp);

        registry.requestWithdrawal();
        vm.stopPrank();

        JudgeRegistry.JudgeProfile memory profile = registry.getJudgeProfile(judge1);
        assertFalse(profile.isActive);
        assertEq(profile.withdrawRequestTime, block.timestamp);
        assertEq(registry.getActiveJudgeCount(), 0);
    }

    function test_CompleteWithdrawal_Success() public {
        vm.startPrank(judge1);
        registry.registerJudge{value: 5 ether}();
        registry.requestWithdrawal();

        // Warp past lock period
        vm.warp(block.timestamp + WITHDRAWAL_LOCK + 1);

        uint256 balanceBefore = judge1.balance;

        vm.expectEmit(true, false, false, true);
        emit WithdrawalCompleted(judge1, 5 ether, block.timestamp);

        registry.completeWithdrawal();
        vm.stopPrank();

        uint256 balanceAfter = judge1.balance;
        assertEq(balanceAfter - balanceBefore, 5 ether);

        JudgeRegistry.JudgeProfile memory profile = registry.getJudgeProfile(judge1);
        assertEq(profile.stakedAmount, 0);
        assertEq(profile.withdrawRequestTime, 0);
        assertEq(registry.totalStaked(), 0);
    }

    function test_CompleteWithdrawal_RevertNotRequested() public {
        vm.prank(judge1);
        registry.registerJudge{value: MIN_STAKE}();

        vm.prank(judge1);
        vm.expectRevert(JudgeRegistry.WithdrawalNotRequested.selector);
        registry.completeWithdrawal();
    }

    function test_CompleteWithdrawal_RevertLockActive() public {
        vm.startPrank(judge1);
        registry.registerJudge{value: MIN_STAKE}();
        registry.requestWithdrawal();

        // Try to withdraw before lock period
        vm.warp(block.timestamp + 15 days); // Only half the lock period

        vm.expectRevert(JudgeRegistry.WithdrawalLockActive.selector);
        registry.completeWithdrawal();
        vm.stopPrank();
    }

    function test_GetWithdrawalAvailability() public {
        vm.startPrank(judge1);
        registry.registerJudge{value: MIN_STAKE}();

        // Before request
        (bool canWithdraw1, uint256 availableAt1) = registry.getWithdrawalAvailability(judge1);
        assertFalse(canWithdraw1);
        assertEq(availableAt1, 0);

        // After request
        registry.requestWithdrawal();
        (bool canWithdraw2, uint256 availableAt2) = registry.getWithdrawalAvailability(judge1);
        assertFalse(canWithdraw2);
        assertEq(availableAt2, block.timestamp + WITHDRAWAL_LOCK);

        // After lock period
        vm.warp(block.timestamp + WITHDRAWAL_LOCK + 1);
        (bool canWithdraw3, ) = registry.getWithdrawalAvailability(judge1);
        assertTrue(canWithdraw3);
        vm.stopPrank();
    }

    // ============ Judge Selection Tests ============

    function test_SelectJudges_Single() public {
        // Register judges
        vm.prank(judge1);
        registry.registerJudge{value: 2 ether}();

        vm.prank(judge2);
        registry.registerJudge{value: 3 ether}();

        vm.prank(judge3);
        registry.registerJudge{value: 1 ether}();

        // Select 1 judge
        address[] memory selected = registry.selectJudges(1, 12345);
        assertEq(selected.length, 1);
        assertTrue(registry.isEligible(selected[0]));
    }

    function test_SelectJudges_Multiple() public {
        // Register 5 judges
        for (uint256 i = 0; i < 5; i++) {
            address judge = makeAddr(string(abi.encodePacked("judge", i)));
            vm.deal(judge, 10 ether);
            vm.prank(judge);
            registry.registerJudge{value: 2 ether}();
        }

        // Select 3 judges
        address[] memory selected = registry.selectJudges(3, 99999);
        assertEq(selected.length, 3);

        // Verify no duplicates
        for (uint256 i = 0; i < selected.length; i++) {
            for (uint256 j = i + 1; j < selected.length; j++) {
                assertTrue(selected[i] != selected[j], "Duplicate judge selected");
            }
        }
    }

    function test_SelectJudges_RevertInsufficientEligible() public {
        vm.prank(judge1);
        registry.registerJudge{value: MIN_STAKE}();

        // Try to select 3 judges when only 1 exists
        vm.expectRevert("Insufficient eligible judges");
        registry.selectJudges(3, 12345);
    }

    function test_IsEligible() public {
        vm.startPrank(judge1);
        registry.registerJudge{value: MIN_STAKE}();

        // Should be eligible
        assertTrue(registry.isEligible(judge1));

        // Request withdrawal - should become ineligible
        registry.requestWithdrawal();
        assertFalse(registry.isEligible(judge1));
        vm.stopPrank();
    }

    function test_IsEligible_LowReputation() public {
        vm.prank(judge1);
        registry.registerJudge{value: MIN_STAKE}();

        // Reduce reputation below minimum
        for (uint256 i = 0; i < 6; i++) {
            registry.updateJudgeStats(judge1, false); // -200 each = -1200 total
        }

        JudgeRegistry.JudgeProfile memory profile = registry.getJudgeProfile(judge1);
        assertLt(profile.reputationScore, MIN_REPUTATION);
        assertFalse(registry.isEligible(judge1));
    }

    // ============ Reputation & Stats Tests ============

    function test_UpdateJudgeStats_Correct() public {
        vm.prank(judge1);
        registry.registerJudge{value: MIN_STAKE}();

        vm.expectEmit(true, false, false, true);
        emit ReputationUpdated(judge1, INITIAL_REPUTATION, INITIAL_REPUTATION + 100, block.timestamp);

        registry.updateJudgeStats(judge1, true);

        JudgeRegistry.JudgeProfile memory profile = registry.getJudgeProfile(judge1);
        assertEq(profile.totalCases, 1);
        assertEq(profile.correctDecisions, 1);
        assertEq(profile.reputationScore, INITIAL_REPUTATION + 100); // +1%
    }

    function test_UpdateJudgeStats_Incorrect() public {
        vm.prank(judge1);
        registry.registerJudge{value: MIN_STAKE}();

        registry.updateJudgeStats(judge1, false);

        JudgeRegistry.JudgeProfile memory profile = registry.getJudgeProfile(judge1);
        assertEq(profile.totalCases, 1);
        assertEq(profile.correctDecisions, 0);
        assertEq(profile.reputationScore, INITIAL_REPUTATION - 200); // -2%
    }

    function test_UpdateJudgeStats_ReputationCap() public {
        vm.prank(judge1);
        registry.registerJudge{value: MIN_STAKE}();

        // Update 30 times to exceed max reputation
        for (uint256 i = 0; i < 30; i++) {
            registry.updateJudgeStats(judge1, true);
        }

        JudgeRegistry.JudgeProfile memory profile = registry.getJudgeProfile(judge1);
        assertEq(profile.reputationScore, 10000); // Capped at 100%
    }

    function test_UpdateJudgeStats_ReputationFloor() public {
        vm.prank(judge1);
        registry.registerJudge{value: MIN_STAKE}();

        // Update many times incorrectly
        for (uint256 i = 0; i < 50; i++) {
            registry.updateJudgeStats(judge1, false);
        }

        JudgeRegistry.JudgeProfile memory profile = registry.getJudgeProfile(judge1);
        assertEq(profile.reputationScore, 0); // Floor at 0%
    }

    function test_GetSuccessRate() public {
        vm.prank(judge1);
        registry.registerJudge{value: MIN_STAKE}();

        // No cases yet
        assertEq(registry.getSuccessRate(judge1), 0);

        // 3 correct, 1 incorrect
        registry.updateJudgeStats(judge1, true);
        registry.updateJudgeStats(judge1, true);
        registry.updateJudgeStats(judge1, true);
        registry.updateJudgeStats(judge1, false);

        // Success rate = 3/4 = 75% = 7500 (basis points)
        assertEq(registry.getSuccessRate(judge1), 7500);
    }

    function test_GetReputationPercentage() public {
        vm.prank(judge1);
        registry.registerJudge{value: MIN_STAKE}();

        // Initial: 8000 / 100 = 80%
        assertEq(registry.getReputationPercentage(judge1), 80);

        // After correct vote: 8100 / 100 = 81%
        registry.updateJudgeStats(judge1, true);
        assertEq(registry.getReputationPercentage(judge1), 81);
    }

    // ============ Slashing Tests ============

    function test_SlashJudge_Success() public {
        vm.prank(judge1);
        registry.registerJudge{value: 10 ether}();

        uint256 treasuryBefore = treasury.balance;
        uint256 expectedSlash = 10 ether * SLASH_PERCENTAGE / 10000; // 1 ether

        vm.expectEmit(true, false, false, true);
        emit JudgeSlashed(judge1, expectedSlash, 9 ether, block.timestamp);

        registry.slashJudge(judge1);

        JudgeRegistry.JudgeProfile memory profile = registry.getJudgeProfile(judge1);
        assertEq(profile.stakedAmount, 9 ether);
        assertEq(registry.totalStaked(), 9 ether);
        assertEq(treasury.balance - treasuryBefore, 1 ether);
    }

    function test_SlashJudge_DeactivatesBelowMinimum() public {
        vm.prank(judge1);
        registry.registerJudge{value: 1.09 ether}(); // Just above minimum

        vm.expectEmit(true, false, false, false);
        emit JudgeDeactivated(judge1, block.timestamp);

        registry.slashJudge(judge1); // Slashing 10% brings below 1 MNT

        JudgeRegistry.JudgeProfile memory profile = registry.getJudgeProfile(judge1);
        assertFalse(profile.isActive);
        assertEq(registry.getActiveJudgeCount(), 0);
    }

    function test_SlashJudge_WithoutTreasury() public {
        // Deploy new registry without treasury
        JudgeRegistry newRegistry = new JudgeRegistry();

        vm.deal(judge1, 10 ether);
        vm.prank(judge1);
        newRegistry.registerJudge{value: 5 ether}();

        uint256 contractBefore = address(newRegistry).balance;

        newRegistry.slashJudge(judge1);

        // Slashed funds stay in contract
        uint256 contractAfter = address(newRegistry).balance;
        assertEq(contractAfter, contractBefore); // No change (funds stay in contract)
    }

    // ============ Configuration Tests ============

    function test_UpdateConfig() public {
        registry.updateConfig(
            2 ether,    // minStakeAmount
            5000,       // minReputationScore (50%)
            60 days,    // withdrawalLockPeriod
            2000,       // slashPercentage (20%)
            9000        // initialReputation (90%)
        );

        (
            uint256 minStake,
            uint256 minRep,
            uint256 lockPeriod,
            uint256 slashPct,
            uint256 initialRep
        ) = registry.config();
        assertEq(minStake, 2 ether);
        assertEq(minRep, 5000);
        assertEq(lockPeriod, 60 days);
        assertEq(slashPct, 2000);
        assertEq(initialRep, 9000);
    }

    function test_UpdateConfig_RevertInvalidReputation() public {
        vm.expectRevert("Invalid reputation");
        registry.updateConfig(1 ether, 15000, 30 days, 1000, 8000); // minReputation > 10000
    }

    function test_UpdateConfig_RevertSlashTooHigh() public {
        vm.expectRevert("Slash too high");
        registry.updateConfig(1 ether, 7000, 30 days, 6000, 8000); // 60% slash
    }

    function test_SetTreasury() public {
        address newTreasury = makeAddr("newTreasury");
        registry.setTreasury(newTreasury);
        assertEq(registry.treasury(), newTreasury);
    }

    function test_SetTreasury_RevertInvalid() public {
        vm.expectRevert("Invalid treasury");
        registry.setTreasury(address(0));
    }

    // ============ View Functions Tests ============

    function test_GetActiveJudges() public {
        vm.prank(judge1);
        registry.registerJudge{value: MIN_STAKE}();

        vm.prank(judge2);
        registry.registerJudge{value: MIN_STAKE}();

        address[] memory active = registry.getActiveJudges();
        assertEq(active.length, 2);
        assertEq(active[0], judge1);
        assertEq(active[1], judge2);
    }

    // ============ Edge Cases ============

    function test_MultipleWithdrawals() public {
        // Judge1 withdraws
        vm.startPrank(judge1);
        registry.registerJudge{value: 3 ether}();
        registry.requestWithdrawal();
        vm.warp(block.timestamp + WITHDRAWAL_LOCK + 1);
        registry.completeWithdrawal();
        vm.stopPrank();

        // Judge2 withdraws
        vm.startPrank(judge2);
        registry.registerJudge{value: 2 ether}();
        registry.requestWithdrawal();
        vm.warp(block.timestamp + WITHDRAWAL_LOCK + 1);
        registry.completeWithdrawal();
        vm.stopPrank();

        assertEq(registry.totalStaked(), 0);
        assertEq(registry.getActiveJudgeCount(), 0);
    }

    function test_StakeIncreaseAfterSlash() public {
        vm.startPrank(judge1);
        registry.registerJudge{value: 5 ether}();
        vm.stopPrank();

        registry.slashJudge(judge1); // Down to 4.5 ether

        vm.startPrank(judge1);
        registry.increaseStake{value: 2 ether}(); // Back up to 6.5 ether
        vm.stopPrank();

        JudgeRegistry.JudgeProfile memory profile = registry.getJudgeProfile(judge1);
        assertEq(profile.stakedAmount, 6.5 ether);
    }

    // ============ Fuzz Tests ============

    function testFuzz_RegisterJudge(uint256 stakeAmount) public {
        vm.assume(stakeAmount >= MIN_STAKE && stakeAmount <= 100 ether);

        vm.deal(judge1, stakeAmount);
        vm.prank(judge1);
        registry.registerJudge{value: stakeAmount}();

        JudgeRegistry.JudgeProfile memory profile = registry.getJudgeProfile(judge1);
        assertEq(profile.stakedAmount, stakeAmount);
    }

    function testFuzz_IncreaseStake(uint256 initial, uint256 increase) public {
        vm.assume(initial >= MIN_STAKE && initial <= 50 ether);
        vm.assume(increase > 0 && increase <= 50 ether);
        vm.assume(initial + increase <= 100 ether);

        vm.deal(judge1, initial + increase);
        vm.startPrank(judge1);
        registry.registerJudge{value: initial}();
        registry.increaseStake{value: increase}();
        vm.stopPrank();

        JudgeRegistry.JudgeProfile memory profile = registry.getJudgeProfile(judge1);
        assertEq(profile.stakedAmount, initial + increase);
    }
}
