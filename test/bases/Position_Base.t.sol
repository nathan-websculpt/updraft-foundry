// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console2, Vm} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Updraft} from "../../src/Updraft.sol";
import {Idea} from "../../src/Idea.sol";
import {Solution} from "../../src/Solution.sol";
import {UPDToken} from "../../src/UPDToken.sol";
import {BaseHelpers} from "../lib/BaseHelpers.sol";
import {Utils} from "../lib/Utils.sol";

// TODO: discuss with team
// not DRY, similar to Solution_Base_Test
// leaving these base tests alone to allow for more tests and flexibility later
abstract contract Position_Base is Test, Utils, BaseHelpers {
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

    uint256 constant CONTRIBUTION = 20e18; // 10 UPD
    uint256 constant CONTRIBUTION_FEE = 100_000; // 1%

    uint256 constant SOLUTION_STAKE = 100e18;
    uint256 constant SOLUTION_GOAL = 10_000e18;
    uint256 constant SOLUTION_DEADLINE = 24 * 60 * 60; // 1 day (86400)

    uint256 constant TRANSFER_AMT = 100e18;
    uint256 constant CONTRIBUTION_AMT = 10e18;

    function setUp() public {
        owner = address(this);
        alice = address(1);
        _upd = new UPDToken();

        _updraft = new Updraft(_upd, ANTI_SPAM_FEE, PERCENT_FEE, CYCLE_LENGTH, ACCRUAL_RATE, faucet);

        // approve updraft to spend UDP
        _upd.approve(address(_updraft), 10000000e18);

        // give alice some UPD
        _upd.transfer(alice, TRANSFER_AMT);
    }

    function _contributionAtAddress(address who, uint256 index, Solution _thisSolution)
        internal
        view
        returns (uint256)
    {
        (uint256 contribution,,,,) = _thisSolution.positionsByAddress(who, index);
        return contribution;
    }

    function _setup() internal returns (Solution) {
        (Idea _thisIdea, ,) = _createIdea();
        (Solution _thisSolution, ,) = BaseHelpers.createSolution(
            _updraft,
            _upd,
            address(_thisIdea),
            SOLUTION_STAKE,
            SOLUTION_GOAL,
            SOLUTION_DEADLINE,
            CONTRIBUTION_FEE,
            _makeSolutionData()
        );

        _upd.approve(address(_thisSolution), TRANSFER_AMT);

        vm.prank(alice);
        _upd.approve(address(_thisSolution), TRANSFER_AMT);

        return _thisSolution;
    }

    function _createIdea() internal returns (Idea, Vm.Log[] memory, bytes memory) {
        return BaseHelpers.createIdea(_updraft, CONTRIBUTION_FEE, CONTRIBUTION, _makeIdeaData());
    }
}
