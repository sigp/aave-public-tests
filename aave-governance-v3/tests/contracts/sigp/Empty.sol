// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

// Basic placeholder contract

contract Empty {
    // Okay, so it's not strictly empty, but it's close enough.
    bool public confirmExistence = true;
    // empty fallback function to avoid reverting
    fallback() external payable {}

}
