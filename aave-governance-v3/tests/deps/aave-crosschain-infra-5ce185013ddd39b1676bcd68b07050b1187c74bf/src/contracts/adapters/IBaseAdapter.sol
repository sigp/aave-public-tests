// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IBaseAdapter
 * @author BGD Labs
 * @notice interface containing the event and method used in all bridge adapters
 */
interface IBaseAdapter {
  /**
   * @notice method that will bridge the payload to the chain specified
   * @param receiver address of the receiver contract on destination chain
   * @param gasLimit amount of the gas limit in wei to use for bridging on receiver side. Each adapter will manage this
            as needed
   * @param destinationChainId id of the destination chain in the bridge notation
   * @param message to send to the specified chain
   */
  function forwardMessage(
    address receiver, // TODO: this should be renamed as is the bridge adapter on receiving side
    uint256 gasLimit,
    uint256 destinationChainId,
    bytes memory message
  ) external;
}
