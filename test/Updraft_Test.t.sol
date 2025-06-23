// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./Base_Test.t.sol";

contract Updraft_Test is Base_Test {    
    
    function testUpdraftApprovedToSpendUPD() public view {
        assertEq(_upd.allowance(owner, address(_updraft)), 10000000e18);
    }

    function testCreateProfile() public {
        bytes memory profileBytesData = _makeProfileData();

        vm.expectEmit();
        emit IERC20.Transfer(owner, faucet, 1e18);

        vm.expectEmit();
        emit Updraft.ProfileUpdated(owner, profileBytesData);

        _updraft.updateProfile(profileBytesData);
    }

    function testDeployIdea() public {   
        (Vm.Log[] memory logs, Idea _thisIdea, bytes memory ideaBytesData) = _createIdea();

        ( 
            uint256 contributionFee,
            uint256 contribution,
            bytes memory data
        ) = abi.decode(logs[0].data, (uint256, uint256, bytes));

        assertEq(contributionFee, CONTRIBUTION_FEE);
        assertEq(contribution, CONTRIBUTION);
        assertEq(data, ideaBytesData);

        // should give the caller a position in the Idea
        assertEq(_thisIdea.numPositions(owner), 1);
    }

    function testCallerPositionEqualContributionMinusAntiSpam() public {
        (, Idea _thisIdea, ) = _createIdea();
        (uint256 tokens, ) = _thisIdea.checkPosition(owner);
        assertEq(tokens, CONTRIBUTION - ANTI_SPAM_FEE);
    }       

    function testDeploySolution() public {
        (, Idea _thisIdea, ) = _createIdea();
        (Vm.Log[] memory logs, Solution _thisSolution, bytes memory solutionBytesData) = _createSolution(address(_thisIdea));

        (
            address fundingToken,
            uint256 stake,
            uint256 goal,
            uint256 deadline,
            uint256 contributionFee,
            bytes memory data
        ) = abi.decode(logs[1].data, (address, uint256, uint256, uint256, uint256, bytes));

        assertEq(fundingToken, address(_upd));
        assertEq(stake, SOLUTION_STAKE);
        assertEq(goal, SOLUTION_GOAL);
        assertEq(deadline, SOLUTION_DEADLINE);
        assertEq(contributionFee, CONTRIBUTION_FEE);
        assertEq(data, solutionBytesData);
    }

    // Creating a Solution to the Idea with a positive stake
    function testResultsInPositiveStakeForCaller() public {
        (, Idea _thisIdea, ) = _createIdea();
        (Vm.Log[] memory logs, Solution _thisSolution, bytes memory solutionBytesData) = _createSolution(address(_thisIdea));

        uint256 ownerStake = _thisSolution.stakes(owner);

        assertEq(ownerStake, SOLUTION_STAKE);
    }
}
