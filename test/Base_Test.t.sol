// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;


import {Test, console2} from "forge-std/Test.sol";
import {Updraft} from "../src/Updraft.sol";
import {UPDToken} from "../src/UPDToken.sol";

contract Base_Test is Test {
    Updraft _updraft;
    UPDToken _upd;
    address owner;
    address alice;
    address bob;

    uint256 constant minFee = 1e18;
    uint256 constant percentFee = 10_000; // 1%
    uint256 constant accrualRate = 100_000; // 10%
    uint256 constant cycleLength = 12 * 60 * 60; // 12 hrs
    address faucet = 0x017F2A266a9833635aC4Ab6F242ed54087E54C50; // fund that collects and distributes a universal dividend: https://arbiscan.io/address/0x017F2A266a9833635aC4Ab6F242ed54087E54C50

    function setUp() public {
        owner = address(this);
        alice = address(1);
        bob = address(2);
        _upd = new UPDToken();
        
        _updraft = new Updraft(
            _upd,
            minFee,
            percentFee,
            accrualRate,
            cycleLength,
            faucet
        );
    }
    
    function testApproval() public {
        _upd.approve(address(_updraft), 1e18);
        assertTrue(_upd.allowance(owner, address(_updraft)) > 0);
        assertFalse(_upd.allowance(owner, address(_updraft)) > 1e18);
    }
}