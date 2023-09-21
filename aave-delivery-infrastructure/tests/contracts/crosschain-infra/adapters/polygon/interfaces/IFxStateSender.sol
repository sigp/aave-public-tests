// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IFxStateSender
 * @notice Defines the interface to process message
 */
interface IFxStateSender {
  /**
   * @notice Send bytes message to Child Tunnel
   * @param _receiver address that will be called with the message by child
   * @param _data bytes message that will be sent to Child Tunnel
   * @custom:security non-reentrant
   */
  function sendMessageToChild(address _receiver, bytes calldata _data) external;
}
