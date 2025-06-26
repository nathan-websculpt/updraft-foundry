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
    
    function _max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    function _formatUnits(uint256 value) internal pure returns (string memory) {
        uint256 integer = value / 1e18;
        uint256 fractional = value % 1e18;
        if(fractional > 0)
            return string(abi.encodePacked(_uintToString(integer), ".", _fractionalToString(fractional, 18)));
        else
            return string(abi.encodePacked(_uintToString(integer)));
    }

    function _uintToString(uint256 v) private pure returns (string memory str) {
        if (v == 0) return "0";
        uint256 maxlength = 78;
        bytes memory reversed = new bytes(maxlength);
        uint256 i = 0;
        while (v != 0) {
            uint256 remainder = v % 10;
            v = v / 10;
            reversed[i++] = bytes1(uint8(48 + remainder));
        }
        bytes memory s = new bytes(i);
        for (uint256 j = 0; j < i; j++) {
            s[j] = reversed[i - j - 1];
        }
        str = string(s);
    }

    function _fractionalToString(uint256 v, uint256 decimals) private pure returns (string memory str) {
        bytes memory s = new bytes(decimals);
        for (uint256 i = decimals; i > 0; --i) {
            s[i - 1] = bytes1(uint8(48 + v % 10));
            v /= 10;
        }
        str = string(s);
    }
}