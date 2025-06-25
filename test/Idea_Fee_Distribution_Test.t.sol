// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console2, Vm} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Updraft} from "../src/Updraft.sol";
import {Idea} from "../src/Idea.sol";
import {UPDToken} from "../src/UPDToken.sol";
import {Utils} from "./lib/Utils.sol";

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

    uint256 constant SOLUTION_STAKE = 100e18;
    uint256 constant SOLUTION_GOAL = 10_000e18;
    uint256 constant SOLUTION_DEADLINE = 3940876877;

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
        // address tokenAddress = _thisIdea.token();
        // IERC20 token = IERC20(tokenAddress);

        console2.log('\n--- Creating test scenario ---');

        _logContractState("Initial state", _thisIdea);

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
        _logContractState("After second wallet contribution in first cycle", _thisIdea);

        // Third wallet contributes in the second cycle
        uint256 thirdContribution = 30e18;
        vm.prank(bob);
        _thisIdea.contribute(thirdContribution);
        console2.log("\nThird wallet contributed in first cycle");
        uint256 thirdContributionAfterFee = thirdContribution - ANTI_SPAM_FEE;
        _logContractState("After third wallet contribution in second cycle", _thisIdea);

        // Advance time to the second cycle
        skip(cycleLength + 1);
        console2.log("\nAdvancing time to the second cycle");
        _logContractState("After advancing time to the second cycle", _thisIdea);

        // First wallet contributes in the second cycle
        uint256 firstContributionSecondCycle = 15e18;
        _thisIdea.contribute(firstContributionSecondCycle);
        console2.log("\nFirst wallet contributed in second cycle");
        uint256 firstContributionSecondCycleAfterFee = firstContributionSecondCycle - ANTI_SPAM_FEE;
        uint256 firstContributionSecondCycleContributorFee = firstContributionSecondCycleAfterFee * contributorFee / percentScale;
        _logContractState("After first wallet contribution in second cycle", _thisIdea);

        // Second wallet contributes in the second cycle
        uint256 secondContributionSecondCycle = 25e18;
        _thisIdea.contribute(secondContributionSecondCycle);
        console2.log("\nSecond wallet contributed in second cycle");
        uint256 secondContributionSecondCycleAfterFee = secondContributionSecondCycle - ANTI_SPAM_FEE;
        uint256 secondContributionSecondCycleContributorFee = secondContributionSecondCycleAfterFee * contributorFee / percentScale;
        _logContractState("After second wallet contribution in second cycle", _thisIdea);

        // advance time to the third cycle
        skip(cycleLength + 1);
        console2.log("\nAdvancing time to the third cycle");
        _logContractState("After advancing time to the third cycle", _thisIdea);

        // Third wallet contributes in the third cycle
        uint256 thirdContributionThirdCycle = 35e18;
        _thisIdea.contribute(thirdContributionThirdCycle);
        console2.log("\nThird wallet contributed in third cycle");
        uint256 thirdContributionThirdCycleAfterFee = thirdContributionThirdCycle - ANTI_SPAM_FEE;
        uint256 thirdContributionThirdCycleContributorFee = thirdContributionThirdCycleAfterFee * contributorFee / percentScale;
        _logContractState("After third wallet contribution in third cycle", _thisIdea);

        // Advance time to the fourth cycle to ensure all fees are distributed
        skip(cycleLength + 1);
        console2.log("\nAdvancing time to the fourth cycle");

        // Make a small contribution to update cycles
    }

    // PRIVATE HELPER FUNCTIONS
    // function _logContractState(string memory _label, IERC20 _token, Idea _thisIdea) private {
    function _logContractState(string memory _label, Idea _thisIdea) private {
        // uint256 contractbalance = _token.balanceOf(address(_thisIdea));
        uint256 contractTokens = _thisIdea.tokens();
        uint256 contributorFees = _thisIdea.contributorFees();

        console2.log("\n--- %s ---", _label);
        // console2.log("Contract balance: ", contractbalance);
        console2.log("Contract tokens: ", contractTokens);
        console2.log("Contributor fees: ", contributorFees);

        // obtain the length of the cycles array via its storage slot
        // forge inspect Idea storage-layout --pretty
        uint256 slot = 2;
        uint256 cyclesArrayLength = uint256(vm.load(address(_thisIdea), bytes32(slot)));
        console2.log("Cycles array length: ", cyclesArrayLength);

        if(cyclesArrayLength > 0) {
            for(uint256 i = 0; i < cyclesArrayLength; i++) {
                (uint256 number, uint256 shares, uint256 fees, bool hasContributions) = _thisIdea.cycles(i);
                console2.log("Cycle %d: hasContributions=%s", i, hasContributions);
                console2.log("\t   number=%d, shares=%d, fees=%d", number, shares, fees);
            }
        }
    }
}

