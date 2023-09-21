// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './ICrossChainForwarder.sol';
import './ICrossChainReceiver.sol';

/**
 * @title ICrossChainController
 * @author BGD Labs
 * @notice interface containing the objects, events and methods definitions of the CrossChainController contract
 */
interface ICrossChainController is ICrossChainForwarder, ICrossChainReceiver {
  /**
   * @notice method called to initialize the proxy
   * @param owner address of the owner of the cross chain controller
   * @param guardian address of the guardian of the cross chain controller
   * @param clEmergencyOracle address of the chainlink emergency oracle
   * @param initialRequiredConfirmations number of confirmations the messages need to be accepted as valid
   * @param receiverBridgeAdaptersToAllow array of addresses of the bridge adapters that can receive messages
   * @param forwarderBridgeAdaptersToEnable array specifying for every bridgeAdapter, the destinations it can have
   * @param sendersToApprove array of addresses to allow as forwarders
   */
  function initialize(
    address owner,
    address guardian,
    address clEmergencyOracle,
    uint256 initialRequiredConfirmations,
    address[] memory receiverBridgeAdaptersToAllow,
    BridgeAdapterConfigInput[] memory forwarderBridgeAdaptersToEnable,
    address[] memory sendersToApprove
  ) external;

  /**
   * @notice method called to rescue tokens sent erroneously to the contract. Only callable by owner
   * @param erc20Token address of the token to rescue
   * @param to address to send the tokens
   * @param amount of tokens to rescue
   */
  function emergencyTokenTransfer(address erc20Token, address to, uint256 amount) external;

  /**
   * @notice method called to rescue ether sent erroneously to the contract. Only callable by owner
   * @param to address to send the eth
   * @param amount of eth to rescue
   */
  function emergencyEtherTransfer(address to, uint256 amount) external;

  /**
  * @notice method to check if there is a new emergency state, indicated by chainlink emergency oracle.
         This method is callable by anyone as a new emergency will be determined by the oracle, and this way
         it will be easier / faster to enter into emergency.
  * @param newConfirmations number of confirmations necessary for a message to be routed to destination
  * @param newValidityTimestamp timestamp in seconds indicating the point to where not confirmed messages will be
  *        invalidated.
  * @param receiverBridgeAdaptersToAllow list of bridge adapter addresses to be allowed to receive messages
  * @param receiverBridgeAdaptersToDisallow list of bridge adapter addresses to be disallowed
  * @param sendersToApprove list of addresses to be approved as senders
  * @param sendersToRemove list of sender addresses to be removed
  * @param forwarderBridgeAdaptersToEnable list of bridge adapters to be enabled to send messages
  * @param forwarderBridgeAdaptersToDisable list of bridge adapters to be disabled
  */
  function solveEmergency(
    uint256 newConfirmations,
    uint120 newValidityTimestamp,
    address[] memory receiverBridgeAdaptersToAllow,
    address[] memory receiverBridgeAdaptersToDisallow,
    address[] memory sendersToApprove,
    address[] memory sendersToRemove,
    BridgeAdapterConfigInput[] memory forwarderBridgeAdaptersToEnable,
    BridgeAdapterToDisable[] memory forwarderBridgeAdaptersToDisable
  ) external;
}
