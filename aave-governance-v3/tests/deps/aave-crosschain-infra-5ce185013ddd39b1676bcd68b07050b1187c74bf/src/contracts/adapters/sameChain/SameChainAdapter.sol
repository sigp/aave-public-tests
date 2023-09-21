// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {IBaseAdapter} from '../IBaseAdapter.sol';
import {IBaseReceiverPortal} from '../../interfaces/IBaseReceiverPortal.sol';

/**
 * @title SameChainAdapter
 * @author BGD Labs
 * @notice adapter that shortcutting the cross chain flow. As for same chain we can send the message directly
           to receiver without the need for bridging. Takes the chain Id directly from deployed chain to ensure
           that the message is forwarded to same chain
 */
contract SameChainAdapter is IBaseAdapter {
  /// @inheritdoc IBaseAdapter
  function forwardMessage(address, uint256, uint256, bytes memory message) external {
    (, address msgOrigin, address msgDestination, bytes memory decodedMessage) = abi.decode(
      message,
      (uint256, address, address, bytes)
    );
    IBaseReceiverPortal(msgDestination).receiveCrossChainMessage(
      msgOrigin,
      getChainID(),
      decodedMessage
    );
  }

  function getChainID() public view returns (uint256) {
    uint256 id;
    assembly {
      id := chainid()
    }
    return id;
  }
}
