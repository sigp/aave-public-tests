// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';
import {SafeERC20} from 'solidity-utils/contracts/oz-common/SafeERC20.sol';
import {Initializable} from 'solidity-utils/contracts/transparent-proxy/Initializable.sol';
import {OwnableWithGuardian} from 'solidity-utils/contracts/access-control/OwnableWithGuardian.sol';
import {EmergencyConsumer, IEmergencyConsumer} from 'solidity-utils/contracts/emergency/EmergencyConsumer.sol';
import {ICrossChainController} from './interfaces/ICrossChainController.sol';
import {CrossChainReceiver} from './CrossChainReceiver.sol';
import {CrossChainForwarder} from './CrossChainForwarder.sol';
import {Errors} from './libs/Errors.sol';

/**
 * @title CrossChainController
 * @author BGD Labs
 * @notice Contract with the logic to manage sending and receiving messages cross chain.
 * @dev This contract is enabled to receive gas tokens as its the one responsible for bridge services payment.
        It should always be topped up, or no messages will be sent to other chains
 * @dev If an emergency is activated, solveEmergency method should be called with new configurations.
 */
contract CrossChainController is
  ICrossChainController,
  CrossChainForwarder,
  CrossChainReceiver,
  EmergencyConsumer,
  Initializable
{
  using SafeERC20 for IERC20;

  /**
   * @param clEmergencyOracle chainlink emergency oracle address
   * @param initialRequiredConfirmations number of confirmations the messages need to be accepted as valid
   * @param receiverBridgeAdaptersToAllow array of addresses of the bridge adapters that can receive messages
   * @param forwarderBridgeAdaptersToEnable array specifying for every bridgeAdapter, the destinations it can have
   * @param sendersToApprove array of addresses to allow as forwarders
   */
  constructor(
    address clEmergencyOracle,
    uint256 initialRequiredConfirmations,
    address[] memory receiverBridgeAdaptersToAllow,
    BridgeAdapterConfigInput[] memory forwarderBridgeAdaptersToEnable,
    address[] memory sendersToApprove
  )
    CrossChainReceiver(initialRequiredConfirmations, receiverBridgeAdaptersToAllow)
    CrossChainForwarder(forwarderBridgeAdaptersToEnable, sendersToApprove)
    EmergencyConsumer(clEmergencyOracle)
  {}

  /// @inheritdoc ICrossChainController
  function initialize(
    address owner,
    address guardian,
    address clEmergencyOracle,
    uint256 initialRequiredConfirmations,
    address[] memory receiverBridgeAdaptersToAllow,
    BridgeAdapterConfigInput[] memory forwarderBridgeAdaptersToEnable,
    address[] memory sendersToApprove
  ) external initializer {
    _transferOwnership(owner);
    _updateGuardian(guardian);
    _updateCLEmergencyOracle(clEmergencyOracle);

    _updateConfirmations(initialRequiredConfirmations);
    _updateReceiverBridgeAdapters(receiverBridgeAdaptersToAllow, true);

    _enableBridgeAdapters(forwarderBridgeAdaptersToEnable);
    _updateSenders(sendersToApprove, true);
  }

  /// @inheritdoc ICrossChainController
  function solveEmergency(
    uint256 newConfirmations,
    uint120 newValidityTimestamp,
    address[] memory receiverBridgeAdaptersToAllow,
    address[] memory receiverBridgeAdaptersToDisallow,
    address[] memory sendersToApprove,
    address[] memory sendersToRemove,
    BridgeAdapterConfigInput[] memory forwarderBridgeAdaptersToEnable,
    BridgeAdapterToDisable[] memory forwarderBridgeAdaptersToDisable
  ) external onlyGuardian onlyInEmergency {
    // receiver side
    _updateReceiverBridgeAdapters(receiverBridgeAdaptersToAllow, true);
    _updateReceiverBridgeAdapters(receiverBridgeAdaptersToDisallow, false);
    _updateConfirmations(newConfirmations);
    _updateMessagesValidityTimestamp(newValidityTimestamp);

    // forwarder side
    _updateSenders(sendersToApprove, true);
    _updateSenders(sendersToRemove, false);
    _enableBridgeAdapters(forwarderBridgeAdaptersToEnable);
    _disableBridgeAdapters(forwarderBridgeAdaptersToDisable);
  }

  /// @inheritdoc ICrossChainController
  function emergencyTokenTransfer(
    address erc20Token,
    address to,
    uint256 amount
  ) external onlyOwner {
    IERC20(erc20Token).safeTransfer(to, amount);
  }

  /// @inheritdoc ICrossChainController
  function emergencyEtherTransfer(address to, uint256 amount) external onlyOwner {
    _safeTransferETH(to, amount);
  }

  /// @notice enable contract to receive eth
  receive() external payable {}

  /**
   * @notice transfer ETH to an address, revert if it fails.
   * @param to recipient of the transfer
   * @param value the amount to send
   */
  function _safeTransferETH(address to, uint256 value) internal {
    (bool success, ) = to.call{value: value}(new bytes(0));
    require(success, Errors.ETH_TRANSFER_FAILED);
  }

  /// @notice method that ensures access control validation
  function _validateEmergencyAdmin() internal override onlyOwner {}
}
