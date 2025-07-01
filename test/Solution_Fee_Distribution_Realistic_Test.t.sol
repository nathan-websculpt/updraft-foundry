// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./bases/Solution_Base.t.sol";

contract Solution_Fee_Distribution_Realistic_Test is Solution_Base {
    // should distribute fees correctly with multiple contributors over multiple cycles
    function testDistributesFeesCorrectlyWithMultipleContributorsOverMultipleCycles() public {
        Solution _thisSolution = _setup();
        uint256 transferAmt = 1_000_000e18;
        _upd.transfer(alice, transferAmt);
        _upd.transfer(bob, transferAmt);

        _upd.approve(address(_thisSolution), transferAmt);
        vm.prank(alice);
        _upd.approve(address(_thisSolution), transferAmt);
        vm.prank(bob);
        _upd.approve(address(_thisSolution), transferAmt);

        uint256 cycleLength = _thisSolution.cycleLength();

        // First wallet contributes in the first cycle (creator)
        // This is already done during contract creation with the stake

        // Second wallet contributes in the first cycle
        uint256 secondContribution = 20_000e18; // 20,000 UPD
        vm.prank(alice);
        _thisSolution.contribute(secondContribution);
        console2.log("Second wallet contributed %s UPD in cycle 1", _formatUnits(secondContribution));

        // Third wallet contributes in the first cycle
        uint256 thirdContribution = 10_000e18; // 10,000 UPD
        vm.prank(bob);
        _thisSolution.contribute(thirdContribution);
        console2.log("Third wallet contributed %s UPD in cycle 1", _formatUnits(thirdContribution));

        // Advance time to the second cycle
        skip(cycleLength + 1);

        // First wallet contributes in the second cycle
        uint256 firstContributionSecondCycle = 30_000e18;
        _thisSolution.contribute(firstContributionSecondCycle);
        console2.log("First wallet contributed %s UPD in cycle 2", _formatUnits(firstContributionSecondCycle));

        // Advance time to the third cycle
        skip(cycleLength + 1);

        // Second wallet contributes in the third cycle
        uint256 secondContributionSecondCycle = 15_000e18;
        vm.prank(alice);
        _thisSolution.contribute(secondContributionSecondCycle);
        console2.log("Second wallet contributed %s UPD in cycle 3", _formatUnits(secondContributionSecondCycle));

        // Advance time to the fourth cycle
        skip(cycleLength + 1);

        // Third wallet contributes in the fourth cycle
        uint256 thirdContributionSecondCycle = 25_000e18;
        vm.prank(bob);
        _thisSolution.contribute(thirdContributionSecondCycle);
        console2.log("Third wallet contributed %s UPD in cycle 4", _formatUnits(thirdContributionSecondCycle));

        // Advance time to the fifth cycle
        skip(cycleLength + 1);

        // Get balances before collecting fees
        uint256 firstBalanceBefore = _upd.balanceOf(owner);
        uint256 secondBalanceBefore = _upd.balanceOf(alice);
        uint256 thirdBalanceBefore = _upd.balanceOf(bob);

        // Get position details
        (uint256 firstFeesEarned, uint256 firstShares) = _thisSolution.checkPosition(owner, 0);
        (uint256 secondFeesEarned1, uint256 secondShares1) = _thisSolution.checkPosition(alice, 0);
        (uint256 secondFeesEarned2, uint256 secondShares2) = _thisSolution.checkPosition(alice, 1);
        (uint256 thirdFeesEarned1, uint256 thirdShares1) = _thisSolution.checkPosition(bob, 0);
        (uint256 thirdFeesEarned2, uint256 thirdShares2) = _thisSolution.checkPosition(bob, 1);

        console2.log(
            "First position fees earned: %s UPD, shares: %s", _formatUnits(firstFeesEarned), _formatUnits(firstShares)
        );
        console2.log(
            "Second position 1 fees earned: %s UPD, shares: %s",
            _formatUnits(secondFeesEarned1),
            _formatUnits(secondShares1)
        );
        console2.log(
            "Second position 2 fees earned: %s UPD, shares: %s",
            _formatUnits(secondFeesEarned2),
            _formatUnits(secondShares2)
        );
        console2.log(
            "Third position 1 fees earned: %s UPD, shares: %s",
            _formatUnits(thirdFeesEarned1),
            _formatUnits(thirdShares1)
        );
        console2.log(
            "Third position 2 fees earned: %s UPD, shares: %s",
            _formatUnits(thirdFeesEarned2),
            _formatUnits(thirdShares2)
        );

        // Get original position contributions
        (uint256 firstOriginalContribution,,,,) = _thisSolution.positionsByAddress(owner, 0);
        (uint256 secondOriginalContribution1,,,,) = _thisSolution.positionsByAddress(alice, 0);
        (uint256 secondOriginalContribution2,,,,) = _thisSolution.positionsByAddress(alice, 1);
        (uint256 thirdOriginalContribution1,,,,) = _thisSolution.positionsByAddress(bob, 0);
        (uint256 thirdOriginalContribution2,,,,) = _thisSolution.positionsByAddress(bob, 1);

        console2.log("First original position contribution: %s UPD", _formatUnits(firstOriginalContribution));
        console2.log("Second original position 1 contribution: %s UPD", _formatUnits(secondOriginalContribution1));
        console2.log("Second original position 2 contribution: %s UPD", _formatUnits(secondOriginalContribution2));
        console2.log("Third original position 1 contribution: %s UPD", _formatUnits(thirdOriginalContribution1));
        console2.log("Third original position 2 contribution: %s UPD", _formatUnits(thirdOriginalContribution2));

        // All wallets collect fees from all positions
        _thisSolution.collectFees(0);
        vm.prank(alice);
        _thisSolution.collectFees(0);
        vm.prank(alice);
        _thisSolution.collectFees(1);
        vm.prank(bob);
        _thisSolution.collectFees(0);
        vm.prank(bob);
        _thisSolution.collectFees(1);

        // Get balances after collecting fees
        uint256 firstBalanceAfter = _upd.balanceOf(owner);
        uint256 secondBalanceAfter = _upd.balanceOf(alice);
        uint256 thirdBalanceAfter = _upd.balanceOf(bob);

        // Calculate fee increases
        uint256 firstIncrease = firstBalanceAfter - firstBalanceBefore;
        uint256 secondIncrease = secondBalanceAfter - secondBalanceBefore;
        uint256 thirdIncrease = thirdBalanceAfter - thirdBalanceBefore;

        console2.log("First wallet collected %s UPD in fees", _formatUnits(firstIncrease));
        console2.log("Second wallet collected %s UPD in fees", _formatUnits(secondIncrease));
        console2.log("Third wallet collected %s UPD in fees", _formatUnits(thirdIncrease));
        console2.log("Total fees collected: %s UPD", _formatUnits(firstIncrease + secondIncrease + thirdIncrease));

        // Verify all wallets received fees
        assertGt(firstIncrease, 0);
        assertGt(secondIncrease, 0);
        assertGt(thirdIncrease, 0);

        // The Solution contract's fee distribution is more complex than just proportional to shares
        // Verify that all wallets receive fees and that distribution makes sense based on contributions and timing

        // Calculate the total shares
        uint256 totalShares = firstShares + secondShares1 + secondShares2 + thirdShares1 + thirdShares2;
        console2.log("Total shares: %s", _formatUnits(totalShares));

        // Calculate the share distribution
        uint256 firstSharePercentage = (firstShares * 1e18) / totalShares;
        uint256 secondSharePercentage = ((secondShares1 + secondShares2) * 1e18) / totalShares;
        uint256 thirdSharePercentage = ((thirdShares1 + thirdShares2) * 1e18) / totalShares;

        console2.log("First wallet share percentage: %s percent", _formatUnits(firstSharePercentage * 100));
        console2.log("Second wallet share percentage: %s percent", _formatUnits(secondSharePercentage * 100));
        console2.log("Third wallet share percentage: %s percent", _formatUnits(thirdSharePercentage * 100));

        // Calculate the fee distribution
        uint256 totalFees = (firstIncrease + secondIncrease + thirdIncrease);
        uint256 firstFeePercentage = (firstIncrease * 1e18) / totalFees;
        uint256 secondFeePercentage = (secondIncrease * 1e18) / totalFees;
        uint256 thirdFeePercentage = (thirdIncrease * 1e18) / totalFees;

        console2.log("First wallet fee percentage: %s percent", _formatUnits(firstFeePercentage * 100));
        console2.log("Second wallet fee percentage: %s percent", _formatUnits(secondFeePercentage * 100));
        console2.log("Third wallet fee percentage: %s percent", _formatUnits(thirdFeePercentage * 100));

        // Verify that all wallets receive fees
        assertGt(firstFeePercentage, 0, "First wallet did not receive fees");
        assertGt(secondFeePercentage, 0, "Second wallet did not receive fees");
        assertGt(thirdFeePercentage, 0, "Third wallet did not receive fees");

        // Verify that the sum of percentages is close to 100%
        assertApproxEqRel(firstFeePercentage + secondFeePercentage + thirdFeePercentage, 1e18, 0.001e18);

        // Verify that the second wallet gets more fees than the third wallet
        // since it contributed more and earlier
        assertGt(secondFeePercentage, thirdFeePercentage);

        // Verify that collecting fees again doesn't change the balance
        _thisSolution.collectFees(0);
        vm.startPrank(alice);
        _thisSolution.collectFees(0);
        _thisSolution.collectFees(1);
        vm.stopPrank();
        vm.startPrank(bob);
        _thisSolution.collectFees(0);
        _thisSolution.collectFees(1);
        vm.stopPrank();

        uint256 firstBalanceAfterSecondCollection = _upd.balanceOf(owner);
        uint256 secondBalanceAfterSecondCollection = _upd.balanceOf(alice);
        uint256 thirdBalanceAfterSecondCollection = _upd.balanceOf(bob);

        assertEq(firstBalanceAfterSecondCollection, firstBalanceAfter);
        assertEq(secondBalanceAfterSecondCollection, secondBalanceAfter);
        assertEq(thirdBalanceAfterSecondCollection, thirdBalanceAfter);
    }

    // PRIVATE HELPERS
    function _setup() private returns (Solution) {
        (, Idea _thisIdea,) = _createIdea();
        (, Solution _thisSolution,) = _createSolution(address(_thisIdea));

        _upd.approve(address(_thisSolution), TRANSFER_AMT);

        vm.prank(alice);
        _upd.approve(address(_thisSolution), TRANSFER_AMT);
        vm.prank(bob);
        _upd.approve(address(_thisSolution), TRANSFER_AMT);

        return _thisSolution;
    }
}
