// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./bases/Base.t.sol";

contract Solution_Test is Base {
    function testAllowsUsersToContributeAndCreatePosition() public {
        Solution _thisSolution = _setup(); // makes an idea, a solution, and approves UPD spending on solution for owner, alice, and bob

        // alice contributes
        vm.prank(alice);
        _thisSolution.contribute(CONTRIBUTION_AMT);

        uint256 tokensContributed = _thisSolution.tokensContributed();
        assertEq(tokensContributed, CONTRIBUTION_AMT);
    }

    function testCorrectlyHandlesContributorFees() public {
        Solution _thisSolution = _setup();

        uint256 contributorFee = _thisSolution.contributorFee();
        uint256 percentScale = _thisSolution.percentScale();
        uint256 cycleLength = _thisSolution.cycleLength();

        vm.prank(alice);
        _thisSolution.contribute(CONTRIBUTION_AMT);

        // Get the position directly from the contract's storage
        // This is a more direct way to check the position's contribution
        uint256 positionIndex = 0;
        (uint256 positionContribution,,,,) = _thisSolution.positionsByAddress(alice, positionIndex);

        uint256 expectedFee = CONTRIBUTION_AMT * contributorFee / percentScale;

        // Verify the position contribution based on the cycle
        uint256 currentCycle = _thisSolution.currentCycleNumber();
        if (currentCycle == 0) {
            assertEq(positionContribution, CONTRIBUTION_AMT);
        } else {
            // In later cycles, fees are charged, so position contribution equals amount minus fee
            assertEq(positionContribution, CONTRIBUTION_AMT - expectedFee);
        }

        // Verify the contract's tokensContributed was updated
        uint256 tokensContributed = _thisSolution.tokensContributed();
        assertEq(tokensContributed, CONTRIBUTION_AMT);

        // Verify the cycle was updated
        assertEq(currentCycle, 0);

        // In the first cycle, no contributor fees are charged
        // Let's advance to the next cycle and make another contribution
        skip(cycleLength + 1);

        // make another contribution
        _thisSolution.contribute(CONTRIBUTION_AMT);

        // Now check the cycle fees - in the next cycle, the fees from the third contribution should be added
        // Get the current cycle number after the contribution
        uint256 newCycleNumber = _thisSolution.currentCycleNumber();

        // We need to check the last stored cycle, not necessarily the current cycle number
        // Since we can't directly get the length of the cycles array, we'll use the current cycle number
        // and check if that cycle exists
        uint256 lastCycleIndex = 1;

        // Check the cycle fees in the last stored cycle
        (,, uint256 cycleFees,) = _thisSolution.cycles(lastCycleIndex);

        uint256 thirdContributionFee = CONTRIBUTION_AMT * contributorFee / percentScale;
        assertEq(cycleFees, thirdContributionFee);
    }

    function testAllowsContributorsToCollectFeesAfterMultipleCycles() public {
        Solution _thisSolution = _setup();

        vm.prank(alice);
        _thisSolution.contribute(CONTRIBUTION_AMT);

        (uint256 initialPositionTokens,) = _thisSolution.checkPosition(alice, 0);
        uint256 cycleLength = _thisSolution.cycleLength();
        skip(cycleLength + 1);

        // Third wallet contributes in the second cycle
        vm.prank(bob);
        _thisSolution.contribute(30e18);

        for (uint256 i = 0; i < 3; i++) {
            skip(cycleLength + 1);
        }

        // Get balance before collecting fees
        uint256 balanceBefore = _upd.balanceOf(alice);

        // Get the position's last collected cycle index
        (,,, uint256 lastCollectedCycleIndex,) = _thisSolution.positionsByAddress(alice, 0);

        // Get the current cycle index by checking the current cycle number
        uint256 currentCycleNumber = _thisSolution.currentCycleNumber();

        // Verify that there are uncollected cycles
        assertGt(currentCycleNumber, lastCollectedCycleIndex);

        // Second wallet collects fees
        vm.prank(alice);
        _thisSolution.collectFees(0);

        // Get balance after collecting fees
        uint256 balanceAfter = _upd.balanceOf(alice);

        // Verify balance increased (fees were collected)
        assertGt(balanceAfter, balanceBefore);

        // Check that the position's lastCollectedCycleIndex was updated
        (,,, uint256 updatedLastCollectedCycleIndex,) = _thisSolution.positionsByAddress(alice, 0);
        assertGt(updatedLastCollectedCycleIndex, lastCollectedCycleIndex);

        // Verify that collecting fees again doesn't change the balance
        vm.prank(alice);
        _thisSolution.collectFees(0);
        assertEq(_upd.balanceOf(alice), balanceAfter);
    }

    function testDistributeFeesProportionallyToContributors() public {
        Solution _thisSolution = _setup();

        // alice contributes twice as much as bob
        vm.prank(alice);
        _thisSolution.contribute(CONTRIBUTION_AMT);
        vm.prank(bob);
        _thisSolution.contribute(10e18);

        uint256 cycleLength = _thisSolution.cycleLength();
        skip(cycleLength + 1);

        // owner contributes in the second cycle
        _thisSolution.contribute(30e18);

        for (uint256 i = 0; i < 3; i++) {
            skip(cycleLength + 1);
        }

        // Get balance before collecting fees
        uint256 aliceBalanceBefore = _upd.balanceOf(alice);
        uint256 bobBalanceBefore = _upd.balanceOf(bob);

        // both wallets collect fees
        vm.prank(alice);
        _thisSolution.collectFees(0);
        vm.prank(bob);
        _thisSolution.collectFees(0);

        // Get balance after collecting fees
        uint256 aliceBalanceAfter = _upd.balanceOf(alice);
        uint256 bobBalanceAfter = _upd.balanceOf(bob);

        // Calculate fee increases
        uint256 aliceFeeIncrease = aliceBalanceAfter - aliceBalanceBefore;
        uint256 bobFeeIncrease = bobBalanceAfter - bobBalanceBefore;

        // verify both wallets received fees
        assertGt(aliceFeeIncrease, 0);
        assertGt(bobFeeIncrease, 0);

        // alice should receive approximately twice as much as bob
        // because they contributed twice as much
        uint256 ratio = aliceFeeIncrease / bobFeeIncrease;
        assertEq(ratio, 2);
    }

    function testAllowsOwnerToExtendTheGoal() public {
        Solution _thisSolution = _setup();
        uint256 initialGoal = _thisSolution.fundingGoal();
        _upd.approve(address(_thisSolution), initialGoal);
        _thisSolution.contribute(initialGoal);

        // Verify goal is reached by checking tokensContributed >= fundingGoal
        uint256 tokensContributed = _thisSolution.tokensContributed();
        uint256 fundingGoal = _thisSolution.fundingGoal();
        assertGe(tokensContributed, fundingGoal);

        // Extend the goal
        uint256 newGoal = initialGoal + 2;
        _thisSolution.extendGoal(newGoal);

        uint256 newFundingGoal = _thisSolution.fundingGoal();
        assertEq(newFundingGoal, newGoal);
    }

    function testAllowsOwnerToExtendTheGoalAndDeadline() public {
        Solution _thisSolution = _setup();
        uint256 initialGoal = _thisSolution.fundingGoal();
        uint256 initialDeadline = _thisSolution.deadline();

        _upd.approve(address(_thisSolution), initialGoal);
        _thisSolution.contribute(initialGoal);

        // Verify goal is reached by checking tokensContributed >= fundingGoal
        uint256 tokensContributed = _thisSolution.tokensContributed();
        uint256 fundingGoal = _thisSolution.fundingGoal();
        assertGe(tokensContributed, fundingGoal);

        // Extend the goal and deadline
        uint256 newGoal = initialGoal + 2;
        uint256 newDeadline = initialDeadline + 86400; // Add 1 day
        _thisSolution.extendGoal(newGoal, newDeadline);

        // Verify the goal and deadline were updated
        uint256 newFundingGoal = _thisSolution.fundingGoal();
        uint256 newDeadlineTime = _thisSolution.deadline();
        assertEq(newFundingGoal, newGoal);
        assertEq(newDeadlineTime, newDeadline);
    }

    function testDoesNotAllowExtendingGoalToALowerValue() public {
        Solution _thisSolution = _setup();
        uint256 initialGoal = _thisSolution.fundingGoal();
        uint256 newGoal = initialGoal - 2;
        vm.expectRevert();
        _thisSolution.extendGoal(newGoal);
    }

    function testDoesNotAllowExtendingGoalIfNotOwner() public {
        Solution _thisSolution = _setup();
        uint256 initialGoal = _thisSolution.fundingGoal();
        uint256 newGoal = initialGoal + 2;
        vm.prank(bob);
        vm.expectRevert();
        _thisSolution.extendGoal(newGoal);
    }

    // STAKE MGMT
    function testAllowsAddingStake() public {
        Solution _thisSolution = _setup();

        uint256 initialStake = _thisSolution.stakes(owner);
        uint256 initialTotalStake = _thisSolution.stake();

        uint256 additionalStake = 50e18;
        _thisSolution.addStake(additionalStake);

        // verify stake was updated
        uint256 finalStake = _thisSolution.stakes(owner);
        uint256 finalTotalStake = _thisSolution.stake();
        assertEq(finalStake, initialStake + additionalStake);
        assertEq(finalTotalStake, initialTotalStake + additionalStake);
    }

    function testAllowsTransferringStake() public {
        Solution _thisSolution = _setup();

        uint256 initialStake = _thisSolution.stakes(owner);

        // transfer stake to alice
        _thisSolution.transferStake(alice);

        assertEq(_thisSolution.stakes(owner), 0);
        assertEq(_thisSolution.stakes(alice), initialStake);

        // total stake should remain the same
        assertEq(_thisSolution.stake(), initialStake);
    }

    function testAllowsRemovingStakeAfterGoalIsReached() public {
        Solution _thisSolution = _setup();

        // Contribute enough to reach the goal
        _contributeFundingGoal(_thisSolution);

        // Get initial stake
        uint256 initialStake = _thisSolution.stakes(owner);
        uint256 initialTotalStake = _thisSolution.stake();

        // get initial balance
        uint256 initialBalance = _upd.balanceOf(owner);

        // remove stake
        uint256 stakeToRemove = initialStake / 2;
        _thisSolution.removeStake(stakeToRemove);

        // Verify stake was updated
        uint256 finalStake = _thisSolution.stakes(owner);
        uint256 finalTotalStake = _thisSolution.stake();
        assertEq(finalStake, initialStake - stakeToRemove);
        assertEq(finalTotalStake, initialTotalStake - stakeToRemove);

        // Verify balance increased
        uint256 finalBalance = _upd.balanceOf(owner);
        assertEq(finalBalance, initialBalance + stakeToRemove);
    }

    function testDoesNotAllowRemovingStakeBeforeGoalIsReached() public {
        Solution _thisSolution = _setup();
        uint256 stakeToRemove = 10e18;
        vm.expectRevert();
        _thisSolution.removeStake(stakeToRemove);
    }

    // REFUND
    function testShouldAllowRefundsIfGoalFails() public {
        Solution _thisSolution = _setup();

        vm.prank(alice);
        _thisSolution.contribute(CONTRIBUTION_AMT);

        (uint256 positionTokens,) = _thisSolution.checkPosition(alice, 0);

        // advance time past the deadline
        _skipPastDeadline(_thisSolution);

        // Get balance before refund
        uint256 balanceBefore = _upd.balanceOf(alice);

        // get refund
        vm.prank(alice);
        _thisSolution.refund(0);

        // Get balance after refund
        uint256 balanceAfter = _upd.balanceOf(alice);

        // Verify balance changed
        assertNotEq(balanceAfter, balanceBefore);

        // verify position is marked as refunded
        (,,,, bool position) = _thisSolution.positionsByAddress(alice, 0);
        assert(position);
    }

    function testDoesNotAllowRefundsIfGoalIsReached() public {
        Solution _thisSolution = _setup();

        vm.prank(alice);
        _thisSolution.contribute(CONTRIBUTION_AMT);

        // Contribute enough to reach the goal
        uint256 goal = _thisSolution.fundingGoal();
        uint256 remainingGoal = goal - _thisSolution.tokensContributed();
        _upd.approve(address(_thisSolution), remainingGoal);
        _thisSolution.contribute(remainingGoal);

        // advance time past the deadline
        _skipPastDeadline(_thisSolution);

        vm.prank(alice);
        vm.expectRevert();
        _thisSolution.refund(0);
    }

    function testDoesNotAllowRefundsBeforeDeadline() public {
        Solution _thisSolution = _setup();

        vm.prank(alice);
        _thisSolution.contribute(CONTRIBUTION_AMT);

        vm.prank(alice);
        vm.expectRevert();
        _thisSolution.refund(0);
    }

    function testDoesNotAllowRefundsForPositionsCreatedBeforeGoalExtension() public {
        Solution _thisSolution = _setup();

        uint256 transferAmt = 100_000e18;
        uint256 contribution = 5_000e18;

        _upd.transfer(alice, transferAmt);
        // alice contributes BEFORE goal extension
        vm.startPrank(alice);
        _upd.approve(address(_thisSolution), transferAmt);

        // alice contributes BEFORE goal extension
        _thisSolution.contribute(contribution);
        vm.stopPrank();

        // First, reach the initial goal to enable goal extension
        uint256 initialGoal = _thisSolution.fundingGoal();
        uint256 remainingGoal = initialGoal - _thisSolution.tokensContributed();
        _upd.approve(address(_thisSolution), remainingGoal);
        _upd.transfer(owner, remainingGoal); //
        _thisSolution.contribute(remainingGoal);

        // verify goal is reached
        uint256 tokensContributed = _thisSolution.tokensContributed();
        uint256 fundingGoal = _thisSolution.fundingGoal();
        assertGe(tokensContributed, fundingGoal);

        // Extend the goal (this sets goalChangedTime to current timestamp)
        vm.warp(10);
        uint256 newGoal = initialGoal * 2;
        _thisSolution.extendGoal(newGoal);

        // verify goal was extended
        uint256 newFundingGoal = _thisSolution.fundingGoal();
        assertEq(newFundingGoal, newGoal);

        // Advance time past the deadline to make the goal fail
        _skipPastDeadline(_thisSolution);

        // verify that the goal has failed
        assertEq(_thisSolution.goalFailed(), true);

        bytes4 selector = bytes4(keccak256("ContributedBeforeGoalExtended(uint256,uint256)"));

        // Try to get refund for position created BEFORE goal extension
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(selector, 1, 10));
        _thisSolution.refund(0);
    }

    function testShouldAllowRefundsForPositionsCreatedAfterGoalExtension() public {
        Solution _thisSolution = _setup();

        uint256 initialGoal = _thisSolution.fundingGoal();

        _upd.transfer(alice, initialGoal);
        vm.startPrank(alice);
        _upd.approve(address(_thisSolution), initialGoal);
        _thisSolution.contribute(initialGoal);
        vm.stopPrank();

        // verify goal is reached
        uint256 tokensContributed = _thisSolution.tokensContributed();
        uint256 fundingGoal = _thisSolution.fundingGoal();
        assertGe(tokensContributed, fundingGoal);

        // Extend the goal (this sets goalExtendedTime to current timestamp)
        uint256 newGoal = initialGoal * 2;
        _thisSolution.extendGoal(newGoal);

        // bob contributes AFTER goal extension
        vm.startPrank(bob);
        _upd.approve(address(_thisSolution), CONTRIBUTION_AMT);
        _thisSolution.contribute(CONTRIBUTION_AMT);
        vm.stopPrank();

        // Advance time past the deadline to make the goal fail
        _skipPastDeadline(_thisSolution);

        // verify that the goal has failed
        assertEq(_thisSolution.goalFailed(), true);

        // Get balance before refund
        uint256 balanceBefore = _upd.balanceOf(bob);

        // bob should be able to get refund for position created AFTER goal extension
        vm.prank(bob);
        _thisSolution.refund(0);

        // get balance after refund
        uint256 balanceAfter = _upd.balanceOf(bob);

        // verify refund
        assertGt(balanceAfter, balanceBefore);
    }

    function testShouldAllowOwnerToWithdrawFundsAfterGoalIsReached() public {
        Solution _thisSolution = _setup();

        // contribute enough to reach the goal
        _upd.approve(address(_thisSolution), _thisSolution.fundingGoal());
        _thisSolution.contribute(_thisSolution.fundingGoal());

        uint256 initialBalance = _upd.balanceOf(owner);
        uint256 withdrawAmt = 1000e18;

        // make sure a non-owner cannot withdraw
        vm.prank(alice);
        vm.expectRevert();
        _thisSolution.withdrawFunds(alice, withdrawAmt);

        _thisSolution.withdrawFunds(owner, withdrawAmt);
        uint256 finalBalance = _upd.balanceOf(owner);
        assertEq(finalBalance, initialBalance + withdrawAmt);
    }

    function testShouldNotAllowWithdrawingMoreThanAvailable() public {
        Solution _thisSolution = _setup();
        uint256 contribution = _contributeFundingGoal(_thisSolution);

        vm.expectRevert();
        _thisSolution.withdrawFunds(owner, contribution + 1);
    }

    function testShouldNotAllowNonOwnersToWithdrawFunds() public {
        Solution _thisSolution = _setup();
        uint256 contribution = _contributeFundingGoal(_thisSolution);

        vm.prank(alice);
        vm.expectRevert();
        _thisSolution.withdrawFunds(alice, contribution);
    }

    // POSITION MGMT

    function testShouldAllowTransferringPosition() public {
        Solution _thisSolution = _setup();
        _thisSolution.contribute(CONTRIBUTION_AMT);

        (uint256 positionTokens,) = _thisSolution.checkPosition(owner, 0);

        _thisSolution.transferPosition(bob, 0);

        // verify position amount is the same
        (uint256 transferredPositionTokens,) = _thisSolution.checkPosition(bob, 0);
        assertEq(positionTokens, transferredPositionTokens);
    }

    function testShouldAllowSplittingPositions() public {
        Solution _thisSolution = _setup();
        _thisSolution.contribute(CONTRIBUTION_AMT);

        (uint256 positionTokens,) = _thisSolution.checkPosition(owner, 0);

        // split position into two parts
        _thisSolution.split(0, 2);

        assertEq(_thisSolution.numPositions(owner), 2);

        // verifiy original position has half the tokens
        (uint256 originalPositionTokens,) = _thisSolution.checkPosition(owner, 0);
        (uint256 newPositionTokens,) = _thisSolution.checkPosition(owner, 1);
        assertEq(originalPositionTokens, positionTokens / 2);
        assertEq(newPositionTokens, positionTokens / 2);
    }

    // PRIVATE HELPERS
    function _setup() private returns (Solution) {
        (Idea _thisIdea, ,) = _createIdea();
        (Solution _thisSolution, ,) = _createSolution(address(_thisIdea));

        _upd.approve(address(_thisSolution), TRANSFER_AMT);

        vm.prank(alice);
        _upd.approve(address(_thisSolution), TRANSFER_AMT);
        vm.prank(bob);
        _upd.approve(address(_thisSolution), TRANSFER_AMT);

        return _thisSolution;
    }

    function _contributeFundingGoal(Solution _thisSolution) private returns (uint256) {
        uint256 goal = _thisSolution.fundingGoal();
        _upd.approve(address(_thisSolution), goal);
        _thisSolution.contribute(goal);
        return goal;
    }
}
