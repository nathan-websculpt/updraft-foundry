// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./Idea_Fee_Distribution_Base_Test.t.sol";

// forge test --mt testFeeDistributionRealistic -vv

contract Idea_Fee_Distribution_Realistic_Test is Idea_Fee_Distribution_Base_Test {

    struct Position {
        string wallet;
        uint256 walletIndex;
        uint256 positionIndex;
        uint256 cycle;
        uint256 contribution;
        uint256 contributionAfterFee;
        uint256 contributorFeePaid;
    }

    Position[] positions;

    Idea _thisIdea;
    IERC20 token;
    string[] walletNames = ["first", "second", "third", "fourth", "fifth"]; // TODO: missing in 1 place

    // should handle fee distribution with realistic UPD amounts and many cycles/positions
    function testFeeDistributionRealistic() public {
        uint256 contributorFee = 100_000; // 10%
        console2.log("Creating idea with %d percent contributor fee", contributorFee / 10000);
        uint256 initialContribution = 500e18; // 500 UPD

        vm.recordLogs();
        _updraft.createIdea(contributorFee, initialContribution, _makeIdeaData());
        Vm.Log[] memory logs = vm.getRecordedLogs();

        address ideaAddr = address(uint160(uint256(logs[0].topics[1])));
        _thisIdea = Idea(ideaAddr);

        uint256 transferAmt = 10_000e18;
        _setupApprovals(transferAmt);

        // Get cycle length and other parameters
        uint256 cycleLength = _thisIdea.cycleLength();
        uint256 percentScale = _thisIdea.percentScale();

        console2.log("\n--- Creating test scenario with realistic amounts ---");
        _logContributorFees();

        // Initial contribution was already made during contract creation
        console2.log("\nInitial contribution made during contract creation (500 UPD)");
        uint256 firstContribution = initialContribution;
        uint256 firstContributionAfterFee = firstContribution - ANTI_SPAM_FEE;
        // No contributor fee in first cycle
        positions.push(Position({wallet: "first", walletIndex: 0, positionIndex: 0, cycle: 0, contribution: firstContribution, contributionAfterFee: firstContributionAfterFee, contributorFeePaid: 0}));

        // Create 10 cycles with multiple contributions in each
        for (uint256 cycle = 0; cycle < 10; cycle++) {
            console2.log("\n--- Cycle %d ---", cycle);

            // Each wallet makes a contribution in the cycle
            for (uint160 walletIndex = 0; walletIndex < 5; walletIndex++) {
                // Skip first wallet in first cycle since it already contributed during creation
                if(cycle == 0 && walletIndex == 0) continue;
                
                // Vary contribution amounts to make it more realistic
                uint256 baseAmt = 100 + (walletIndex * 50) + (cycle * 20);
                uint256 contribution = baseAmt * 1e18;
                
                // Ensure we have enough allowance for each contribution
                if(walletIndex == 0) {
                    _upd.approve(address(_thisIdea), contribution);
                    _thisIdea.contribute(contribution);
                } else {
                    vm.startPrank(address(walletIndex));
                    _upd.approve(address(_thisIdea), contribution);
                    _thisIdea.contribute(contribution);
                    vm.stopPrank();

                    // just for my own sanity // TODO: remove
                    if (walletIndex == 0) assertEq(address(walletIndex), owner);
                    else if (walletIndex == 1) assertEq(address(walletIndex), alice);
                    else if (walletIndex == 2) assertEq(address(walletIndex), bob);
                    else if (walletIndex == 3) assertEq(address(walletIndex), james);
                    else if (walletIndex == 4) assertEq(address(walletIndex), kirk);
                }

                console2.log("%d wallet contributed %d UPD in cycle %d", walletIndex, baseAmt, cycle);

                uint256 contributionAfterFee = contribution - ANTI_SPAM_FEE;
                uint256 contributorFeePaid = 0;

                // No contributor fee in first cycle
                if (cycle > 0) {
                    contributorFeePaid = contributionAfterFee * contributorFee / percentScale;
                }

                // get the position index
                uint256 numPositions = _thisIdea.numPositions(address(walletIndex));
                console2.log("%d wallet has %d positions", walletIndex, numPositions); // TODO: remove after discussing with team

                // TODO: talk with Adam - the 0 wallet has a positions in all cycles - there is an IF up above looking for walletIndex == 0 and cycle == 0 ... 
                uint256 positionIndex;
                if(numPositions > 0) {
                    positionIndex = numPositions - 1;   
                } else {
                    positionIndex = 0;
                }

                string memory walletName = "Unknown";
                if (walletIndex == 0) walletName = "first";
                else if (walletIndex == 1) walletName = "second";
                else if (walletIndex == 2) walletName = "third";
                else if (walletIndex == 3) walletName = "fourth";
                else if (walletIndex == 4) walletName = "fifth";
                positions.push(Position({wallet: walletName, walletIndex: walletIndex, positionIndex: positionIndex, cycle: cycle, contribution: contribution, contributionAfterFee: contributionAfterFee, contributorFeePaid: contributorFeePaid}));

                // Advance time to the next cycle
                skip(cycleLength + 1);
                console2.log("Advanced to cycle %d", cycle + 1);
                _logContributorFees();

                // Make a final small contribution to update cycles
                uint256 finalContribution = ANTI_SPAM_FEE * 2;
                // Ensure we have enough allowance for the final contribution
                _upd.approve(address(_thisIdea), finalContribution);
                _thisIdea.contribute(finalContribution);
                console2.log("\nFirst wallet made small contribution in final cycle");
                uint256 finalContributionAfterFee = finalContribution - ANTI_SPAM_FEE;
                uint256 finalContributionContributorFee = finalContributionAfterFee * contributorFee / percentScale;

                // Get the position index
                uint256 finalPositionIndex = _thisIdea.numPositions(owner) - 1;
                positions.push(Position({wallet: "first", walletIndex: 0, positionIndex: finalPositionIndex, cycle: 10, contribution: finalContribution, contributionAfterFee: finalContributionAfterFee, contributorFeePaid: finalContributionContributorFee}));

                _logContributorFees();
                
                // Get the token contract
                token = _thisIdea.token();

                uint256 totalContributions = 0;
                uint256 totalAntiSpamFees = 0;
                uint256 totalContributorFees = 0;

                for (uint256 i = 0; i < positions.length; i++) {
                    totalContributions += positions[i].contribution;
                    totalAntiSpamFees += (positions[i].contribution - positions[i].contributionAfterFee);
                    totalContributorFees += positions[i].contributorFeePaid;
                }

                uint256 expectedNetContributions = totalContributions - totalAntiSpamFees;
                // Log the contract balance before withdrawals
                uint256 balanceBeforeWithdrawals = token.balanceOf(address(_thisIdea));
                console2.log("\nContract balance before withdrawals: %d UPD", balanceBeforeWithdrawals);

                // Log the contract's internal token tracking before withdrawals
                uint256 tokensBeforeWithdrawals = _thisIdea.tokens();
                console2.log("Contract's internal token tracking before withdrawals: %d UPD", tokensBeforeWithdrawals);

                // Log expected values
                console2.log("\nTotal contributions: %d", totalContributions);
                console2.log("Total anti-spam fees: %d", totalAntiSpamFees);
                console2.log("Total contributor fees: %d", totalContributorFees);
                console2.log("Expected net contributions: %d", expectedNetContributions);

                // Get all positions for each wallet
                uint256[] memory walletPositions = new uint256[](walletNames.length);
                for (uint256 i = 0; i < walletNames.length; i++) {
                   uint256 numberPositions = _thisIdea.numPositions(address(uint160(i)));
                   walletPositions[i] = numberPositions;
                   console2.log("%s wallet has %d positions", walletNames[i], numberPositions);
                }

                
            }
        }
    }

    // PRIVATE HELPER FUNCTIONS
    function _logContributorFees() private {
        uint256 contributorFees = _thisIdea.contributorFees();
        console2.log("Contributor fees: %d UPD", contributorFees);
    }

    function _setupApprovals(uint _transferAmt) private {
        _upd.approve(address(_thisIdea), _transferAmt);
        vm.startPrank(alice);
        _upd.approve(address(_thisIdea), _transferAmt);
        vm.stopPrank();
        vm.prank(bob);
        _upd.approve(address(_thisIdea), _transferAmt);
        vm.stopPrank();
        vm.prank(james);
        _upd.approve(address(_thisIdea), _transferAmt);
        vm.stopPrank();
        vm.prank(kirk);
        _upd.approve(address(_thisIdea), _transferAmt);

        _upd.transfer(owner, _transferAmt);
        _upd.transfer(alice, _transferAmt);
        _upd.transfer(bob, _transferAmt);
        _upd.transfer(james, _transferAmt);
        _upd.transfer(kirk, _transferAmt);
    }
}