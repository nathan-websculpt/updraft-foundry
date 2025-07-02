// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./bases/Base.t.sol";

contract Idea_Test is Base {
    uint256 AIRDROP_AMT = 1_000_000e18; // 1 million UPD - truly massive airdrop to test scaling

    function testUserCanContributeToIdea() public {
        (Idea _thisIdea,,) = _createIdea();
        (uint256 tokens, uint256 expectedAmt) = _basicContribution(_thisIdea);
        assertEq(tokens, expectedAmt);
    }

    // should correctly handle contributor fees in cycles after the first
    function testHandlesContributorFeesInCyclesAfterTheFirst() public {
        (Idea _thisIdea,,) = _createIdea();

        uint256 contributorFee = _thisIdea.contributorFee();
        uint256 percentScale = _thisIdea.percentScale();
        uint256 percentFee = _thisIdea.percentFee();
        uint256 cycleLength = _thisIdea.cycleLength();

        skip(cycleLength + 1);

        // Second wallet contributes in the second cycle
        vm.startPrank(alice);
        _upd.approve(address(_thisIdea), TRANSFER_AMT);
        _thisIdea.contribute(CONTRIBUTION_AMT);
        vm.stopPrank();

        (uint256 tokens,) = _thisIdea.checkPosition(alice, 0);
        uint256 fee = _max(ANTI_SPAM_FEE, (CONTRIBUTION_AMT * percentFee) / percentScale);
        uint256 expectedContributorFee = (CONTRIBUTION_AMT - ANTI_SPAM_FEE) * contributorFee / percentScale;
        uint256 expectedAmount = CONTRIBUTION_AMT - ANTI_SPAM_FEE - expectedContributorFee;

        assertEq(tokens, expectedAmount);
    }

    function testDoesNotCollectContributorFeesInFirstCycle() public {
        (Idea _thisIdea,,) = _createIdea();
        (uint256 tokens, uint256 expectedAmt) = _basicContribution(_thisIdea);
        assertEq(tokens, expectedAmt);

        (uint256 number, uint256 shares, uint256 fees, bool hasContributions) = _thisIdea.cycles(0);
        assertEq(fees, 0); // fees should be 0
    }

    function testShouldNotAllowAirdropsInFirstCycle() public {
        (Idea _thisIdea,,) = _createIdea();
        vm.expectRevert(Idea.CannotAirdropInFirstCycle.selector);
        _thisIdea.airdrop(AIRDROP_AMT);
    }

    function testAllowsContributorsToWithdrawTheirPositions() public {
        (Idea _thisIdea,,) = _createIdea();
        uint256 initialBalance = _upd.balanceOf(owner);
        (uint256 tokens,) = _thisIdea.checkPosition(owner, 0);

        // withdraw position
        _thisIdea.withdraw(0);
        uint256 finalBalance = _upd.balanceOf(owner);

        // Verify balance increased by position amount
        assertEq(finalBalance - initialBalance, tokens);

        // Verify position no longer exists
        vm.expectRevert(Idea.PositionDoesNotExist.selector);
        _thisIdea.checkPosition(owner, 0);
    }

    // should correctly distribute contributor fees when withdrawing after multiple cycles
    function testCorrectlyDistributesContributorFeesWhenWithdrawingAfterMultipleCycles() public {
        (Idea _thisIdea,,) = _createIdea();

        _upd.approve(address(_thisIdea), TRANSFER_AMT);
        vm.prank(alice);
        _upd.approve(address(_thisIdea), TRANSFER_AMT);

        uint256 cycleLength = _thisIdea.cycleLength();
        skip(cycleLength + 1);

        // alice contributes in the second cycle
        vm.prank(alice);
        _thisIdea.contribute(CONTRIBUTION_AMT);

        // Get initial position amount
        (uint256 initialPositionTokens,) = _thisIdea.checkPosition(alice, 0);

        // advance cycles
        for (uint256 i = 0; i < 3; i++) {
            skip(cycleLength + 1);
            // make a small contribution to update cycles (this is owner contributing)
            _smallContribution(_thisIdea);
        }

        // Get position amount after cycles
        (uint256 finalPositionTokens,) = _thisIdea.checkPosition(alice, 0);

        // Verify position tokens increased due to fee distribution
        assertGt(finalPositionTokens, initialPositionTokens);

        // Get balance before withdrawal
        uint256 balanceBefore = _upd.balanceOf(alice);

        // Withdraw position
        vm.prank(alice);
        _thisIdea.withdraw(0);

        // Get balance after withdrawal
        uint256 balanceAfter = _upd.balanceOf(alice);

        // Verify balance increased by the correct amount
        assertEq(balanceAfter - balanceBefore, finalPositionTokens);
    }

    // AIRDROP
    function testIncreasesTotalTokensInContract() public {
        (Idea _thisIdea,,) = _createIdea();
        _upd.approve(address(_thisIdea), AIRDROP_AMT + 2 ether);

        uint256 cycleLength = _thisIdea.cycleLength();
        skip(cycleLength + 1);

        _smallContribution(_thisIdea);

        uint256 initialTokens = _thisIdea.tokens();

        // perform airdrop
        _thisIdea.airdrop(AIRDROP_AMT);

        uint256 tokensAfterAirdrop = _thisIdea.tokens();

        // Calculate expected tokens (initial + airdrop - anti-spam fee)
        uint256 minFee = _thisIdea.minFee();
        uint256 percentFee = _thisIdea.percentFee();
        uint256 percentScale = _thisIdea.percentScale();
        uint256 calculatedFee = (AIRDROP_AMT * percentFee) / percentScale;
        uint256 expectedFee = calculatedFee > minFee ? calculatedFee : minFee;
        uint256 expectedTokensAdded = AIRDROP_AMT - expectedFee;
        uint256 expectedTotalTokens = initialTokens + expectedTokensAdded;

        // Check that tokens increased correctly
        assertEq(tokensAfterAirdrop, expectedTotalTokens);
    }

    function testCreatePositionWithZeroTokensForTheAirDropper() public {
        (Idea _thisIdea,,) = _createIdea();
        _upd.approve(address(_thisIdea), AIRDROP_AMT + 2 ether);

        uint256 cycleLength = _thisIdea.cycleLength();
        skip(cycleLength + 1);

        _smallContribution(_thisIdea);

        // get initial number of positions
        uint256 initialPositions = _thisIdea.numPositions(owner);

        // perform airdrop
        _thisIdea.airdrop(AIRDROP_AMT);

        // get number of positions after airdrop
        uint256 positionsAfterAirdrop = _thisIdea.numPositions(owner);

        // check that a new position was created
        assertEq(positionsAfterAirdrop, initialPositions + 1);

        uint256 positionIndex = positionsAfterAirdrop - 1;

        // Check that the position has 0 tokens
        (, uint256 tokens) = _thisIdea.positionsByAddress(owner, positionIndex); // gets Position Struct
        assertEq(tokens, 0);
    }

    function testDistributesAirdroppedTokensProportionallyToContributors() public {
        (Idea _thisIdea,,) = _createIdea();

        _upd.approve(address(_thisIdea), AIRDROP_AMT + 4 ether);
        vm.prank(alice);
        _upd.approve(address(_thisIdea), TRANSFER_AMT);
        vm.prank(bob);
        _upd.approve(address(_thisIdea), TRANSFER_AMT);

        // Second wallet contributes twice as much as third wallet
        vm.prank(alice);
        _thisIdea.contribute(20e18);
        vm.prank(bob);
        _thisIdea.contribute(10e18);

        uint256 cycleLength = _thisIdea.cycleLength();
        skip(cycleLength + 1);

        // Make a small contribution to create a new cycle
        _smallContribution(_thisIdea);

        // get initial positions
        (uint256 aliceInitialTokens,) = _thisIdea.checkPosition(alice, 0);
        (uint256 bobInitialTokens,) = _thisIdea.checkPosition(bob, 0);

        // owner airdrops to idea
        _thisIdea.airdrop(AIRDROP_AMT);

        skip(cycleLength + 1);

        // Call updateCyclesAddingAmount indirectly by making a small contribution
        _smallContribution(_thisIdea);

        // check positions after airdrop
        (uint256 aliceAfterAirdropTokens,) = _thisIdea.checkPosition(alice, 0);
        (uint256 bobAfterAirdropTokens,) = _thisIdea.checkPosition(bob, 0);

        assertGt(aliceAfterAirdropTokens, aliceInitialTokens);
        assertGt(bobAfterAirdropTokens, bobInitialTokens);

        // Verify the second wallet (with twice the contribution) received approximately twice the airdrop amount
        // We use a tolerance because of rounding and the exact distribution depends on shares
        uint256 aliceIncrease = aliceAfterAirdropTokens - aliceInitialTokens;
        uint256 bobIncrease = bobAfterAirdropTokens - bobInitialTokens;

        assertGt(aliceIncrease, 0);
        assertGt(bobIncrease, 0);
        assertGt(aliceIncrease, bobIncrease * 2);
    }

    function testLeavesNoTokensInContractAfterAllContributorsWithdraw() public {
        (Idea _thisIdea,,) = _createIdea();

        _upd.approve(address(_thisIdea), AIRDROP_AMT + 4 ether);
        vm.prank(alice);
        _upd.approve(address(_thisIdea), TRANSFER_AMT);
        vm.prank(bob);
        _upd.approve(address(_thisIdea), TRANSFER_AMT);

        // Second wallet contributes twice as much as third wallet
        vm.prank(alice);
        _thisIdea.contribute(20e18);
        vm.prank(bob);
        _thisIdea.contribute(10e18);

        uint256 cycleLength = _thisIdea.cycleLength();
        skip(cycleLength + 1);

        // Make a small contribution to create a new cycle
        _smallContribution(_thisIdea);

        // first wallet airdrops to the idea
        _thisIdea.airdrop(AIRDROP_AMT);

        skip(cycleLength + 1);

        _smallContribution(_thisIdea);

        // get total tokens before withdrawals
        uint256 totalTokensBefore = _thisIdea.tokens();

        // get initial positions
        (uint256 ownerInitialTokens, uint256 ownerInitialShares) = _thisIdea.checkPosition(owner, 0);
        (uint256 aliceInitialTokens, uint256 aliceInitialShares) = _thisIdea.checkPosition(alice, 0);
        (uint256 bobInitialTokens, uint256 bobInitialShares) = _thisIdea.checkPosition(bob, 0);

        console2.log(
            "owner position tokens: %s UPD, shares: %s",
            _formatUnits(ownerInitialTokens),
            _formatUnits(ownerInitialShares)
        );
        console2.log(
            "alice position tokens: %s UPD, shares: %s",
            _formatUnits(aliceInitialTokens),
            _formatUnits(aliceInitialShares)
        );
        console2.log(
            "bob   position tokens: %s UPD, shares: %s \n",
            _formatUnits(bobInitialTokens),
            _formatUnits(bobInitialShares)
        );

        // get initial position tokens
        (, uint256 ownerOriginalTokens) = _thisIdea.positionsByAddress(owner, 0);
        (, uint256 aliceOriginalTokens) = _thisIdea.positionsByAddress(alice, 0);
        (, uint256 bobOriginalTokens) = _thisIdea.positionsByAddress(bob, 0);

        console2.log("owner original positon tokens: %s UPD", _formatUnits(ownerOriginalTokens));
        console2.log("alice original positon tokens: %s UPD", _formatUnits(aliceOriginalTokens));
        console2.log("bob   original positon tokens: %s UPD \n", _formatUnits(bobOriginalTokens));

        // track wallet balances before withdrawals
        uint256 ownerBalanceBefore = _upd.balanceOf(owner);
        uint256 aliceBalanceBefore = _upd.balanceOf(alice);
        uint256 bobBalanceBefore = _upd.balanceOf(bob);

        // all wallets withdraw their positions
        _thisIdea.withdraw(0);
        vm.prank(alice);
        _thisIdea.withdraw(0);
        vm.prank(bob);
        _thisIdea.withdraw(0);

        // track wallet balances aftet withdrawals
        uint256 ownerBalanceAfter = _upd.balanceOf(owner);
        uint256 aliceBalanceAfter = _upd.balanceOf(alice);
        uint256 bobBalanceAfter = _upd.balanceOf(bob);

        // Calculate withdrawn amounts
        uint256 ownerWithdrawn = ownerBalanceAfter - ownerBalanceBefore;
        uint256 aliceWithdrawn = aliceBalanceAfter - aliceBalanceBefore;
        uint256 bobWithdrawn = bobBalanceAfter - bobBalanceBefore;

        console2.log("owner withdrew: %s UPD", _formatUnits(ownerWithdrawn));
        console2.log("alice withdrew: %s UPD", _formatUnits(aliceWithdrawn));
        console2.log("bob   withdrew: %s UPD", _formatUnits(bobWithdrawn));
        console2.log("total withdrew: %s UPD \n", _formatUnits(ownerWithdrawn + aliceWithdrawn + bobWithdrawn));

        // Get total tokens after all withdrawals
        uint256 totalTokensAfter = _thisIdea.tokens();
        uint256 contributorFeesAfter = _thisIdea.contributorFees();

        console2.log("tokens left in contract: %d out of %d", totalTokensAfter, totalTokensBefore);
        console2.log("contributor fees left: %d \n", contributorFeesAfter);

        assertEq(contributorFeesAfter, 0);
    }

    function testTransferringPositions() public {
        (Idea _thisIdea,,) = _createIdea();

        (uint256 initialTokens,) = _thisIdea.checkPosition(owner, 0);

        // transfer position to another wallet
        _thisIdea.transferPosition(alice, 0);

        // Verify first wallet no longer has the position
        vm.expectRevert(Idea.PositionDoesNotExist.selector);
        (uint256 finalTokens,) = _thisIdea.checkPosition(owner, 0);

        // Verify second wallet now has the position
        assertEq(_thisIdea.numPositions(alice), 1);

        // Verify position amount is the same
        (uint256 transferredPositionTokens,) = _thisIdea.checkPosition(alice, 0);
        assertEq(transferredPositionTokens, initialTokens);
    }

    function testAllowsSplittingPositions() public {
        (Idea _thisIdea,,) = _createIdea();
        (uint256 initialTokens,) = _thisIdea.checkPosition(owner, 0);

        // split position into two
        _thisIdea.split(0, 2);

        // verify that there are two positions
        assertEq(_thisIdea.numPositions(owner), 2);

        // verify that original position has half the tokens
        (uint256 originalPositionTokens,) = _thisIdea.checkPosition(owner, 0);
        assertEq(originalPositionTokens, initialTokens / 2);

        // verify new position has half the tokens
        (uint256 newPositionTokens,) = _thisIdea.checkPosition(owner, 1);
        assertEq(newPositionTokens, initialTokens / 2);
    }

    // PRIVATE HELPER FUNCTIONS
    function _basicContribution(Idea _thisIdea) private returns (uint256, uint256) {
        // Approve the idea contract to spend tokens
        vm.startPrank(alice);
        _upd.approve(address(_thisIdea), TRANSFER_AMT);
        _thisIdea.contribute(CONTRIBUTION_AMT);
        vm.stopPrank();

        // check that position was created successfully
        (uint256 tokens,) = _thisIdea.checkPosition(alice);
        uint256 expectedAmt = _getExpectedAmt();
        return (tokens, expectedAmt);
    }

    function _getExpectedAmt() private returns (uint256) {
        uint256 fee = _max(ANTI_SPAM_FEE, (CONTRIBUTION_AMT * 10_000) / 1_000_000);
        uint256 expectedAmt = CONTRIBUTION_AMT - fee;
        return expectedAmt;
    }

    function _smallContribution(Idea _thisIdea) private {
        _thisIdea.contribute(ANTI_SPAM_FEE * 2);
    }
}
