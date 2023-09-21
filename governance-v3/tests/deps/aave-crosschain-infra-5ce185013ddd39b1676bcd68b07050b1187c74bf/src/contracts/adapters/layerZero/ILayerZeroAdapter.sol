// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ILayerZeroAdapter
 * @author BGD Labs
 * @notice interface containing the events, objects and method definitions used in the LayerZero bridge adapter
 */
interface ILayerZeroAdapter {
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
   * @param nonce outbound nonce
   */
  event MessageForwarded(
    address indexed receiver,
    uint16 indexed destinationChainId,
    bytes message,
    uint256 nonce
  );

  /**
   * @notice emitted when a payload has been received and processed
   * @param originChainId id indicating the origin chain
   * @param nonce unique number of the message
   * @param sender address of the origination contract
   * @param payload message bridged
   */
  event LZPayloadProcessed(
    uint256 indexed originChainId,
    uint64 nonce,
    address indexed sender,
    bytes payload
  );

  /**
   * @notice returns the layer zero version used
   * @return LayerZero version
   */
  function VERSION() external view returns (uint16);

  /**
   * @notice method to get infrastructure chain id from bridge native chain id
   * @param bridgeChainId bridge native chain id
   */
  function nativeToInfraChainId(uint16 bridgeChainId) external returns (uint256);

  /**
   * @notice method to get bridge native chain id from native bridge chain id
   * @param infraChainId infrastructure chain id
   */
  function infraToNativeChainId(uint256 infraChainId) external returns (uint16);
}
