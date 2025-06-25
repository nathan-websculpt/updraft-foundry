// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./Idea_Fee_Distribution_Base_Test.t.sol";

// forge test --mt testFeeDistributionRealistic -vv

contract Idea_Fee_Distribution_Realistic_Test is Idea_Fee_Distribution_Base_Test {

    Idea _thisIdea;

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