// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./data/Structs.sol";

contract Utils {
    
    function _makeProfileData() internal pure returns(bytes memory) {
        return abi.encode(ProfileData("Adam, Victor, Bastin, Beigi, Amirerfan", "Creators of Updraft"));
    }

    function _makeIdeaData() internal pure returns(bytes memory) {
        return abi.encode(CommonData("Idea Test One", "Description for Test One"));
    }

    function _makeSolutionData() internal pure returns(bytes memory) {
        return abi.encode(CommonData("Solution for Test One", "Description for Solution One"));
    }
}