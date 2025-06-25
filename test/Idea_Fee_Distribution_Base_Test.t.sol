// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console2, Vm} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Updraft} from "../src/Updraft.sol";
import {Idea} from "../src/Idea.sol";
import {UPDToken} from "../src/UPDToken.sol";
import {Utils} from "./lib/Utils.sol";

abstract contract Idea_Fee_Distribution_Base_Test is Test, Utils {
    
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
    uint256 constant CONTRIBUTION_FEE = 10_000; // 1%

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
        _upd.approve(address(_updraft), 10000000e18); // TODO:

        // give alice and bob some UPD
        _upd.transfer(alice, TRANSFER_AMT);
        _upd.transfer(bob, TRANSFER_AMT);
    }
}