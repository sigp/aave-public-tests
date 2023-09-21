// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

// Basic placeholder contract

contract Empty {
    // a simple contract with a fallback function to avoid creating a mock for some contracts
    uint256[50] internal _gap;
    bool public toRevert;
    
    // in some case, we need the call to revert, so we set the `toRevert` variable to true
    function setToRevert() external {
        toRevert = true;
    }
     function setNotRevert() external {
        toRevert = false;
    }

    fallback() external payable {
        if (toRevert) {
            revert();}
        else {}
    }

    receive() external payable {}

}
