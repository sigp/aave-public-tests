// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.12;

contract ForceDonate {
    function boom(address payable recipient) public {
        selfdestruct(recipient);
    }

    fallback() external payable {}
}
