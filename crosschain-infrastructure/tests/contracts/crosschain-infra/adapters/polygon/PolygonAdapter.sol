// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BaseAdapter, IBaseAdapter} from '../BaseAdapter.sol';
import {IPolygonAdapter} from './IPolygonAdapter.sol';
import {Errors} from '../../libs/Errors.sol';
import {ChainIds} from '../../libs/ChainIds.sol';
import {IFxStateSender} from './interfaces/IFxStateSender.sol';
import {IFxMessageProcessor} from './interfaces/IFxMessageProcessor.sol';

/**
 * @title PolygonAdapter
 * @author BGD Labs
 * @notice Polygon bridge adapter. Used to send and receive messages cross chain between Ethereum and Polygon
 * @dev it uses the eth balance of CrossChainController contract to pay for message bridging as the method to bridge
        is called via delegate call
 */
contract PolygonAdapter is IPolygonAdapter, IFxMessageProcessor, BaseAdapter {
  address public immutable FX_ROOT;
  address public immutable FX_CHILD;

  /**
   * @notice Only FxChild can call functions marked by this modifier.
   **/
  modifier onlyFxChild() {
    require(msg.sender == FX_CHILD, Errors.CALLER_NOT_FX_CHILD);
    _;
  }

  /**
   * @param crossChainController address of the cross chain controller that will use this bridge adapter
   * @param fxRoot polygon entry point address
   * @param fxChild polygon contract that receives messages from origin chain and calls adapter
   * @param trustedRemotes list of remote configurations to set as trusted
   */
  constructor(
    address crossChainController,
    address fxRoot,
    address fxChild,
    TrustedRemotesConfig[] memory trustedRemotes
  ) BaseAdapter(crossChainController, trustedRemotes) {
    FX_ROOT = fxRoot;
    FX_CHILD = fxChild;
  }

  /// @inheritdoc IBaseAdapter
  function forwardMessage(
    address receiver,
    uint256,
    uint256 destinationChainId,
    bytes calldata message
  ) external returns (address, uint256) {
    require(
      isDestinationChainIdSupported(destinationChainId),
      Errors.DESTINATION_CHAIN_ID_NOT_SUPPORTED
    );
    require(receiver != address(0), Errors.RECEIVER_NOT_SET);

    IFxStateSender(FX_ROOT).sendMessageToChild(receiver, message);

    return (FX_ROOT, 0);
  }

  /// @inheritdoc IFxMessageProcessor
  function processMessageFromRoot(
    uint256,
    address rootMessageSender,
    bytes calldata data
  ) external override onlyFxChild {
    uint256 originChainId = getOriginChainId();
    require(
      _trustedRemotes[originChainId] == rootMessageSender && rootMessageSender != address(0),
      Errors.REMOTE_NOT_TRUSTED
    );

    _registerReceivedMessage(data, originChainId);
  }

  /// @inheritdoc IPolygonAdapter
  function getOriginChainId() public view virtual returns (uint256) {
    return ChainIds.ETHEREUM;
  }

  /// @inheritdoc IPolygonAdapter
  function isDestinationChainIdSupported(uint256 chainId) public view virtual returns (bool) {
    return chainId == ChainIds.POLYGON;
  }

  /// @inheritdoc IBaseAdapter
  function nativeToInfraChainId(uint256 nativeChainId) public pure override returns (uint256) {
    return nativeChainId;
  }

  /// @inheritdoc IBaseAdapter
  function infraToNativeChainId(uint256 infraChainId) public pure override returns (uint256) {
    return infraChainId;
  }
}
