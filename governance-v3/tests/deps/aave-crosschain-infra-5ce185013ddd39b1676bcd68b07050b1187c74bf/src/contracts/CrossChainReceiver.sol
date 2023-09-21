// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {OwnableWithGuardian} from 'solidity-utils/contracts/access-control/OwnableWithGuardian.sol';
import {ICrossChainReceiver} from './interfaces/ICrossChainReceiver.sol';
import {IBaseReceiverPortal} from './interfaces/IBaseReceiverPortal.sol';
import {Errors} from './libs/Errors.sol';

/**
 * @title CrossChainReceiver
 * @author BGD Labs
 * @notice this contract contains the methods to get bridged messages and route them to their respective recipients.
 * @dev to route a message, this one needs to be bridged correctly n number of confirmations.
 * @dev if at some point, it is detected that some bridge has been hacked, there is a possibility to invalidate
 *      messages by calling updateMessagesValidityTimestamp
 */
contract CrossChainReceiver is OwnableWithGuardian, ICrossChainReceiver {
  // number of bridges that are needed to make a bridged message valid.
  // Depending on the deployment chain, this needs to change, to account for the existing number of bridges
  uint256 internal _requiredConfirmations;

  // all messages originated but not finally confirmed before this timestamp, are invalid
  uint120 internal _validityTimestamp;

  // stores hash(nonce + originChainId + origin + dest + message) => bridged message information and state
  mapping(bytes32 => InternalBridgedMessage) internal _internalReceivedMessages;

  // specifies if an address is allowed to forward messages
  mapping(address => bool) internal _allowedBridgeAdapters;

  // checks if caller is one of the approved bridge adapters
  modifier onlyApprovedBridges() {
    require(isReceiverBridgeAdapterAllowed(msg.sender), Errors.CALLER_NOT_APPROVED_BRIDGE);
    _;
  }

  /**
   * @param initialRequiredConfirmations number of confirmations the messages need to be accepted as valid
   * @param bridgeAdaptersToAllow array of addresses of the bridge adapters that can receive messages
   */
  constructor(uint256 initialRequiredConfirmations, address[] memory bridgeAdaptersToAllow) {
    _updateConfirmations(initialRequiredConfirmations);
    _updateReceiverBridgeAdapters(bridgeAdaptersToAllow, true);
  }

  /// @inheritdoc ICrossChainReceiver
  function getRequiredConfirmations() external view returns (uint256) {
    return _requiredConfirmations;
  }

  /// @inheritdoc ICrossChainReceiver
  function getValidityTimestamp() external view returns (uint120) {
    return _validityTimestamp;
  }

  /// @inheritdoc ICrossChainReceiver
  function isReceiverBridgeAdapterAllowed(address bridgeAdapter) public view returns (bool) {
    return _allowedBridgeAdapters[bridgeAdapter];
  }

  /// @inheritdoc ICrossChainReceiver
  function getInternalMessageState(
    bytes32 internalId
  ) external view returns (InternalBridgedMessageStateWithoutAdapters memory) {
    return
      InternalBridgedMessageStateWithoutAdapters({
        confirmations: _internalReceivedMessages[internalId].confirmations,
        firstBridgedAt: _internalReceivedMessages[internalId].firstBridgedAt,
        delivered: _internalReceivedMessages[internalId].delivered
      });
  }

  /// @inheritdoc ICrossChainReceiver
  function isInternalMessageReceivedByAdapter(
    bytes32 internalId,
    address bridgeAdapter
  ) external view returns (bool) {
    return _internalReceivedMessages[internalId].bridgedByAdapter[bridgeAdapter];
  }

  /// @inheritdoc ICrossChainReceiver
  function updateConfirmations(uint256 newConfirmations) external onlyOwner {
    _updateConfirmations(newConfirmations);
  }

  /// @inheritdoc ICrossChainReceiver
  function updateMessagesValidityTimestamp(uint120 newValidityTimestamp) external onlyOwner {
    _updateMessagesValidityTimestamp(newValidityTimestamp);
  }

  /// @inheritdoc ICrossChainReceiver
  function allowReceiverBridgeAdapters(address[] memory bridgeAdapters) external onlyOwner {
    _updateReceiverBridgeAdapters(bridgeAdapters, true);
  }

  /// @inheritdoc ICrossChainReceiver
  function disallowReceiverBridgeAdapters(address[] memory bridgeAdapters) external onlyOwner {
    _updateReceiverBridgeAdapters(bridgeAdapters, false);
  }

  /// @inheritdoc ICrossChainReceiver
  function receiveCrossChainMessage(
    bytes memory payload,
    uint256 originChainId
  ) external onlyApprovedBridges {
    (, address msgOrigin, address msgDestination, bytes memory message) = abi.decode(
      payload,
      (uint256, address, address, bytes)
    );

    bytes32 internalId = keccak256(abi.encode(originChainId, payload));

    InternalBridgedMessage storage internalMessage = _internalReceivedMessages[internalId];

    // if bridged at is > invalidation means that the first message bridged happened after invalidation
    // which means that invalidation doesnt affect as invalid bridge has already been removed.
    // as nonce is packed in the payload. If message arrives after invalidation from resending, it will pass.
    // if its 0 means that is the first bridge received, meaning that invalidation does not matter for this message
    // checks that bridge adapter has not already bridged this message
    uint120 messageFirstBridgedAt = internalMessage.firstBridgedAt;
    if (
      (messageFirstBridgedAt > _validityTimestamp &&
        !internalMessage.bridgedByAdapter[msg.sender]) || messageFirstBridgedAt == 0
    ) {
      if (messageFirstBridgedAt == 0) {
        internalMessage.firstBridgedAt = uint120(block.timestamp);
      }

      uint256 newConfirmations = ++internalMessage.confirmations;
      internalMessage.bridgedByAdapter[msg.sender] = true;

      emit MessageReceived(
        internalId,
        msg.sender,
        msgDestination,
        msgOrigin,
        message,
        newConfirmations
      );

      // it checks if it has been delivered, so it doesnt deliver again when message arrives from extra bridges
      // (when already reached confirmations) and reverts (because of destination logic)
      // and it saves that these bridges have also correctly bridged the message
      if (newConfirmations == _requiredConfirmations && !internalMessage.delivered) {
        IBaseReceiverPortal(msgDestination).receiveCrossChainMessage(
          msgOrigin,
          originChainId,
          message
        );

        internalMessage.delivered = true;

        emit MessageConfirmed(msgDestination, msgOrigin, message);
      }
    }
  }

  /**
   * @notice method to invalidate messages previous to certain timestamp.
   * @param newValidityTimestamp timestamp where all the previous unconfirmed messages must be invalidated.
   */
  function _updateMessagesValidityTimestamp(uint120 newValidityTimestamp) internal {
    require(newValidityTimestamp > _validityTimestamp, Errors.TIMESTAMP_ALREADY_PASSED);
    _validityTimestamp = newValidityTimestamp;

    emit NewInvalidation(newValidityTimestamp);
  }

  /**
   * @notice updates confirmations needed for a message to be accepted as valid
   * @param newConfirmations number of confirmations
   */
  function _updateConfirmations(uint256 newConfirmations) internal {
    _requiredConfirmations = newConfirmations;
    emit ConfirmationsUpdated(newConfirmations);
  }

  /**
   * @notice method to remove bridge adapters from the allowed list
   * @param bridgeAdapters array of bridge adapter addresses to update
   * @param newState new state, will they be allowed or not
   */
  function _updateReceiverBridgeAdapters(address[] memory bridgeAdapters, bool newState) internal {
    for (uint256 i = 0; i < bridgeAdapters.length; i++) {
      _allowedBridgeAdapters[bridgeAdapters[i]] = newState;

      emit ReceiverBridgeAdaptersUpdated(bridgeAdapters[i], newState);
    }
  }
}
