// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

// Inherit from this contract to get an empty fallback function
import "./Empty.sol";

contract MockCrossChainController is Empty {

    uint256 public l1ChainId;
    address public l1VotingPortal;
    uint256 public l2GasLimit;
    bytes public data;
    address public sender;

    function forwardMessage(
        uint256 _l1ChainId,
        address _l1VotingPortal,
        uint256 _l2GasLimit,
        bytes memory _data
    ) external {
        l1ChainId = _l1ChainId;
        l1VotingPortal = _l1VotingPortal;
        l2GasLimit = _l2GasLimit;
        data = _data;
        sender = msg.sender;
    }


}
