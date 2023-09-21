// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {OwnableWithGuardian} from 'solidity-utils/contracts/access-control/OwnableWithGuardian.sol';
import {ICrossChainForwarder} from './interfaces/ICrossChainForwarder.sol';
import {IBaseAdapter} from './adapters/IBaseAdapter.sol';
import {Errors} from './libs/Errors.sol';

/**
 * @title CrossChainForwarder
 * @author BGD Labs
 * @notice this contract contains the methods used to forward messages to different chains
 *         using registered bridge adapters.
 * @dev To be able to forward a message, caller needs to be an approved sender.
 */
contract CrossChainForwarder is OwnableWithGuardian, ICrossChainForwarder {
  // for every message we attach a nonce, that will be unique for the message. It increments by one
  uint256 internal _currentNonce;

  // specifies if an address is approved to forward messages
  mapping(address => bool) internal _approvedSenders;

  // Stores messages sent. hash(chainId, msgId, origin, dest, message) . This is used to check if a message can be retried
  mapping(bytes32 => bool) internal _forwardedMessages;

  // (chainId => chain configuration) list of bridge adapter configurations for a chain
  mapping(uint256 => ChainIdBridgeConfig[]) internal _bridgeAdaptersByChain;

  // checks if caller is an approved sender
  modifier onlyApprovedSenders() {
    require(isSenderApproved(msg.sender), Errors.CALLER_IS_NOT_APPROVED_SENDER);
    _;
  }

  /**
   * @param bridgeAdaptersToEnable list of bridge adapter configurations to enable
   * @param sendersToApprove list of addresses to approve to forward messages
   */
  constructor(
    BridgeAdapterConfigInput[] memory bridgeAdaptersToEnable,
    address[] memory sendersToApprove
  ) {
    _enableBridgeAdapters(bridgeAdaptersToEnable);
    _updateSenders(sendersToApprove, true);
  }

  /// @inheritdoc ICrossChainForwarder
  function getCurrentNonce() external view returns (uint256) {
    return _currentNonce;
  }

  /// @inheritdoc ICrossChainForwarder
  function isSenderApproved(address sender) public view returns (bool) {
    return _approvedSenders[sender];
  }

  /// @inheritdoc ICrossChainForwarder
  function isMessageForwarded(
    uint256 destinationChainId,
    address origin,
    address destination,
    bytes memory message
  ) public view returns (bool) {
    bytes32 hashedMsgId = keccak256(abi.encode(destinationChainId, origin, destination, message));

    return _forwardedMessages[hashedMsgId];
  }

  /// @inheritdoc ICrossChainForwarder
  function forwardMessage(
    uint256 destinationChainId,
    address destination,
    uint256 gasLimit,
    bytes memory message
  ) external onlyApprovedSenders {
    _forwardMessage(destinationChainId, msg.sender, destination, gasLimit, message);
  }

  /// @inheritdoc ICrossChainForwarder
  function retryMessage(
    uint256 destinationChainId,
    address origin,
    address destination,
    uint256 gasLimit,
    bytes memory message
  ) external onlyOwnerOrGuardian {
    // If message not bridged before means that something in the message params has changed
    // and it can not be directly resent.
    require(
      isMessageForwarded(destinationChainId, origin, destination, message) == true,
      Errors.MESSAGE_REQUIRED_TO_HAVE_BEEN_PREVIOUSLY_FORWARDED
    );
    _forwardMessage(destinationChainId, origin, destination, gasLimit, message);
  }

  /// @inheritdoc ICrossChainForwarder
  function getBridgeAdaptersByChain(
    uint256 chainId
  ) external view returns (ChainIdBridgeConfig[] memory) {
    return _bridgeAdaptersByChain[chainId];
  }

  /**
   * @dev method called to initiate message forwarding to other networks.
   * @param destinationChainId id of the destination chain where the message needs to be bridged
   * @param origin address where the message originates from
   * @param destination address where the message is intended for
   * @param message bytes that need to be bridged
   */
  function _forwardMessage(
    uint256 destinationChainId,
    address origin,
    address destination,
    uint256 gasLimit,
    bytes memory message
  ) internal {
    bytes memory encodedMessage = abi.encode(_currentNonce++, origin, destination, message);

    ChainIdBridgeConfig[] memory bridgeAdapters = _bridgeAdaptersByChain[destinationChainId];

    bool someMessageForwarded;
    for (uint256 i = 0; i < bridgeAdapters.length; i++) {
      ChainIdBridgeConfig memory bridgeAdapterConfig = bridgeAdapters[i];

      (bool success, bytes memory returnData) = bridgeAdapterConfig
        .currentChainBridgeAdapter
        .delegatecall(
          abi.encodeWithSelector(
            IBaseAdapter.forwardMessage.selector,
            bridgeAdapterConfig.destinationBridgeAdapter,
            gasLimit,
            destinationChainId,
            encodedMessage
          )
        );

      if (!success) {
        // it doesnt revert as sending to other bridges might succeed
        emit AdapterFailed(
          destinationChainId,
          bridgeAdapterConfig.currentChainBridgeAdapter,
          bridgeAdapterConfig.destinationBridgeAdapter,
          encodedMessage,
          returnData
        );
      } else {
        someMessageForwarded = true;

        emit MessageForwarded(
          destinationChainId,
          bridgeAdapterConfig.currentChainBridgeAdapter,
          bridgeAdapterConfig.destinationBridgeAdapter,
          encodedMessage
        );
      }
    }

    require(someMessageForwarded, Errors.NO_MESSAGE_FORWARDED_SUCCESSFULLY);

    // save sent message for future retries. We save even if one bridge was able to send
    // so this way, if other bridges failed, we can retry.
    bytes32 fullMessageId = keccak256(abi.encode(destinationChainId, origin, destination, message));
    _forwardedMessages[fullMessageId] = true;
  }

  /// @inheritdoc ICrossChainForwarder
  function approveSenders(address[] memory senders) external onlyOwner {
    _updateSenders(senders, true);
  }

  /// @inheritdoc ICrossChainForwarder
  function removeSenders(address[] memory senders) external onlyOwner {
    _updateSenders(senders, false);
  }

  /// @inheritdoc ICrossChainForwarder
  function enableBridgeAdapters(
    BridgeAdapterConfigInput[] memory bridgeAdapters
  ) external onlyOwner {
    _enableBridgeAdapters(bridgeAdapters);
  }

  /// @inheritdoc ICrossChainForwarder
  function disableBridgeAdapters(
    BridgeAdapterToDisable[] memory bridgeAdapters
  ) external onlyOwner {
    _disableBridgeAdapters(bridgeAdapters);
  }

  /**
   * @notice method to enable bridge adapters
   * @param bridgeAdapters array of new bridge adapter configurations
   */
  function _enableBridgeAdapters(BridgeAdapterConfigInput[] memory bridgeAdapters) internal {
    for (uint256 i = 0; i < bridgeAdapters.length; i++) {
      BridgeAdapterConfigInput memory bridgeAdapterConfigInput = bridgeAdapters[i];

      require(
        bridgeAdapterConfigInput.destinationBridgeAdapter != address(0) &&
          bridgeAdapterConfigInput.currentChainBridgeAdapter != address(0),
        Errors.CURRENT_OR_DESTINATION_CHAIN_ADAPTER_NOT_SET
      );
      ChainIdBridgeConfig[] storage bridgeAdapterConfigs = _bridgeAdaptersByChain[
        bridgeAdapterConfigInput.destinationChainId
      ];
      bool configFound;
      // check that we dont push same config twice.
      for (uint256 j = 0; j < bridgeAdapterConfigs.length; j++) {
        ChainIdBridgeConfig storage bridgeAdapterConfig = bridgeAdapterConfigs[j];

        if (
          bridgeAdapterConfig.currentChainBridgeAdapter ==
          bridgeAdapterConfigInput.currentChainBridgeAdapter
        ) {
          if (
            bridgeAdapterConfig.destinationBridgeAdapter !=
            bridgeAdapterConfigInput.destinationBridgeAdapter
          ) {
            bridgeAdapterConfig.destinationBridgeAdapter = bridgeAdapterConfigInput
              .destinationBridgeAdapter;
          }
          configFound = true;
          break;
        }
      }

      if (!configFound) {
        bridgeAdapterConfigs.push(
          ChainIdBridgeConfig({
            destinationBridgeAdapter: bridgeAdapterConfigInput.destinationBridgeAdapter,
            currentChainBridgeAdapter: bridgeAdapterConfigInput.currentChainBridgeAdapter
          })
        );
      }

      emit BridgeAdapterUpdated(
        bridgeAdapterConfigInput.destinationChainId,
        bridgeAdapterConfigInput.currentChainBridgeAdapter,
        bridgeAdapterConfigInput.destinationBridgeAdapter,
        true
      );
    }
  }

  /**
   * @notice method to disable bridge adapters
   * @param bridgeAdaptersToDisable array of bridge adapter addresses to disable
   */
  function _disableBridgeAdapters(
    BridgeAdapterToDisable[] memory bridgeAdaptersToDisable
  ) internal {
    for (uint256 i = 0; i < bridgeAdaptersToDisable.length; i++) {
      for (uint256 j = 0; j < bridgeAdaptersToDisable[i].chainIds.length; j++) {
        ChainIdBridgeConfig[] storage bridgeAdapterConfigs = _bridgeAdaptersByChain[
          bridgeAdaptersToDisable[i].chainIds[j]
        ];

        for (uint256 k = 0; k < bridgeAdapterConfigs.length; k++) {
          if (
            bridgeAdapterConfigs[k].currentChainBridgeAdapter ==
            bridgeAdaptersToDisable[i].bridgeAdapter
          ) {
            address destinationBridgeAdapter = bridgeAdapterConfigs[k].destinationBridgeAdapter;

            if (k != bridgeAdapterConfigs.length) {
              bridgeAdapterConfigs[k] = bridgeAdapterConfigs[bridgeAdapterConfigs.length - 1];
            }

            bridgeAdapterConfigs.pop();

            emit BridgeAdapterUpdated(
              bridgeAdaptersToDisable[i].chainIds[j],
              bridgeAdaptersToDisable[i].bridgeAdapter,
              destinationBridgeAdapter,
              false
            );
            break;
          }
        }
      }
    }
  }

  /**
   * @notice method to approve or disapprove a list of senders
   * @param senders list of addresses to update
   * @param newState indicates if the list of senders will be approved or disapproved
   */
  function _updateSenders(address[] memory senders, bool newState) internal {
    for (uint256 i = 0; i < senders.length; i++) {
      _approvedSenders[senders[i]] = newState;
      emit SenderUpdated(senders[i], newState);
    }
  }
}
