// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {IBaseAdapter} from '../IBaseAdapter.sol';
import {IBaseReceiverPortal} from '../../interfaces/IBaseReceiverPortal.sol';
import {Errors} from '../../libs/Errors.sol';
import {Transaction, Envelope, TransactionUtils} from '../../libs/EncodingUtils.sol';

/**
 * @title SameChainAdapter
 * @author BGD Labs
 * @notice adapter that shortcutting the cross chain flow. As for same chain we can send the message directly
           to receiver without the need for bridging. Takes the chain Id directly from deployed chain to ensure
           that the message is forwarded to same chain
 */
contract SameChainAdapter is IBaseAdapter {
  /// @inheritdoc IBaseAdapter
  function forwardMessage(
    address,
    uint256,
    uint256 destinationChainId,
    bytes calldata message
  ) external returns (address, uint256) {
    require(
      destinationChainId == block.chainid,
      Errors.DESTINATION_CHAIN_NOT_SAME_AS_CURRENT_CHAIN
    );

    Transaction memory transaction = TransactionUtils.decode(message);
    Envelope memory envelope = transaction.getEnvelope();

    IBaseReceiverPortal(envelope.destination).receiveCrossChainMessage(
      envelope.origin,
      destinationChainId,
      envelope.message
    );
    return (envelope.destination, 0);
  }

  /// @inheritdoc IBaseAdapter
  function setupPayments() external {}

  /// @inheritdoc IBaseAdapter
  function nativeToInfraChainId(uint256 nativeChainId) public view override returns (uint256) {
    if (nativeChainId == block.chainid) {
      return nativeChainId;
    }
    return 0;
  }

  /// @inheritdoc IBaseAdapter
  function infraToNativeChainId(uint256 infraChainId) public view override returns (uint256) {
    if (infraChainId == block.chainid) {
      return infraChainId;
    }
    return 0;
  }

  /// @inheritdoc IBaseAdapter
  function getTrustedRemoteByChainId(uint256) external pure returns (address) {
    return address(0);
  }
}
