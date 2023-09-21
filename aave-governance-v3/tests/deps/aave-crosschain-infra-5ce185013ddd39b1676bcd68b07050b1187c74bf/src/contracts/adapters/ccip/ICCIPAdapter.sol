// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRouterClient} from './interfaces/IRouterClient.sol';

/**
 * @title ICCIPAdapter
 * @author BGD Labs
 * @notice interface containing the events, objects and method definitions used in the CCIP bridge adapter
 */
interface ICCIPAdapter {
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
   * @param messageId CCIP id of the message forwarded
   * @param message object to be bridged
   */
  event MessageForwarded(
    address indexed receiver,
    uint64 indexed destinationChainId,
    bytes32 indexed messageId,
    bytes message
  );

  /**
   * @notice emitted when a message is received and has been correctly processed
   * @param srcChainId id of the chain where the message originated from
   * @param srcAddress address that sent the message (origin CrossChainContract)
   * @param data bridged message
   */
  event CCIPPayloadProcessed(uint256 indexed srcChainId, address indexed srcAddress, bytes data);

  /**
   * @notice emitted when a trusted remote is set
   * @param originChainId id of the chain where the trusted remote is from
   * @param originForwarder address of the contract that will send the messages
   */
  event SetTrustedRemote(uint256 indexed originChainId, address indexed originForwarder);

  /**
   * @notice method to get the CCIP router address
   * @return adddress of the CCIP router
   */
  function CCIP_ROUTER() external view returns (IRouterClient);

  /**
   * @notice method to get the trusted remote address from a specified chain id
   * @param chainId id of the chain from where to get the trusted remote
   * @return address of the trusted remote
   */
  function getTrustedRemoteByChainId(uint256 chainId) external view returns (address);

  /**
   * @notice method to get infrastructure chain id from bridge native chain id
   * @param nativeChainId bridge native chain id
   */
  function nativeToInfraChainId(uint64 nativeChainId) external pure returns (uint256);

  /**
   * @notice method to get bridge native chain id from native bridge chain id
   * @param infraChainId infrastructure chain id
   */
  function infraToNativeChainId(uint256 infraChainId) external pure returns (uint64);
}
