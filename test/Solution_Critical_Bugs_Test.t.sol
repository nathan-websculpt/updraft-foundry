// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./bases/Solution_Base.t.sol";

contract Solution_Critical_Bugs_Test is Solution_Base {
    // Division by Zero Vulnerabilities
    function testHandlesTotalSharesWhenNoCyclesExist() public {
        Solution _thisSolution = _setup(); // makes an idea, a solution, and approves UPD spending on solution for owner, alice, and bob
        uint256 totalShares = _thisSolution.totalShares();
        assertEq(totalShares, 0);
    }

    function testHandlesRefundWhenTotalSharesIsZero() public {
        Solution _thisSolution = _setup();
        uint256 secondContribution = 20e18;
        _contribute(_thisSolution, alice, secondContribution);

        // advance time past the deadline
        _skipPastDeadline(_thisSolution);

        // Try to get refund - this might cause division by zero in stakeAward calculation
        // if totalShares() returns 0
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Solution.Refunded(alice, 0, secondContribution, 1e20);
        _thisSolution.refund(0);
    }

    // should handle fee collection when cycle.shares is zero
    function testHandlesFeeCollectionWhenCycleSharesIsZero() public {
        Solution _thisSolution = _setup();
        uint256 secondContribution = 20e18;
        _contribute(_thisSolution, alice, secondContribution);

        // advance time to create cycles
        _skipPastCycleLength(_thisSolution);

        // Try to collect fees - this might cause division by zero if cycle.shares is 0
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Solution.FeesCollected(alice, 0, 0);
        _thisSolution.collectFees(0);
    }
}
