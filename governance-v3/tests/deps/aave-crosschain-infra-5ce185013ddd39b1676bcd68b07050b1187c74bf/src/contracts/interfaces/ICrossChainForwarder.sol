// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

/**
 * @title ICrossChainForwarder
 * @author BGD Labs
 * @notice interface containing the objects, events and methods definitions of the CrossChainForwarder contract
 */
interface ICrossChainForwarder {
  /**
   * @notice object storing the connected pair of bridge adapters, on current and destination chain
   * @param destinationBridgeAdapter address of the bridge adapter on the destination chain
   * @param currentChainBridgeAdapter address of the bridge adapter deployed on current network
   */
  struct ChainIdBridgeConfig {
    address destinationBridgeAdapter;
    address currentChainBridgeAdapter;
  }

  /**
   * @notice object with the necessary information to remove bridge adapters
   * @param bridgeAdapter address of the bridge adapter to remove
   * @param chainIds array of chain ids where the bridge adapter connects
   */
  struct BridgeAdapterToDisable {
    address bridgeAdapter;
    uint256[] chainIds;
  }

  /**
   * @notice object storing the pair bridgeAdapter (current deployed chain) destination chain bridge adapter configuration
   * @param currentChainBridgeAdapter address of the bridge adapter deployed on current chain
   * @param destinationBridgeAdapter address of the bridge adapter on the destination chain
   * @param dstChainId id of the destination chain using our own nomenclature
   */
  struct BridgeAdapterConfigInput {
    address currentChainBridgeAdapter;
    address destinationBridgeAdapter;
    uint256 destinationChainId;
  }

  /**
   * @notice emitted when a bridge adapter failed to send a message
   * @param destinationChainId id of the destination chain in our notation
   * @param bridgeAdapter address of the bridge adapter that failed (deployed on current network)
   * @param destinationBridgeAdapter address of the connected bridge adapter on destination chain
   * @param destinationChainId id of destination chain
   * @param message bytes intended to be bridged
   * @param returndata bytes with error information
   */
  event AdapterFailed(
    uint256 indexed destinationChainId,
    address indexed bridgeAdapter,
    address indexed destinationBridgeAdapter,
    bytes message,
    bytes returndata
  );

  /**
   * @notice emitted when a message is successfully forwarded through a bridge adapter
   * @param destinationChainId id of the destination chain in our notation
   * @param bridgeAdapter address of the bridge adapter that failed (deployed on current network)
   * @param destinationBridgeAdapter address of the connected bridge adapter on destination chain
   * @param destinationChainId id of destination chain
   * @param message bytes intended to be bridged
   */
  event MessageForwarded(
    uint256 indexed destinationChainId,
    address indexed bridgeAdapter,
    address indexed destinationBridgeAdapter,
    bytes message
  );

  /**
   * @notice emitted when a bridge adapter has been added to the allowed list
   * @param destinationChainId id of the destination chain in our notation
   * @param bridgeAdapter address of the bridge adapter added (deployed on current network)
   * @param destinationBridgeAdapter address of the connected bridge adapter on destination chain
   * @param allowed boolean indicating if the bridge adapter is allowed or disallowed
   */
  event BridgeAdapterUpdated(
    uint256 indexed destinationChainId,
    address indexed bridgeAdapter,
    address destinationBridgeAdapter,
    bool indexed allowed
  );

  /**
   * @notice emitted when a sender has been updated
   * @param sender address of the updated sender
   * @param isApproved boolean that indicates if the sender has been approved or removed
   */
  event SenderUpdated(address indexed sender, bool indexed isApproved);

  /**
   * @notice method to get the current sent message nonce
   * @return the current nonce
   */
  function getCurrentNonce() external view returns (uint256);

  /**
   * @notice method to check if a message has been previously forwarded.
   * @param destinationChainId id of the destination chain where the message needs to be bridged
   * @param origin address where the message originates from
   * @param destination address where the message is intended for
   * @param message bytes that need to be bridged
   * @return boolean indicating if the message has been forwarded
   */
  function isMessageForwarded(
    uint256 destinationChainId,
    address origin,
    address destination,
    bytes memory message
  ) external view returns (bool);

  /**
   * @notice method called to initiate message forwarding to other networks.
   * @param destinationChainId id of the destination chain where the message needs to be bridged
   * @param destination address where the message is intended for
   * @param gasLimit gas cost on receiving side of the message
   * @param message bytes that need to be bridged
   */
  function forwardMessage(
    uint256 destinationChainId,
    address destination,
    uint256 gasLimit,
    bytes memory message
  ) external;

  /**
   * @notice method called to re forward a previously sent message.
   * @param destinationChainId id of the destination chain where the message needs to be bridged
   * @param origin address where the message originates from
   * @param destination address where the message is intended for
   * @param gasLimit gas cost on receiving side of the message
   * @param message bytes that need to be bridged
   */
  function retryMessage(
    uint256 destinationChainId,
    address origin,
    address destination,
    uint256 gasLimit,
    bytes memory message
  ) external;

  /**
   * @notice method to enable bridge adapters
   * @param bridgeAdapters array of new bridge adapter configurations
   */
  function enableBridgeAdapters(BridgeAdapterConfigInput[] memory bridgeAdapters) external;

  /**
   * @notice method to disable bridge adapters
   * @param bridgeAdapters array of bridge adapter addresses to disable
   */
  function disableBridgeAdapters(BridgeAdapterToDisable[] memory bridgeAdapters) external;

  /**
   * @notice method to remove sender addresses
   * @param senders list of addresses to remove
   */
  function removeSenders(address[] memory senders) external;

  /**
   * @notice method to approve new sender addresses
   * @param senders list of addresses to approve
   */
  function approveSenders(address[] memory senders) external;

  /**
   * @notice method to get all the bridge adapters of a chain
   * @param chainId id of the chain we want to get the adateprs from
   * @return an array of chain configurations where the bridge adapter can communicate
   */
  function getBridgeAdaptersByChain(
    uint256 chainId
  ) external view returns (ChainIdBridgeConfig[] memory);

  /**
   * @notice method to get if a sender is approved
   * @param sender address that we want to check if approved
   * @return boolean indicating if the address has been approved as sender
   */
  function isSenderApproved(address sender) external view returns (bool);
}
