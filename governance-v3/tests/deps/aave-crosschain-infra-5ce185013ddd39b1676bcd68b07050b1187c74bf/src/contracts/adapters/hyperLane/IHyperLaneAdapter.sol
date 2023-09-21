// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IMailbox} from 'hyperlane-monorepo/interfaces/IMailbox.sol';
import {IInterchainGasPaymaster} from 'hyperlane-monorepo/interfaces/IInterchainGasPaymaster.sol';

/**
 * @title IHyperLaneAdapter
 * @author BGD Labs
 * @notice interface containing the events, objects and method definitions used in the HyperLane bridge adapter
 */
interface IHyperLaneAdapter {
  /**
   * @notice pair of origin address and origin chain
   * @param originForwarder address of the contract that will send the messages
   * @param originChainId id of the chain where the trusted remote is from
   */
  struct TrustedRemotesConfig {
    address originForwarder;
    uint256 originChainId;
  }

  /**
   * @notice emitted when a payload is forwarded
   * @param receiver address that will receive the payload
   * @param destinationChainId id of the chain to bridge the payload
   * @param message object to be bridged
   */
  event MessageForwarded(
    address indexed receiver,
    uint32 indexed destinationChainId,
    bytes message
  );

  /**
   * @notice emitted when a trusted remote is set
   * @param originChainId id of the chain where the trusted remote is from
   * @param originForwarder address of the contract that will send the messages
   */
  event SetTrustedRemote(uint256 indexed originChainId, address indexed originForwarder);

  /**
   * @notice emitted when a message is received and has been correctly processed
   * @param originChainId id of the chain where the message originated from
   * @param srcAddress address that sent the message (origin CrossChainContract)
   * @param _messageBody bridged message
   */
  event HLPayloadProcessed(
    uint256 indexed originChainId,
    address indexed srcAddress,
    bytes _messageBody
  );

  /**
   * @notice method to get the current Mail Box address
   * @return the address of the HyperLane Mail Box
   */
  function HL_MAIL_BOX() external view returns (IMailbox);

  /**
   * @notice method to get the current IGP address
   * @return the address of the HyperLane IGP
   */
  function IGP() external view returns (IInterchainGasPaymaster);

  /**
   * @notice method to get the trusted remote for a chain
   * @param chainId id of the chain to get the trusted remote address from
   * @return address of the trusted remote
   */
  function getTrustedRemoteByChainId(uint256 chainId) external view returns (address);

  /**
   * @notice method to get infrastructure chain id from bridge native chain id
   * @param bridgeChainId bridge native chain id
   */
  function nativeToInfraChainId(uint32 bridgeChainId) external returns (uint256);

  /**
   * @notice method to get bridge native chain id from native bridge chain id
   * @param infraChainId infrastructure chain id
   */
  function infraToNativeChainId(uint256 infraChainId) external returns (uint32);
}
