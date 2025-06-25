// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console2, Vm} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Updraft} from "../src/Updraft.sol";
import {Idea} from "../src/Idea.sol";
import {UPDToken} from "../src/UPDToken.sol";
import {Utils} from "./lib/Utils.sol";

// forge test --mt testFeeDistribution -vv

contract Idea_Fee_Distribution_Test is Test, Utils {
    
    Updraft _updraft;
    UPDToken _upd;

    address owner;
    address alice;
    address bob;
    address faucet = 0xdC0046B52e2E38AEe2271B6171ebb65cCD337518; // fund that collects and distributes a universal dividend

    uint256 constant ANTI_SPAM_FEE = 1e18; // 1 UPD
    uint256 constant PERCENT_FEE = 10_000; // 1%
    uint256 constant ACCRUAL_RATE = 100_000; // 10%
    uint256 constant CYCLE_LENGTH = 3600; // 1 hour in seconds

    uint256 constant CONTRIBUTION = 10e18; // 10 UPD
    uint256 constant CONTRIBUTION_FEE = 10_000; // 1%

    uint256 constant TRANSFER_AMT = 100e18;
    uint256 constant CONTRIBUTION_AMT = 10e18;

    function setUp() public {
        owner = address(this);
        alice = address(1);
        bob = address(2);
        _upd = new UPDToken();
        
        _updraft = new Updraft(
            _upd,
            ANTI_SPAM_FEE,
            PERCENT_FEE,
            CYCLE_LENGTH,
            ACCRUAL_RATE,
            faucet
        );

        // approve updraft to spend UDP
        _upd.approve(address(_updraft), 10000000e18); // TODO:

        // give alice and bob some UPD
        _upd.transfer(alice, TRANSFER_AMT);
        _upd.transfer(bob, TRANSFER_AMT);
    }

    // should distribute all contributor fees correctly and leave no tokens in the contract
    function testFeeDistribution() public {
        uint256 contributorFee = 100_000; // 10%
        uint256 initialContribution = 10e18; // 10 UPD

        vm.recordLogs();
        _updraft.createIdea(contributorFee, initialContribution, _makeIdeaData());
        Vm.Log[] memory logs = vm.getRecordedLogs();

        address ideaAddr = address(uint160(uint256(logs[0].topics[1])));
        Idea _thisIdea = Idea(ideaAddr);

        _upd.approve(ideaAddr, 1000e18);
        vm.prank(alice);
        _upd.approve(ideaAddr, TRANSFER_AMT);
        vm.prank(bob);
        _upd.approve(ideaAddr, TRANSFER_AMT);

        uint256 cycleLength = _thisIdea.cycleLength();
        uint256 percentScale = _thisIdea.percentScale();

        // get the token contract
        IERC20 token = _thisIdea.token();
        assertEq(address(token), address(_upd));

        console2.log('\n--- Creating test scenario ---');

        _logContractState("Initial state", _thisIdea, token);

        // Initial contribution was already made during contract creation
        console2.log("\nInitial contribution made during contract creation");
        uint256 firstContribution = initialContribution;
        uint256 firstContributionAfterFee = firstContribution - ANTI_SPAM_FEE;

        // Second wallet contributes in the first cycle
        uint256 secondContribution = 20e18;
        vm.prank(alice);
        _thisIdea.contribute(secondContribution);
        console2.log("\nSecond wallet contributed in first cycle");
        uint256 secondContributionAfterFee = secondContribution - ANTI_SPAM_FEE;
        _logContractState("After second wallet contribution in first cycle", _thisIdea, token);

        // Third wallet contributes in the first cycle
        uint256 thirdContribution = 30e18;
        vm.prank(bob);
        _thisIdea.contribute(thirdContribution);
        console2.log("\nThird wallet contributed in first cycle");
        uint256 thirdContributionAfterFee = thirdContribution - ANTI_SPAM_FEE;
        _logContractState("After third wallet contribution in first cycle", _thisIdea, token);

        // Advance time to the second cycle
        skip(cycleLength + 1);
        console2.log("\nAdvancing time to the second cycle");
        _logContractState("After advancing time to the second cycle", _thisIdea, token);

        // First wallet contributes in the second cycle
        uint256 firstContributionSecondCycle = 15e18;
        _thisIdea.contribute(firstContributionSecondCycle);
        console2.log("\nFirst wallet contributed in second cycle");
        uint256 firstContributionSecondCycleAfterFee = firstContributionSecondCycle - ANTI_SPAM_FEE;
        uint256 firstContributionSecondCycleContributorFee = firstContributionSecondCycleAfterFee * contributorFee / percentScale;
        _logContractState("After first wallet contribution in second cycle", _thisIdea, token);

        // Second wallet contributes in the second cycle
        uint256 secondContributionSecondCycle = 25e18;
        vm.prank(alice);
        _thisIdea.contribute(secondContributionSecondCycle);
        console2.log("\nSecond wallet contributed in second cycle");
        uint256 secondContributionSecondCycleAfterFee = secondContributionSecondCycle - ANTI_SPAM_FEE;
        uint256 secondContributionSecondCycleContributorFee = secondContributionSecondCycleAfterFee * contributorFee / percentScale;
        _logContractState("After second wallet contribution in second cycle", _thisIdea, token);

        // advance time to the third cycle
        skip(cycleLength + 1);
        console2.log("\nAdvancing time to the third cycle");
        _logContractState("After advancing time to the third cycle", _thisIdea, token);

        // Third wallet contributes in the third cycle
        uint256 thirdContributionThirdCycle = 35e18;
        vm.prank(bob);
        _thisIdea.contribute(thirdContributionThirdCycle);
        console2.log("\nThird wallet contributed in third cycle");
        uint256 thirdContributionThirdCycleAfterFee = thirdContributionThirdCycle - ANTI_SPAM_FEE;
        uint256 thirdContributionThirdCycleContributorFee = thirdContributionThirdCycleAfterFee * contributorFee / percentScale;
        _logContractState("After third wallet contribution in third cycle", _thisIdea, token);

        // Advance time to the fourth cycle to ensure all fees are distributed
        skip(cycleLength + 1);
        console2.log("\nAdvancing time to the fourth cycle");

        // Make a small contribution to update cycles
        uint256 finalContribution = 5e18;
        _thisIdea.contribute(finalContribution);
        console2.log("\nFirst wallet made small contribution in fourth cycle");
        uint256 finalContributionAfterFee = finalContribution - ANTI_SPAM_FEE;
        uint256 finalContributionContributorFee = finalContributionAfterFee * contributorFee / percentScale;
        _logContractState("After final contribution", _thisIdea, token);

        // Calculate total contributions and expected contributor fees
        uint256 totalContributions = firstContribution + secondContribution + thirdContribution + firstContributionSecondCycle + secondContributionSecondCycle + thirdContributionThirdCycle + finalContribution;
        uint256 totalAntiSpamFees = ANTI_SPAM_FEE * 7; // 7 contributions
        uint256 totalContributorFees = firstContributionSecondCycleContributorFee + secondContributionSecondCycleContributorFee + thirdContributionThirdCycleContributorFee + finalContributionContributorFee;
        uint256 expectedNetContributions = totalContributions - totalAntiSpamFees;

        console2.log("\n--- Contribution Summary ---");
        console2.log("Total contributions: %d", totalContributions);
        console2.log("Total anti-spam fees: %d", totalAntiSpamFees);
        console2.log("Total contributor fees: %d", totalContributorFees);
        console2.log("Expected net contributions: %d", expectedNetContributions);

        // Get contract balance before withdrawals
        uint256 balanceBeforeWithdrawals = token.balanceOf(address(_thisIdea));
        console2.log("\nContract balance before withdrawals: %d", balanceBeforeWithdrawals);

        console2.log("\n--- Withdrawing all positions ---");

        // First wallet positions
        console2.log("\nFirst wallet positions:");
        uint256 firstWalletPositions = _thisIdea.numPositions(owner);
        console2.log("First wallet has %d positions", firstWalletPositions);

        uint256 firstWalletWithdrawn = 0;
        for (uint256 i = 0; i < firstWalletPositions; i++) {
            uint256 balanceBefore = token.balanceOf(owner);
            _thisIdea.withdraw(i);
            uint256 balanceAfter = token.balanceOf(owner);
            uint256 withdrawn = balanceAfter - balanceBefore;
            firstWalletWithdrawn += withdrawn;
            console2.log("Successfully withdrew first wallet position %d: %d", i, withdrawn);
            _logContractState(string(abi.encodePacked("After first wallet position ", i, " withdrawal")), _thisIdea, token);
        }
        console2.log("Total withdrawn by first wallet: %d", firstWalletWithdrawn);

        // Second wallet positions
        console2.log("\nSecond wallet positions:");
        uint256 secondWalletPositions = _thisIdea.numPositions(alice);
        console2.log("Second wallet has %d positions", secondWalletPositions);

        uint256 secondWalletWithdrawn = 0;
        for (uint256 i = 0; i < secondWalletPositions; i++) {
            uint256 balanceBefore = token.balanceOf(alice);
            vm.prank(alice);
            _thisIdea.withdraw(i);
            uint256 balanceAfter = token.balanceOf(alice);
            uint256 withdrawn = balanceAfter - balanceBefore;
            secondWalletWithdrawn += withdrawn;
            console2.log("Successfully withdrew second wallet position %d: %d", i, withdrawn);
            _logContractState(string(abi.encodePacked("After second wallet position ", i, " withdrawal")), _thisIdea, token);
        }
        console2.log("Total withdrawn by second wallet: %d", secondWalletWithdrawn);

        // Third wallet positions
        console2.log("\nThird wallet positions:");
        uint256 thirdWalletPositions = _thisIdea.numPositions(bob);
        console2.log("Third wallet has %d positions", thirdWalletPositions);

        uint256 thirdWalletWithdrawn = 0;
        for (uint256 i = 0; i < thirdWalletPositions; i++) {
            uint256 balanceBefore = token.balanceOf(bob);
            vm.prank(bob);
            _thisIdea.withdraw(i);
            uint256 balanceAfter = token.balanceOf(bob);
            uint256 withdrawn = balanceAfter - balanceBefore;
            thirdWalletWithdrawn += withdrawn;
            console2.log("Successfully withdrew third wallet position %d: %d", i, withdrawn);
            _logContractState(string(abi.encodePacked("After third wallet position ", i, " withdrawal")), _thisIdea, token);
        }
        console2.log("Total withdrawn by third wallet: %d", thirdWalletWithdrawn);

        // Calculate the total contributions by each wallet (minus anti-spam fees)
        uint256 firstWalletContributions = firstContributionAfterFee + firstContributionSecondCycleAfterFee + finalContributionAfterFee;
        uint256 secondWalletContributions = secondContributionAfterFee + secondContributionSecondCycleAfterFee;
        uint256 thirdWalletContributions = thirdContributionAfterFee + thirdContributionThirdCycleAfterFee;

        console2.log("\nFirst wallet contributions: ", firstWalletContributions);
        console2.log("First wallet withdrawals: ", firstWalletWithdrawn);
        // console2.log("First wallet profit: ", firstWalletWithdrawn - firstWalletContributions); // TODO:

        console2.log("\nSecond wallet contributions: ", secondWalletContributions);
        console2.log("Second wallet withdrawals: ", secondWalletWithdrawn);
        // console2.log("Second wallet profit: ", secondWalletWithdrawn - secondWalletContributions); // TODO:

        console2.log("\nThird wallet contributions: ", thirdWalletContributions);
        console2.log("Third wallet withdrawals: ", thirdWalletWithdrawn);
        // console2.log("Third wallet profit: ", thirdWalletWithdrawn - thirdWalletContributions); // TODO:

        // Calculate total withdrawn
        uint256 totalWithdrawn = firstWalletWithdrawn + secondWalletWithdrawn + thirdWalletWithdrawn;
        console2.log("\nTotal withdrawn: ", totalWithdrawn);

        // Check the contract's final balance
        uint256 contractBalance = token.balanceOf(address(_thisIdea));
        console2.log("Contract final balance: ", contractBalance);

        // check the contract's internal token tracking
        uint256 contractTokens = _thisIdea.tokens();
        console2.log("Contract internal tokens tracking: ", contractTokens);

        // Check the contract's contributorFees
        uint256 finalContributorsFees = _thisIdea.contributorFees();
        console2.log("Contract final contributor fees: ", finalContributorsFees);

        // Verify that all tokens were withdrawn
        console2.log("\n--- Verification ---");
        console2.log("Expected net contributions: ", expectedNetContributions);
        console2.log("Total withdrawn: ", totalWithdrawn);
        console2.log("Difference: ", expectedNetContributions - totalWithdrawn);
        console2.log("Tokens left in contract: ", contractBalance);
        console2.log("contributorFees left: ", finalContributorsFees);

        // Assert that the contract balance is zero
        assertEq(contractBalance, 0, "Contract should have zero balance after all withdrawals");

        // Assert that the contract's internal token tracking is zero
        assertEq(contractTokens, 0, "Contract's internal token tracking should be zero after all withdrawals");

        // Assert that the contract's contributorFees is zero
        assertEq(finalContributorsFees, 0, "Contract's contributorFees should be zero after all withdrawals");

        // Assert that the total withdrawn equals the expected net contributions
        assertEq(totalWithdrawn, expectedNetContributions, "Total withdrawn should equal expected net contributions");
    }

    // PRIVATE HELPER FUNCTIONS
    function _logContractState(string memory _label, Idea _thisIdea, IERC20 _token) private {
        uint256 contractbalance = _token.balanceOf(address(_thisIdea));
        uint256 contractTokens = _thisIdea.tokens();
        uint256 contributorFees = _thisIdea.contributorFees();

        console2.log("\n--- %s ---", _label);
        console2.log("Contract balance: ", contractbalance);
        console2.log("Contract tokens:  ", contractTokens);
        console2.log("Contributor fees: ", contributorFees);

        // obtain the length of the cycles array via its storage slot
        // forge inspect Idea storage-layout --pretty
        uint256 slot = 2;
        uint256 cyclesArrayLength = uint256(vm.load(address(_thisIdea), bytes32(slot)));

        if(cyclesArrayLength > 0) {
            for(uint256 i = 0; i < cyclesArrayLength; i++) {
                (uint256 number, uint256 shares, uint256 fees, bool hasContributions) = _thisIdea.cycles(i);
                console2.log("Cycle %d: hasContributions=%s", i, hasContributions);
                console2.log("\t   number=%d, shares=%d, fees=%d", number, shares, fees);
            }
        }
    }
}

