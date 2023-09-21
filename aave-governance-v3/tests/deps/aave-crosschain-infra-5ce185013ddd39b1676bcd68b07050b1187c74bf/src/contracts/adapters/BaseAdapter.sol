// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {IBaseAdapter} from './IBaseAdapter.sol';
import {ICrossChainController} from '../interfaces/ICrossChainController.sol';

/**
 * @title BaseAdapter
 * @author BGD Labs
 * @notice base contract implementing the method to route a bridged message to the CrossChainController contract.
 * @dev All bridge adapters must implement this contract
 */
abstract contract BaseAdapter is IBaseAdapter {
  ICrossChainController public immutable CROSS_CHAIN_CONTROLLER;

  /**
   * @param crossChainController address of the CrossChainController the bridged messages will be routed to
   */
  constructor(address crossChainController) {
    CROSS_CHAIN_CONTROLLER = ICrossChainController(crossChainController);
  }

  /**
   * @notice calls CrossChainController to register the bridged payload
   * @param _payload bytes containing the bridged message
   * @param originChainId id of the chain where the message originated
   */
  function _registerReceivedMessage(bytes memory _payload, uint256 originChainId) internal {
    CROSS_CHAIN_CONTROLLER.receiveCrossChainMessage(_payload, originChainId);
  }
}
