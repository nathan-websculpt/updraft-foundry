// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./bases/Position_Base.t.sol";

contract Position_Split_Security_Test is Position_Base {
    // forge test --mt testIdeaDoesNotAllowGainingExtraTokensBySplittingPositions -vv
    function testIdeaDoesNotAllowGainingExtraTokensBySplittingPositions() public {
        (, Idea _thisIdea,) = _createIdea();

        _upd.approve(address(_thisIdea), TRANSFER_AMT);

        vm.prank(alice);
        _upd.approve(address(_thisIdea), TRANSFER_AMT);

        uint256 initialPositionCount = _thisIdea.numPositions(owner);
        (uint256 initialPositionTokens, uint256 initialPositionShares) = _thisIdea.checkPosition(owner, 0);

        // Get contract's total tokens before split
        uint256 initialTotalTokens = _thisIdea.tokens();
        uint256 initialTotalShares = _thisIdea.totalShares();

        console2.log("Initial total tokens in contract: %d", initialTotalTokens);
        console2.log("Initial total shares in contract: %d", initialTotalShares);
        console2.log("Initial position tokens: %d", initialPositionTokens);
        console2.log("Initial position shares: %d", initialPositionShares);

        // Split position into 3 parts (original + 2 new)
        _thisIdea.split(0, 3);

        // Check the position count after split
        uint256 finalPositionCount = _thisIdea.numPositions(owner);

        // Get contract's total tokens after split
        uint256 finalTotalTokens = _thisIdea.tokens();
        uint256 finalTotalShares = _thisIdea.totalShares();

        console2.log("Final total tokens in contract: %d", finalTotalTokens);
        console2.log("Final total shares in contract: %d", finalTotalShares);

        // Verify position count increased by 2
        assertEq(finalPositionCount, initialPositionCount + 2);

        // Get all positions' token amounts
        (uint256 position0Tokens,) = _thisIdea.checkPosition(owner, 0);
        (uint256 position1Tokens,) = _thisIdea.checkPosition(owner, 1);
        (uint256 position2Tokens,) = _thisIdea.checkPosition(owner, 2);

        console2.log("Position 0 tokens after split: %d", position0Tokens);
        console2.log("Position 1 tokens: %d", position1Tokens);
        console2.log("Position 2 tokens: %d", position2Tokens);

        // Calculate the sum of all positions' tokens
        uint256 totalPositionTokens = position0Tokens + position1Tokens + position2Tokens;
        console2.log("Sum of all positions' tokens: %d", totalPositionTokens);

        // Verify the sum of all positions' tokens equals the initial position tokens
        assertEq(totalPositionTokens, initialPositionTokens);

        // Verify the contract's total tokens remain unchanged
        assertEq(finalTotalTokens, initialTotalTokens);

        // Verify the contract's total shares remain unchanged
        assertEq(finalTotalShares, initialTotalShares);

        // Try to withdraw all positions and verify the total amount withdrawn
        uint256 initialBalance = _upd.balanceOf(owner);

        _thisIdea.withdraw(0);
        _thisIdea.withdraw(1);
        _thisIdea.withdraw(2);

        uint256 finalBalance = _upd.balanceOf(owner);
        uint256 totalWithdrawn = finalBalance - initialBalance;

        console2.log("Total tokens withdrawn: %d", totalWithdrawn);

        // Verify the total withdrawn equals the initial position tokens
        assertEq(totalWithdrawn, initialPositionTokens);

        // Verify the contract's token balance is now 0
        uint256 contractBalance = _upd.balanceOf(address(_thisIdea));
        console2.log("Contract balance after all withdrawals: %d", contractBalance);
        assertEq(contractBalance, 0);
    }

    // forge test --mt testIdeaDoesNotAllowGainingExtraTokensBySplittingPositionsMultipleTimes -vv
    function testIdeaDoesNotAllowGainingExtraTokensBySplittingPositionsMultipleTimes() public {
        (, Idea _thisIdea,) = _createIdea();

        // Get initial position details
        (uint256 initialPositionTokens, uint256 initialPositionShares) = _thisIdea.checkPosition(owner, 0);

        // Get contract's total tokens before split
        uint256 initialTotalTokens = _thisIdea.tokens();

        console2.log("Initial total tokens in contract: %d", initialTotalTokens);
        console2.log("Initial position tokens: %d", initialPositionTokens);

        // Split position into 2 parts (original + 1 new)
        _thisIdea.split(0, 2);

        // Split the first position again
        _thisIdea.split(0, 2);

        // Split the second position
        _thisIdea.split(1, 2);

        // Get contract's total tokens after splits
        uint256 finalTotalTokens = _thisIdea.tokens();

        console2.log("Final total tokens in contract: %d", finalTotalTokens);

        // Verify the contract's total tokens remain unchanged
        assertEq(finalTotalTokens, initialTotalTokens);

        // Get all positions' token amounts
        uint256 positions = _thisIdea.numPositions(owner);
        console2.log("Total positions after splits: %d", positions);

        uint256 totalPositionTokens = 0;

        // Sum up all positions' tokens
        for (uint256 i = 0; i < positions; i++) {
            (uint256 positionTokens,) = _thisIdea.checkPosition(owner, i);
            console2.log("Position %d tokens: %d", i, positionTokens);
            totalPositionTokens += positionTokens;
        }

        console2.log("Sum of all positions' tokens: %d", totalPositionTokens);

        // Verify the sum of all positions' tokens equals the initial position tokens
        assertEq(totalPositionTokens, initialPositionTokens);

        // Now check all positions in detail
        uint256 detailedTotalTokens = 0;

        // Sum up all positions' tokens
        for (uint256 i = 0; i < positions; i++) {
            (uint256 positionTokens,) = _thisIdea.checkPosition(owner, i);
            console2.log("Position %d tokens: %d", i, positionTokens);
            detailedTotalTokens += positionTokens;
        }

        console2.log("Sum of all positions' tokens (detailed check): %d", detailedTotalTokens);

        // Verify the sum of all positions' tokens equals the initial position tokens
        assertEq(detailedTotalTokens, initialPositionTokens);
    }

    // forge test --mt testSolutionDoesNotAllowGainingExtraTokensBySplittingPositions -vv
    function testSolutionDoesNotAllowGainingExtraTokensBySplittingPositions() public {
        Solution _thisSolution = _setup();

        // Create a position by contributing
        _thisSolution.contribute(CONTRIBUTION_AMT);

        uint256 cycleLength = _thisSolution.cycleLength();

        vm.prank(alice);
        _upd.approve(address(_thisSolution), TRANSFER_AMT);
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

        // Get contract's total tokens and shares before split
        uint256 initialTotalTokens = _thisSolution.totalTokens();
        uint256 initialTotalShares = _thisSolution.totalShares();
        uint256 initialTokensContributed = _thisSolution.tokensContributed();

        console2.log("Initial total tokens in contract: %d", initialTotalTokens);
        console2.log("Initial total shares in contract: %d", initialTotalShares);
        console2.log("Initial tokens contributed: %d", initialTokensContributed);
        console2.log("Initial position fees earned: %d", initialPositionFees);
        console2.log("Initial position shares: %d", initialPositionShares);

        // Get the position's contribution amount
        uint256 initialContribution = _contributionAtAddress(owner, 0, _thisSolution);

        console2.log("Initial contribution: %d", initialContribution);

        // Split position into 3 parts (original + 2 new)
        _thisSolution.split(0, 3);

        // Check the position count after split
        uint256 finalPositionCount = _thisSolution.numPositions(owner);

        // Get contract's total tokens and shares after split
        uint256 finalTotalTokens = _thisSolution.totalTokens();
        uint256 finalTotalShares = _thisSolution.totalShares();
        uint256 finalTokensContributed = _thisSolution.tokensContributed();

        console2.log("Final total tokens in contract: %d", finalTotalTokens);
        console2.log("Final total shares in contract: %d", finalTotalShares);
        console2.log("Final tokens contributed: %d", finalTokensContributed);

        // Verify position count increased by 2
        assertEq(finalPositionCount, initialPositionCount + 2);

        // Verify the contract's total tokens remain unchanged
        assertEq(finalTotalTokens, initialTotalTokens);

        // Verify the contract's total shares remain unchanged
        assertEq(finalTotalShares, initialTotalShares);

        // Verify tokensContributed remains unchanged
        assertEq(finalTokensContributed, initialTokensContributed);

        // Get all positions' contribution amounts
        uint256 position0Contribution = _contributionAtAddress(owner, 0, _thisSolution);
        uint256 position1Contribution = _contributionAtAddress(owner, 1, _thisSolution);
        uint256 position2Contribution = _contributionAtAddress(owner, 2, _thisSolution);

        console2.log("Position 0 contribution after split: %d", position0Contribution);
        console2.log("Position 1 contribution: %d", position1Contribution);
        console2.log("Position 2 contribution: %d", position2Contribution);

        // Calculate the sum of all positions' contributions
        uint256 totalPositionContributions = position0Contribution + position1Contribution + position2Contribution;
        console2.log("Sum of all positions' contributions: %d", totalPositionContributions);

        // Verify the sum of all positions' contributions equals the initial position contribution
        assertEq(totalPositionContributions, initialContribution);

        // Collect fees from all positions and verify the total amount collected
        uint256 initialBalance = _upd.balanceOf(owner);

        _thisSolution.collectFees(0);
        _thisSolution.collectFees(1);
        _thisSolution.collectFees(2);

        uint256 finalBalance = _upd.balanceOf(owner);
        uint256 totalCollected = finalBalance - initialBalance;

        console2.log("Total fees collected: %d", totalCollected);

        // Verify the total collected equals the initial position fees
        // Allow for a small rounding error (up to 3 wei) due to multiple divisions
        uint256 maxAllowedDifference = 3;
        uint256 difference = (totalCollected > initialPositionFees)
            ? totalCollected - initialPositionFees
            : initialPositionFees - totalCollected;

        console2.log("Difference between collected fees and initial fees: %d", difference);
        console2.log("Maximum allowed difference: %d wei", maxAllowedDifference);

        assertLe(difference, maxAllowedDifference);

        if (difference > 0) {
            console2.log(
                "Note: There was a difference of %d wei, which is acceptable due to division rounding", difference
            );
        }
    }

    // forge test --mt testSolutionDoesNotAllowGainingExtraTokensBySplittingPositionsMultipleTimes -vv
    function testSolutionDoesNotAllowGainingExtraTokensBySplittingPositionsMultipleTimes() public {
        Solution _thisSolution = _setup();

        // Create position by contributing
        uint256 contributionAmt = 20e18;
        _thisSolution.contribute(contributionAmt);

        uint256 cycleLength = _thisSolution.cycleLength();

        _upd.transfer(alice, TRANSFER_AMT);
        _upd.approve(address(_thisSolution), TRANSFER_AMT);
        vm.prank(alice);
        _upd.approve(address(_thisSolution), TRANSFER_AMT);

        // Advance time to the second cycle
        skip(cycleLength + 1);

        // Second wallet contributes in the second cycle (this will generate fees)
        uint256 secondContribution = 30e18;
        vm.prank(alice);
        _thisSolution.contribute(secondContribution);

        // Advance time to the second cycle
        skip(cycleLength + 1);

        // Get initial position details
        (uint256 initialPositionFees, uint256 initialPositionShares) = _thisSolution.checkPosition(owner, 0);

        // Get contract's total tokens and shares before split
        uint256 initialTotalTokens = _thisSolution.totalTokens();
        uint256 initialTotalShares = _thisSolution.totalShares();
        uint256 initialTokensContributed = _thisSolution.tokensContributed();

        console2.log("Initial total tokens in contract: %d", initialTotalTokens);
        console2.log("Initial total shares in contract: %d", initialTotalShares);
        console2.log("Initial tokens contributed: %d", initialTokensContributed);
        console2.log("Initial position fees earned: %d", initialPositionFees);
        console2.log("Initial position shares: %d", initialPositionShares);

        // Get the position's contribution amount
        uint256 initialContribution = _contributionAtAddress(owner, 0, _thisSolution);

        console2.log("Initial contribution: %d", initialContribution);

        // Split position into 2 parts (original + 1 new)
        _thisSolution.split(0, 2);

        // Split the first position again
        _thisSolution.split(0, 2);

        // Split the second position
        _thisSolution.split(1, 2);

        // Get contract's total tokens and shares after splits
        uint256 finalTotalTokens = _thisSolution.totalTokens();
        uint256 finalTotalShares = _thisSolution.totalShares();
        uint256 finalTokensContributed = _thisSolution.tokensContributed();

        console2.log("Final total tokens in contract: %d", finalTotalTokens);
        console2.log("Final total shares in contract: %d", finalTotalShares);
        console2.log("Final tokens contributed: %d", finalTokensContributed);

        // Verify the contract's total tokens remain unchanged
        assertEq(finalTotalTokens, initialTotalTokens);

        // Verify the contract's total shares remain unchanged
        assertEq(finalTotalShares, initialTotalShares);

        // Verify tokensContributed remains unchanged
        assertEq(finalTokensContributed, initialTokensContributed);

        // Get all positions' contribution amounts
        uint256 positions = _thisSolution.numPositions(owner);
        console2.log("Total positions after splits: %d", positions);

        // Sum up all positions' contributions
        uint256 totalPositionContributions = 0;
        for (uint256 i = 0; i < positions; i++) {
            uint256 positionContribution = _contributionAtAddress(owner, i, _thisSolution);
            console2.log("Position %d contribution: %d", i, positionContribution);
            totalPositionContributions += positionContribution;
        }

        console2.log("Sum of all positions' contributions: %d", totalPositionContributions);

        // Verify the sum of all positions' contributions equals the initial position contribution
        assertEq(totalPositionContributions, initialContribution);

        // Collect fees from all positions and verify the total amount collected
        uint256 initialBalance = _upd.balanceOf(owner);

        for (uint256 i = 0; i < positions; i++) {
            _thisSolution.collectFees(i);
        }

        uint256 finalBalance = _upd.balanceOf(owner);
        uint256 totalCollected = finalBalance - initialBalance;

        console2.log("Total fees collected: %d", totalCollected);

        // Verify the total collected equals the initial position fees
        // We should expect exact equality or at most a difference of 1 wei due to division rounding
        uint256 maxAllowedDifference = 1;
        uint256 difference = (totalCollected > initialPositionFees)
            ? totalCollected - initialPositionFees
            : initialPositionFees - totalCollected;

        console2.log("Difference between collected fees and initial fees: %d", difference);
        console2.log("Maximum allowed difference: %d wei", maxAllowedDifference);

        assertLe(difference, maxAllowedDifference);

        if (difference > 0) {
            console2.log(
                "Note: There was a difference of %d wei, which is acceptable due to division rounding", difference
            );
        }
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
