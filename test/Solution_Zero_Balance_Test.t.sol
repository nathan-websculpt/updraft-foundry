// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./bases/Solution_Base.t.sol";

// forge test --mt testAllowsContributorFeesToBeFullyCollected -vv

contract Solution_Zero_Balance_Test is Solution_Base {
    IERC20 token;

    function testAllowsContributorFeesToBeFullyCollected() public {
        Solution _thisSolution = _setup();
        _upd.approve(address(_thisSolution), 1000e18);

        console2.log("\n--- Creating test scenario ---");

        uint256 cycleLength = _thisSolution.cycleLength();

        // First wallet contributes in the first cycle
        uint256 firstContribution = 50e18;
        _thisSolution.contribute(firstContribution);
        console2.log("First wallet contributed in first cycle");

        // Second wallet contributes in the first cycle
        uint256 secondContribution = 20e18;
        vm.prank(alice);
        _thisSolution.contribute(secondContribution);
        console2.log("Second wallet contributed in first cycle");

        // Third wallet contributes in the first cycle
        uint256 thirdContribution = 30e18;
        vm.prank(bob);
        _thisSolution.contribute(thirdContribution);
        console2.log("Third wallet contributed in first cycle");

        // Advance time to the second cycle
        skip(cycleLength + 1);
        console2.log("Advanced to second cycle");

        // First wallet contributes in the second cycle
        uint256 firstContributionSecondCycle = 15e18;
        _thisSolution.contribute(firstContributionSecondCycle);
        console2.log("First wallet contributed in second cycle");

        // Advance time to the third cycle
        skip(cycleLength + 1);
        console2.log("Advanced to third cycle");

        // Second wallet contributes in the third cycle
        uint256 secondContributionThirdCycle = 25e18;
        vm.prank(alice);
        _thisSolution.contribute(secondContributionThirdCycle);
        console2.log("Second wallet contributed in third cycle");

        // Advance time to the fourth cycle
        skip(cycleLength + 1);
        console2.log("Advanced to fourth cycle");

        // Make a small contribution to update cycles
        _thisSolution.contribute(ANTI_SPAM_FEE * 2);
        console2.log("First wallet made a small contribution in fourth cycle");

        // Get the token contract
        token = IERC20(_thisSolution.fundingToken());
        uint256 balanceBeforeCollection = token.balanceOf(address(_thisSolution));
        console2.log("\nContract balance before fee collection: ", balanceBeforeCollection);

        uint256 tokensContributed = _thisSolution.tokensContributed();
        uint256 tokensWithdrawn = _thisSolution.tokensWithdrawn();
        console2.log("Contract tokensContributed: ", tokensContributed);
        console2.log("Contract tokensWithdrawn: ", tokensWithdrawn);
        console2.log("Contract totalTokens: ", tokensContributed - tokensWithdrawn);

        uint256 firstWalletPositions = _thisSolution.numPositions(owner);
        uint256 secondWalletPositions = _thisSolution.numPositions(alice);
        uint256 thirdWalletPositions = _thisSolution.numPositions(bob);

        console2.log("\nFirst wallet has ", firstWalletPositions, " positions");
        console2.log("Second wallet has ", secondWalletPositions, " positions");
        console2.log("Third wallet has ", thirdWalletPositions, " positions");

        // Log each position's details
        console2.log('\n--- Position details ---');
        for (uint256 i = 0; i < firstWalletPositions; i++) {
            (uint256 feesEarned, uint256 shares) = _thisSolution.checkPosition(owner, i);
            console2.log("First wallet position %d: feesEarned=%d, shares=%d", i, feesEarned, shares);
        }

        for (uint256 i = 0; i < secondWalletPositions; i++) {
            (uint256 feesEarned, uint256 shares) = _thisSolution.checkPosition(alice, i);
            console2.log("Second wallet position %d: feesEarned=%d, shares=%d", i, feesEarned, shares);
        }

        for (uint256 i = 0; i < thirdWalletPositions; i++) {
            (uint256 feesEarned, uint256 shares) = _thisSolution.checkPosition(bob, i);
            console2.log("Third wallet position %d: feesEarned=%d, shares=%d", i, feesEarned, shares);
        }

        // Collect fees for all positions
        console2.log("\n--- Collecting fees for all positions ---");

        // First wallet positions
        console2.log("\nFirst wallet positions:");
        for (uint256 i = 0; i < firstWalletPositions; i++) {
            try _thisSolution.collectFees(i) {
                console2.log("Successfully collected fees for first wallet position %d", i);
            } catch Error(string memory reason) {
                console2.log("Error collecting fees for first wallet position %d: %s", i, reason);
            }
        }

        // Second wallet positions
        console2.log("\nSecond wallet positions:");
        for (uint256 i = 0; i < secondWalletPositions; i++) {
            vm.prank(alice);
            try _thisSolution.collectFees(i) {
                console2.log("Successfully collected fees for second wallet position %d", i);
            } catch Error(string memory reason) {
                console2.log("Error collecting fees for second wallet position %d: %s", i, reason);
            }
        }

        // Third wallet positions
        console2.log("\nThird wallet positions:");
        for (uint256 i = 0; i < thirdWalletPositions; i++) {
            vm.prank(bob);
            try _thisSolution.collectFees(i) {
                console2.log("Successfully collected fees for third wallet position %d", i);
            } catch Error(string memory reason) {
                console2.log("Error collecting fees for third wallet position %d: %s", i, reason);
            }
        }

        // Check the contract's token balance after fee collection
        uint256 contractBalanceAfterCollection = token.balanceOf(address(_thisSolution));
        console2.log("\nContract balance after fee collection: ", contractBalanceAfterCollection);

        // Check the contract's internal token tracking after fee collection
        uint256 tokensContributedAfter = _thisSolution.tokensContributed();
        uint256 tokensWithdrawnAfter = _thisSolution.tokensWithdrawn();
        console2.log("Contract tokensContributed after: ", tokensContributedAfter);
        console2.log("Contract tokensWithdrawn after: ", tokensWithdrawnAfter);
        console2.log("Contract totalTokens after: ", tokensContributedAfter - tokensWithdrawnAfter);

        // Get information about cycles
        console2.log('\n--- Cycle information ---');

        // obtain the length of the cycles array via its storage slot
        // forge inspect Solution storage-layout --pretty
        uint256 slot = 7;
        uint256 cyclesArrayLength = uint256(vm.load(address(_thisSolution), bytes32(slot)));

        if(cyclesArrayLength > 0) {
            for(uint256 i = 0; i < cyclesArrayLength; i++) {
                (uint256 number, uint256 shares, uint256 fees, bool hasContributions) = _thisSolution.cycles(i);
                console2.log("Cycle %d: hasContributions=%s", i, hasContributions);
                console2.log("\t   number=%d, shares=%d, fees=%d", number, shares, fees);
            }
        }

        // Calculate total contributor fees that should have been collected
        // Contributor fee is 10% of contributions after the first cycle
        uint256 contributorFeePercent = _thisSolution.contributorFee();
        uint256 percentScale = _thisSolution.percentScale();

        // Calculate expected contributor fees
        // First cycle contributions don't have contributor fees
        uint256 firstCycleContributions = firstContribution + secondContribution + thirdContribution;
        uint256 laterCycleContributions = firstContributionSecondCycle + secondContributionThirdCycle + (ANTI_SPAM_FEE * 2);
        uint256 expectedContributorFees = (laterCycleContributions * contributorFeePercent) / percentScale;

        console2.log("\nFirst cycle contributions: ", firstCycleContributions);
        console2.log("Later cycle contributions: ", laterCycleContributions);
        console2.log("Expected contributor fees: ", expectedContributorFees);

        // Calculate actual fees collected
        uint256 totalFeesCollected = balanceBeforeCollection - contractBalanceAfterCollection;
        console2.log("Actual fees collected: ", totalFeesCollected);

        // Calculate the difference
        uint256 feesDifference = expectedContributorFees - totalFeesCollected;
        console2.log("Difference between expected and actual fees: ", feesDifference);

        // Verify that all contributor fees were collected
        // Allow for a small rounding error (up to 4 wei) due to multiple divisions
        uint256 maxAllowedDifference = 4;
        console2.log("Maximum allowed difference: ", maxAllowedDifference, " wei");

        // This test verifies that all contributor fees can be collected from the Solution contract
        uint256 absDifference = feesDifference < 0 ? uint256(-int256(feesDifference)) : feesDifference;
        assertLe(absDifference, maxAllowedDifference);

        if (absDifference > 0) {
            console2.log("Note: There was a difference of ", absDifference, " wei, which is acceptable due to division rounding");
        }

        // Also verify that the contract's internal accounting is correct
        uint256 contributedMinusWithdrawn = tokensContributedAfter - tokensWithdrawnAfter;
        uint256 expectedBalance = contributedMinusWithdrawn + 100e18; // Add stake
        int256 balanceDifference = int256(expectedBalance) - int256(contractBalanceAfterCollection);

        console2.log("\nContract balance: ", contractBalanceAfterCollection);
        console2.log("Expected balance (contributed - withdrawn + stake): ", expectedBalance);
        console2.log("Balance difference: ", balanceDifference);

        // Verify that the contract's balance matches its internal accounting
        uint256 absBalanceDifference = balanceDifference < 0 ? uint256(-balanceDifference) : uint256(balanceDifference);
        assertLe(absBalanceDifference, maxAllowedDifference);

        if (absBalanceDifference > 0) {
            console2.log("Note: There was a balance difference of ", absBalanceDifference, " wei, which is acceptable due to division rounding");
        }
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