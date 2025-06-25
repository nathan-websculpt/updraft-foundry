// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./Solution_Base_Test.t.sol";

contract Solution_Critical_Bugs_Test is Solution_Base_Test {
    
    // Division by Zero Vulnerabilities
    function testHandlesTotalSharesWhenNoCyclesExist() public {
        Solution _thisSolution = _setup(); // makes an idea, a solution, and approves UPD spending on solution for owner, alice, and bob
        uint256 totalShares = _thisSolution.totalShares();
        assertEq(totalShares, 0);
    }

    function testHandlesRefundWhenTotalSharesIsZero() public {
        Solution _thisSolution = _setup(); 
        vm.startPrank(alice);
        _upd.approve(address(_thisSolution), TRANSFER_AMT);
        uint256 secondContribution = 20e18;
        _thisSolution.contribute(secondContribution);

        // advance time past the deadline
        uint256 deadline = _thisSolution.deadline();
        skip(deadline + 1);

        // Try to get refund - this might cause division by zero in stakeAward calculation
        // if totalShares() returns 0
        vm.expectEmit(true, true, true, true);
        emit Solution.Refunded(alice, 0, secondContribution, 1e20);
        _thisSolution.refund(0);
        vm.stopPrank();
    }

    // should handle fee collection when cycle.shares is zero
    function testHandlesFeeCollectionWhenCycleSharesIsZero() public {
        Solution _thisSolution = _setup(); 
        vm.startPrank(alice);
        _upd.approve(address(_thisSolution), TRANSFER_AMT);
        uint256 secondContribution = 20e18;
        _thisSolution.contribute(secondContribution);

        // advance time to create cycles
        uint256 cycleLength = _thisSolution.cycleLength();
        skip(cycleLength + 1);

        // Try to collect fees - this might cause division by zero if cycle.shares is 0
        vm.expectEmit(true, true, true, true);
        emit Solution.FeesCollected(alice, 0, 0);
        _thisSolution.collectFees(0);
        vm.stopPrank();
    }


    // PRIVATE HELPERS
    function _setup() private returns (Solution) {
        (, Idea _thisIdea, ) = _createIdea();
        (, Solution _thisSolution, ) = _createSolution(address(_thisIdea));

        _upd.approve(address(_thisSolution), TRANSFER_AMT);

        vm.prank(alice);
        _upd.approve(address(_thisSolution), TRANSFER_AMT);
        vm.prank(bob);
        _upd.approve(address(_thisSolution), TRANSFER_AMT);

        return _thisSolution;
    }
}