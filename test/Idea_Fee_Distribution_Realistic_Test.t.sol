// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./bases/Idea_Fee_Distribution_Base.t.sol";

// forge test --mt testRealisticFeeDistribution -vv

contract Idea_Fee_Distribution_Realistic_Test is Idea_Fee_Distribution_Base {

    struct Position {
        string wallet;
        uint256 walletIndex;
        uint256 positionIndex;
        uint256 cycle;
        uint256 contribution;
        uint256 contributionAfterFee;
        uint256 contributorFeePaid;
        uint256 actualWithdrawn;
    }

    Position[] positions;
    uint256[] walletWithdrawals;

    Idea _thisIdea;
    IERC20 token;
    string[] walletNames = ["first", "second", "third", "fourth", "fifth"];

    // should handle fee distribution with realistic UPD amounts and many cycles/positions
    function testRealisticFeeDistribution() public {
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
        positions.push(Position({wallet: "first", walletIndex: 0, positionIndex: 0, cycle: 0, contribution: firstContribution, contributionAfterFee: firstContributionAfterFee, contributorFeePaid: 0, actualWithdrawn: 0}));

        // Create 10 cycles with multiple contributions in each
        for (uint256 cycle = 0; cycle < 10; cycle++) {
            console2.log("\n--- Cycle %d ---", cycle);

            // Each wallet makes a contribution in the cycle
            for (uint256 walletIndex = 0; walletIndex < walletNames.length; walletIndex++) {
                // Skip first wallet in first cycle since it already contributed during creation
                if(cycle == 0 && walletIndex == 0) continue;

                address _thisWallet = _getThisWallet(walletIndex);
                
                // Vary contribution amounts to make it more realistic
                uint256 baseAmt = 100 + (walletIndex * 50) + (cycle * 20);
                uint256 contribution = baseAmt * 1e18;
                
                // Ensure we have enough allowance for each contribution

                if(walletIndex == 0) {
                    _upd.approve(address(_thisIdea), contribution);
                    _thisIdea.contribute(contribution);
                } else {
                    vm.startPrank(_thisWallet);
                    _upd.approve(address(_thisIdea), contribution);
                    _thisIdea.contribute(contribution);
                    vm.stopPrank();
                }

                console2.log("%s wallet contributed %d UPD in cycle %d", walletNames[walletIndex], baseAmt, cycle);

                uint256 contributionAfterFee = contribution - ANTI_SPAM_FEE;
                uint256 contributorFeePaid = 0;

                // No contributor fee in first cycle
                if (cycle > 0) {
                    contributorFeePaid = contributionAfterFee * contributorFee / percentScale;
                }

                // get the position index
                uint256 positionIndex = _thisIdea.numPositions(_thisWallet) - 1;

                positions.push(Position({wallet: walletNames[walletIndex], walletIndex: walletIndex, positionIndex: positionIndex, cycle: cycle, contribution: contribution, contributionAfterFee: contributionAfterFee, contributorFeePaid: contributorFeePaid, actualWithdrawn: 0}));
            }
            // Advance time to the next cycle
            skip(cycleLength + 1);
            console2.log("Advanced to cycle %d", cycle + 1);
            _logContributorFees();
        }
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
        positions.push(Position({wallet: "first", walletIndex: 0, positionIndex: finalPositionIndex, cycle: 10, contribution: finalContribution, contributionAfterFee: finalContributionAfterFee, contributorFeePaid: finalContributionContributorFee, actualWithdrawn: 0}));

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
        console2.log("\nContract balance before withdrawals: %s UPD", _formatUnits(balanceBeforeWithdrawals));

        // Log the contract's internal token tracking before withdrawals
        uint256 tokensBeforeWithdrawals = _thisIdea.tokens();
        console2.log("Contract's internal token tracking before withdrawals: %s UPD", _formatUnits(tokensBeforeWithdrawals));

        // Log expected values
        console2.log("\nTotal contributions: %s", _formatUnits(totalContributions));
        console2.log("Total anti-spam fees: %s", _formatUnits(totalAntiSpamFees));
        console2.log("Total contributor fees: %s", _formatUnits(totalContributorFees));
        console2.log("Expected net contributions: %s", _formatUnits(expectedNetContributions));

        // Get all positions for each wallet
        uint256[] memory walletPositions = new uint256[](walletNames.length);
        for (uint256 i = 0; i < walletNames.length; i++) {
            uint256 numberPositions = _thisIdea.numPositions(_getThisWallet(i));
            walletPositions[i] = numberPositions;
            console2.log("%s wallet has %d positions", walletNames[i], numberPositions);
        }

        // Get all cycles
        // obtain the length of the cycles array via its storage slot
        // forge inspect Idea storage-layout --pretty
        uint256 slot = 2;
        uint256 cyclesArrayLength = uint256(vm.load(address(_thisIdea), bytes32(slot)));

        if(cyclesArrayLength > 0) {
            for(uint256 i = 0; i < cyclesArrayLength; i++) {
                (uint256 number, uint256 shares, uint256 fees, bool hasContributions) = _thisIdea.cycles(i);
                // console2.log("Cycle %d: hasContributions=%s", i, hasContributions);
                // console2.log("\t   number=%d, shares=%d, fees=%d", number, shares, fees);
            }
        }

        console2.log("found %d cycles", cyclesArrayLength);

        // Withdraw all positions for all wallets
        console2.log("\n--- Withdrawing all positions ---");

        for(uint256 walletIndex = 0; walletIndex < walletNames.length; walletIndex++) {
            console2.log("\n%s wallet positions:", walletNames[walletIndex]);
            uint256 walletWithdrawn = 0;

            for(uint256 positionIndex = 0; positionIndex < walletPositions[walletIndex]; positionIndex++){
                uint256 withdrawn = _trackWithdrawal(walletNames[walletIndex], walletIndex, positionIndex);
                walletWithdrawn += withdrawn;
            }

            walletWithdrawals.push(walletWithdrawn);
            console2.log("Total withdrawn by %s wallet: %s UPD", walletNames[walletIndex], _formatUnits(walletWithdrawn));
        }
        // Calculate wallet contributions and profits
        console2.log("\n--- Wallet Contributions and Profits ---");

        uint256 totalWithdrawn = 0;

        for (uint256 walletIndex = 0; walletIndex < walletNames.length; walletIndex++) {
            // Calculate total contributions by this wallet
            uint256 walletContributions = 0;
            uint256 walletContributionsAfterFee = 0;
        
            for (uint256 positionIndex = 0; positionIndex < positions.length; positionIndex++) {
                if (positions[positionIndex].walletIndex == walletIndex) {
                walletContributions += positions[positionIndex].contribution;
                walletContributionsAfterFee += positions[positionIndex].contributionAfterFee - positions[positionIndex].contributorFeePaid;
                }
            }
        
            uint256 walletProfit = walletWithdrawals[walletIndex] - walletContributionsAfterFee;
        
            console2.log("%s wallet:", walletNames[walletIndex]);
            console2.log("  Total contributions: %s UPD", _formatUnits(walletContributions));
            console2.log("  Contributions after fees: %s UPD", _formatUnits(walletContributionsAfterFee));
            console2.log("  Total withdrawals: %s UPD", _formatUnits(walletWithdrawals[walletIndex]));
            console2.log("  Profit: %s UPD", _formatUnits(walletProfit));
        
            totalWithdrawn += walletWithdrawals[walletIndex];
        }
        
        // Check the contract's token balance
        uint256 contractBalance = token.balanceOf(address(_thisIdea));
        console2.log("\nContract balance after all withdrawals: %s", _formatUnits(contractBalance));

        // Check the contract's internal token tracking
        uint256 contractTokens = _thisIdea.tokens();
        console2.log("Contract internal tokens tracking: %s", _formatUnits(contractTokens));

        // Check the contract's contributorFees
        _logContributorFees();

        // Verify that all tokens were withdrawn
        console2.log("\n--- Verification ---");
        console2.log("Expected net contributions: %s", _formatUnits(expectedNetContributions));
        console2.log("Total withdrawn: %s", _formatUnits(totalWithdrawn));
        console2.log("Difference: %s", _formatUnits(expectedNetContributions - totalWithdrawn));
        console2.log("Tokens left in contract: %s", _formatUnits(contractBalance));

        // Calculate percentage of tokens left in contract
        if (contractBalance > 0) {
            uint256 percentageLeft = (contractBalance * 100) / expectedNetContributions;
            console2.log("Percentage of tokens left in contract: ", percentageLeft, "%");
        }

        assertEq(contractBalance, 0);        
    }

    // PRIVATE HELPER FUNCTIONS
    function _logContributorFees() private {
        uint256 contributorFees = _thisIdea.contributorFees();
        console2.log("Contributor fees: %s UPD", _formatUnits(contributorFees));
    }

    // Helper function to track wallet balances and contributor fees during withdrawals
    function _trackWithdrawal(string memory walletName, uint256 walletIndex, uint256 positionIndex) private returns (uint256 withdrawn) {
        address walletAddress = _getThisWallet(walletIndex);
        (uint256 positionTokens, uint256 shares) = _checkPositionDetails(walletName, walletIndex, positionIndex, walletAddress);
        
        uint256 balanceBefore = token.balanceOf(walletAddress);
        uint256 contributorFeesBefore = _thisIdea.contributorFees();

        // Perform the withdrawal
        vm.prank(walletAddress);
        _thisIdea.withdraw(positionIndex);

        // Get balances and contributor fees after withdrawal
        uint256 balanceAfter = token.balanceOf(walletAddress);
        uint256 contributorFeesAfter = _thisIdea.contributorFees();

        // Calculate changes
        uint256 withdrawn = balanceAfter - balanceBefore;
        uint256 contributorFeesChange = contributorFeesBefore - contributorFeesAfter;

        // Find the position in our tracking 
        Position memory position = _findPosition(walletName, positionIndex);
        
        position.actualWithdrawn = withdrawn; // set on storage

        // Calculate the original contribution amount (after anti-spam fee but before contributor fee)
        uint256 originalContribution = position.contributionAfterFee - position.contributorFeePaid;

        // Calculate fees earned
        int256 feesEarned = int256(withdrawn) - int256(originalContribution);

        console2.log("Successfully withdrew %s wallet position %d:", walletName, positionIndex);
        console2.log("  Withdrawn amount: %s UPD", _formatUnits(withdrawn));
        console2.log("  Original contribution: %s UPD", _formatUnits(originalContribution));
        console2.log("  Fees earned: %s UPD", feesEarned);
        console2.log("  Contributor fees change: %s UPD", _formatUnits(contributorFeesChange));
        console2.log("  Contributor fees remaining: %s UPD", _formatUnits(contributorFeesAfter));

        return withdrawn;      
    }

    // Helper function to check position details before withdrawal
    function _checkPositionDetails(string memory walletName, uint256 walletIndex, uint256 positionIndex, address walletAddress) private returns(uint256, uint256) {
        vm.prank(walletAddress);
        (uint256 positionTokens, uint256 shares) = _thisIdea.checkPosition(walletAddress, positionIndex);
        
        // Get contract balance
        uint256 contractBalance = token.balanceOf(address(_thisIdea));
        uint256 contractTokens = _thisIdea.tokens();
        uint256 contributorFees = _thisIdea.contributorFees();

        // find position
        Position memory position = _findPosition(walletName, positionIndex);

        // Calculate the original contribution amount (after anti-spam fee but before contributor fee)
        uint256 originalContribution = position.contributionAfterFee - position.contributorFeePaid;

        // Get the original position tokens from the contract
        (,uint256 originalPositionTokens) = _thisIdea.positionsByAddress(walletAddress, positionIndex);

        // Calculate fees that would be earned in this withdrawal
        uint256 feesToBeEarned = positionTokens - originalPositionTokens;

        console2.log("Position check for %s wallet position %d:", walletName, positionIndex);
        console2.log("  Original contribution: %s UPD", _formatUnits(originalContribution));
        console2.log("  Position details from contract:");
        console2.log("    Tokens from checkPosition: %s UPD", _formatUnits(positionTokens));
        console2.log("    Original position tokens: %s UPD", _formatUnits(originalPositionTokens));
        console2.log("    Fees to be earned: %s UPD", _formatUnits(feesToBeEarned));
        console2.log("    Shares: %s shares", _formatUnits(shares));
        console2.log("  Contract state:");
        console2.log("    Contract balance: %s UPD", _formatUnits(contractBalance));
        console2.log("    Contract tokens: %s UPD", _formatUnits(contractTokens));
        console2.log("    Contributor fees: %s UPD", _formatUnits(contributorFees));

        // Check if position is trying to withdraw more than what's left
        if (positionTokens > contractBalance) {
            console2.log("  WARNING: Position is trying to withdraw %s UPD, but contract only has %s UPD", _formatUnits(positionTokens), _formatUnits(contractBalance));
            console2.log("  Difference: %s UPD", _formatUnits(positionTokens - contractBalance));
        }

        // Check if position is trying to withdraw more fees than available
        if (feesToBeEarned > contributorFees) {
            console2.log("  WARNING: Position is trying to withdraw %s UPD in fees, but contract only has %s UPD in contributorFees", _formatUnits(feesToBeEarned), _formatUnits(contributorFees));
            console2.log("  Difference: %s UPD", _formatUnits(feesToBeEarned - contributorFees));
            console2.log("  This will likely cause an underflow in the contributorFees subtraction!");
        }

        return (positionTokens, shares);
    }

    function _findPosition(string memory walletName, uint256 positionIndex) private returns(Position memory) {
        for(uint256 i; i < positions.length; i++) {
            Position memory position = positions[i];
            if(keccak256(abi.encodePacked(position.wallet)) == keccak256(abi.encodePacked(walletName)) && positions[i].positionIndex == positionIndex) {
                return position;
            }
        }
        revert("Failed to find position in function: _findPosition");
    }

    function _getThisWallet(uint256 walletIndex) private returns(address) {
        if(walletIndex == 0) return owner;
        else if(walletIndex == 1) return alice;
        else if(walletIndex == 2) return bob;
        else if(walletIndex == 3) return james;
        else if(walletIndex == 4) return kirk;        
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