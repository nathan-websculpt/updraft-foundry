// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./bases/Position_Base.t.sol";

contract Position_Self_Transfer_Test is Position_Base {
    // Idea contract should delete the original position and create a new one when transferring to yourself without gaining extra tokens
    // forge test --mt testIdeaDeletesOriginalPositionWhenTransferringSelfWithoutGainingExtraTokens -vv
    function testIdeaDeletesOriginalPositionWhenTransferringSelfWithoutGainingExtraTokens() public {
        (, Idea _thisIdea,) = _createIdea();

        // Get initial position details
        uint256 initialPositionCount = _thisIdea.numPositions(owner);
        (uint256 initialPositionTokens, uint256 initialPositionShares) = _thisIdea.checkPosition(owner, 0);

        // Get contract's total tokens before transfer
        uint256 initialTotalTokens = _thisIdea.tokens();
        uint256 initialTotalShares = _thisIdea.totalShares();

        console2.log("Initial total tokens in contract: %d", initialTotalTokens);
        console2.log("Initial total shares in contract: %d", initialTotalShares);
        console2.log("Initial position tokens: %d", initialPositionTokens);
        console2.log("Initial position shares: %d", initialPositionShares);

        // Transfer the position to the same address
        _thisIdea.transferPosition(owner, 0);

        // Check the position count after transfer
        uint256 finalPositionCount = _thisIdea.numPositions(owner);

        // Get contract's total tokens after transfer
        uint256 finalTotalTokens = _thisIdea.tokens();
        uint256 finalTotalShares = _thisIdea.totalShares();

        console2.log("Final total tokens in contract: %d", finalTotalTokens);
        console2.log("Final total shares in contract: %d", finalTotalShares);

        // Verify position count increased by 1
        assertEq(finalPositionCount, initialPositionCount + 1);

        // Verify original position no longer exists
        vm.expectRevert(Idea.PositionDoesNotExist.selector);
        _thisIdea.checkPosition(owner, 0);
    }

    // forge test --mt testSolutionDeletesOriginalPositionWhenTransferringSelfWithoutGainingExtraTokens -vv
    function testSolutionDeletesOriginalPositionWhenTransferringSelfWithoutGainingExtraTokens() public {
        Solution _thisSolution = _setup();

        // Create a position by contributing
        _thisSolution.contribute(CONTRIBUTION_AMT);

        // Get cycle length and advance time to accumulate shares and fees
        uint256 cycleLength = _thisSolution.cycleLength();

        // Create a second wallet and have it contribute to generate fees
        vm.prank(alice);
        _upd.approve(address(_thisSolution), TRANSFER_AMT);

        // Advance time to the second cycle
        skip(cycleLength + 1);

        // Second wallet contributes in the second cycle (this will generate fees)
        uint256 secondContribution = 30e18;
        vm.prank(alice);
        _thisSolution.contribute(secondContribution);

        // Advance time to the third cycle to accumulate more shares
        skip(cycleLength + 1);

        // Get initial position details
        uint256 initialPositionCount = _thisSolution.numPositions(owner);
        (uint256 initialPositionFees, uint256 initialPositionShares) = _thisSolution.checkPosition(owner, 0);

        // Get contract's total tokens and shares before transfer
        uint256 initialTotalTokens = _thisSolution.totalTokens();
        uint256 initialTotalShares = _thisSolution.totalShares();

        console2.log("Initial total tokens in contract: %d", initialTotalTokens);
        console2.log("Initial total shares in contract: %d", initialTotalShares);
        console2.log("Initial position fees earned: %d", initialPositionFees);
        console2.log("Initial position shares: %d", initialPositionShares);

        // Get the position's contribution amount and other details
        (uint256 initialContribution,, uint256 initialStartCycleIndex, uint256 initialLastCollectedCycleIndex,) =
            _thisSolution.positionsByAddress(owner, 0);

        console2.log("Initial contribution: %d", initialContribution);
        console2.log("Initial startCycleIndex: %d", initialStartCycleIndex);
        console2.log("Initial lastCollectedCycleIndex: %d", initialLastCollectedCycleIndex);

        // Transfer the position to the same address
        _thisSolution.transferPosition(owner, 0);

        // Check the position count after transfer
        uint256 finalPositionCount = _thisSolution.numPositions(owner);

        // Get contract's total tokens and shares after transfer
        uint256 finalTotalTokens = _thisSolution.totalTokens();
        uint256 finalTotalShares = _thisSolution.totalShares();

        console2.log("Final total tokens in contract: %d", finalTotalTokens);
        console2.log("Final total shares in contract: %d", finalTotalShares);

        // Verify position count increased by 1
        assertEq(finalPositionCount, initialPositionCount + 1);

        // Verify original position is empty (deleted)
        (uint256 emptyContribution,,,,) = _thisSolution.positionsByAddress(owner, 0);
        assertEq(emptyContribution, 0);

        // Verify new position has the same properties as the original
        uint256 newPositionIndex = finalPositionCount - 1;
        (uint256 newContribution,, uint256 newStartCycleIndex, uint256 newLastCollectedCycleIndex,) =
            _thisSolution.positionsByAddress(owner, newPositionIndex);
        (uint256 newPositionFees, uint256 newPositionShares) = _thisSolution.checkPosition(owner, newPositionIndex);

        console2.log("New position fees earned: %d", newPositionFees);
        console2.log("New position shares: %d", newPositionShares);
        console2.log("New contribution: %d", newContribution);
        console2.log("New startCycleIndex: %d", newStartCycleIndex);
        console2.log("New lastCollectedCycleIndex: %d", newLastCollectedCycleIndex);

        // Verify the new position has the same contribution as the original
        assertEq(newContribution, initialContribution);

        // Verify the new position has the same startCycleIndex as the original
        assertEq(newStartCycleIndex, initialStartCycleIndex);

        // Verify the new position has the same lastCollectedCycleIndex as the original
        assertEq(newLastCollectedCycleIndex, initialLastCollectedCycleIndex);

        // Verify the new position has the same shares as the original
        assertEq(newPositionShares, initialPositionShares);

        // Verify the new position has the same fees as the original
        assertEq(newPositionFees, initialPositionFees);

        // Verify the contract's total tokens remain unchanged
        assertEq(finalTotalTokens, initialTotalTokens);

        // Verify the contract's total shares remain unchanged
        assertEq(finalTotalShares, initialTotalShares);
    }

    // PRIVATE HELPERS
    function _setup() private returns (Solution) {
        (, Idea _thisIdea,) = _createIdea();
        (, Solution _thisSolution,) = _createSolution(address(_thisIdea));

        _upd.approve(address(_thisSolution), TRANSFER_AMT);

        vm.prank(alice);
        _upd.approve(address(_thisSolution), TRANSFER_AMT);

        return _thisSolution;
    }
}
