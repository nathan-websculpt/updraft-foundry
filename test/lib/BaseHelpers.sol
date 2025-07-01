// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Vm} from "forge-std/Vm.sol";
import {Idea} from "../../src/Idea.sol";
import {Solution} from "../../src/Solution.sol";
import {Updraft} from "../../src/Updraft.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract BaseHelpers {
    // instead of having to pass vm as a parameter
    Vm constant _vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function createIdea(Updraft _updraft, uint256 contributionFee, uint256 contribution, bytes memory ideaData)
        internal
        returns (Vm.Log[] memory, Idea, bytes memory)
    {
        _vm.recordLogs();
        _updraft.createIdea(contributionFee, contribution, ideaData);
        Vm.Log[] memory logs = _vm.getRecordedLogs();
        address ideaAddr = address(uint160(uint256(logs[0].topics[1])));
        return (logs, Idea(ideaAddr), ideaData);
    }

    function createSolution(
        Updraft _updraft,
        IERC20 _upd,
        address ideaAddr,
        uint256 stake,
        uint256 goal,
        uint256 deadline,
        uint256 contributionFee,
        bytes memory solutionData
    ) internal returns (Vm.Log[] memory, Solution, bytes memory) {
        _vm.recordLogs();
        _updraft.createSolution(ideaAddr, _upd, stake, goal, deadline, contributionFee, solutionData);
        Vm.Log[] memory logs = _vm.getRecordedLogs();
        address solutionAddr = address(uint160(uint256(logs[1].topics[1])));
        return (logs, Solution(solutionAddr), solutionData);
    }
}
