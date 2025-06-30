// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console2, Vm} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Updraft} from "../../src/Updraft.sol";
import {Idea} from "../../src/Idea.sol";
import {Solution} from "../../src/Solution.sol";
import {UPDToken} from "../../src/UPDToken.sol";
import {Utils} from "../lib/Utils.sol";

abstract contract Solution_Base is Test, Utils {
    
    Updraft _updraft;
    UPDToken _upd;

    address owner;
    address alice;
    address bob;
    address james;
    address kirk;
    address faucet = 0xdC0046B52e2E38AEe2271B6171ebb65cCD337518; // fund that collects and distributes a universal dividend

    uint256 constant ANTI_SPAM_FEE = 1e18; // 1 UPD
    uint256 constant PERCENT_FEE = 10_000; // 1%
    uint256 constant ACCRUAL_RATE = 100_000; // 10%
    uint256 constant CYCLE_LENGTH = 3600; // 1 hour in seconds

    uint256 constant CONTRIBUTION = 10e18; // 10 UPD
    uint256 constant CONTRIBUTION_FEE = 100_000; // 1%

    uint256 constant SOLUTION_STAKE = 100e18;
    uint256 constant SOLUTION_GOAL = 10_000e18;
    uint256 constant SOLUTION_DEADLINE = 7 * 24 * 60 * 60; // 7 days

    uint256 constant TRANSFER_AMT = 100e18;
    uint256 constant CONTRIBUTION_AMT = 10e18;

    function setUp() public {
        owner = address(this);
        alice = address(1);
        bob = address(2);
        james = address(3);
        kirk = address(4);
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
        _upd.approve(address(_updraft), 10000000e18);

        // give alice and bob some UPD
        _upd.transfer(alice, TRANSFER_AMT);
        _upd.transfer(bob, TRANSFER_AMT);
    }

    function _createIdea() internal returns (Vm.Log[] memory, Idea, bytes memory) {
        bytes memory ideaBytesData = _makeIdeaData();
        vm.recordLogs();

        _updraft.createIdea(CONTRIBUTION_FEE, CONTRIBUTION, ideaBytesData);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        address ideaAddr = address(uint160(uint256(logs[0].topics[1])));
        return (logs, Idea(ideaAddr), ideaBytesData);
    }

    function _createSolution(address _ideaAddr) internal returns (Vm.Log[] memory, Solution, bytes memory) {
        bytes memory solutionBytesData = _makeSolutionData();
        vm.recordLogs();

        _updraft.createSolution(_ideaAddr, _upd, SOLUTION_STAKE, SOLUTION_GOAL, SOLUTION_DEADLINE, CONTRIBUTION_FEE, solutionBytesData);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        address solutionAddr = address(uint160(uint256(logs[1].topics[1])));
        return (logs, Solution(solutionAddr), solutionBytesData);
    }
}