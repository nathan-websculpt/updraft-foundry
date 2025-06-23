// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./Base_Test.t.sol";

contract Idea_Test is Base_Test {

    function testUserCanContributeToIdea() public {
        (Vm.Log[] memory logs, Idea _thisIdea, bytes memory ideaBytesData) = _createIdea();
        (uint256 tokens, uint256 expectedAmt) = _basicContribution(_thisIdea);
        assertEq(tokens, expectedAmt);
    }

    // should correctly handle contributor fees in cycles after the first
    function testHandlesContributorFeesInCyclesAfterTheFirst() public {
        (Vm.Log[] memory logs, Idea _thisIdea, bytes memory ideaBytesData) = _createIdea();

        uint256 contributorFee = _thisIdea.contributorFee();
        uint256 percentScale = _thisIdea.percentScale();
        uint256 percentFee = _thisIdea.percentFee();
        uint256 cycleLength = _thisIdea.cycleLength();

        vm.warp(cycleLength + 1);

        // Second wallet contributes in the second cycle
        vm.startPrank(alice);
        _upd.approve(address(_thisIdea), TRANSFER_AMT);
        _thisIdea.contribute(CONTRIBUTION_AMT);
        vm.stopPrank();


        (uint256 tokens, ) = _thisIdea.checkPosition(alice, 0);
        uint256 fee = max(ANTI_SPAM_FEE, (CONTRIBUTION_AMT * percentFee) / percentScale);
        uint256 expectedContributorFee = (CONTRIBUTION_AMT - ANTI_SPAM_FEE) * contributorFee / percentScale;
        uint256 expectedAmount = CONTRIBUTION_AMT - ANTI_SPAM_FEE - expectedContributorFee;

        assertEq(tokens, expectedAmount);
    }

    // describe('First Cycle Behavior', () => {
    //     it('should not collect contributor fees in the first cycle',

    function testDoesNotCollectContributorFeesInFirstCycle() public {
        (Vm.Log[] memory logs, Idea _thisIdea, bytes memory ideaBytesData) = _createIdea();
        (uint256 tokens, uint256 expectedAmt) = _basicContribution(_thisIdea);
        assertEq(tokens, expectedAmt);

        (uint256 number, uint256 shares, uint256 fees, bool hasContributions) = _thisIdea.cycles(0);
        assertEq(fees, 0); // fees should be 0
    }


    // PRIVATE HELPER FUNCTIONS
    function _basicContribution(Idea _thisIdea) private returns (uint256, uint256) {
        // Approve the idea contract to spend tokens
        vm.startPrank(alice);
        _upd.approve(address(_thisIdea), TRANSFER_AMT);
        _thisIdea.contribute(CONTRIBUTION_AMT);
        vm.stopPrank();

        // check that position was created successfully
        (uint256 tokens, ) = _thisIdea.checkPosition(alice);
        uint256 expectedAmt = _getExpectedAmt();
        return (tokens, expectedAmt);
    }

    function _getExpectedAmt() private returns (uint256) {
        uint256 fee = max(ANTI_SPAM_FEE, (CONTRIBUTION_AMT * 10_000) / 1_000_000);
        uint256 expectedAmt = CONTRIBUTION_AMT - fee;
        return expectedAmt;
    }
}
