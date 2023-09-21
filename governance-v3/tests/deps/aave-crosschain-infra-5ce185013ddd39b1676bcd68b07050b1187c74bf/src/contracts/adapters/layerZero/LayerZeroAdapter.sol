// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {BaseAdapter, IBaseAdapter} from '../BaseAdapter.sol';
import {NonblockingLzApp} from 'solidity-examples/lzApp/NonblockingLzApp.sol';
import {ILayerZeroAdapter} from './ILayerZeroAdapter.sol';
import {MainnetChainIds, TestnetChainIds} from '../../libs/ChainIds.sol';
import {Errors} from '../../libs/Errors.sol';

/**
 * @title LayerZeroAdapter
 * @author BGD Labs
 * @notice LayerZero bridge adapter. Used to send and receive messages cross chain
 * @dev it uses the eth balance of CrossChainController contract to pay for message bridging as the method to bridge
        is called via delegate call
 */
contract LayerZeroAdapter is BaseAdapter, NonblockingLzApp, ILayerZeroAdapter {
  /// @inheritdoc ILayerZeroAdapter
  uint16 public constant VERSION = 1;

  /**
   * @notice constructor for the Layer Zero adapter
   * @param _lzEndpoint address of the layer zero endpoint on the current chain where adapter is deployed
   * @param crossChainController address of the contract that manages cross chain infrastructure
   * @param originConfig object with chain id and origin address.
   */
  constructor(
    address _lzEndpoint,
    address crossChainController,
    TrustedRemotesConfig[] memory originConfig
  ) NonblockingLzApp(_lzEndpoint) BaseAdapter(crossChainController) {
    _updateTrustedRemotes(originConfig);
  }

  /// @inheritdoc IBaseAdapter
  function forwardMessage(
    address receiver,
    uint256 destinationGasLimit,
    uint256 destinationChainId,
    bytes memory message
  ) external {
    uint16 nativeChainId = infraToNativeChainId(destinationChainId);
    require(nativeChainId != uint16(0), Errors.DESTINATION_CHAIN_ID_NOT_SUPPORTED);
    require(receiver != address(0), Errors.RECEIVER_NOT_SET);

    bytes memory adapterParams = abi.encodePacked(VERSION, destinationGasLimit);

    (uint256 nativeFee, ) = lzEndpoint.estimateFees(
      nativeChainId,
      receiver,
      message,
      false,
      adapterParams
    );

    require(nativeFee <= address(this).balance, Errors.NOT_ENOUGH_VALUE_TO_PAY_BRIDGE_FEES);

    uint64 nonce = lzEndpoint.getOutboundNonce(nativeChainId, address(this));

    // remote address concatenated with local address packed into 40 bytes
    bytes memory remoteAndLocalAddresses = abi.encodePacked(receiver, address(this));

    lzEndpoint.send{value: nativeFee}(
      nativeChainId,
      remoteAndLocalAddresses,
      message,
      payable(address(this)),
      address(0), // uses native currency for bridge payment
      adapterParams
    );

    emit MessageForwarded(receiver, nativeChainId, message, nonce);
  }

  /// @inheritdoc ILayerZeroAdapter
  function nativeToInfraChainId(uint16 nativeChainId) public pure returns (uint256) {
    if (nativeChainId == uint16(101)) {
      return MainnetChainIds.ETHEREUM;
    } else if (nativeChainId == uint16(106)) {
      return MainnetChainIds.AVALANCHE;
    } else if (nativeChainId == uint16(109)) {
      return MainnetChainIds.POLYGON;
    } else if (nativeChainId == uint16(110)) {
      return MainnetChainIds.ARBITRUM;
    } else if (nativeChainId == uint16(111)) {
      return MainnetChainIds.OPTIMISM;
    } else if (nativeChainId == uint16(112)) {
      return MainnetChainIds.FANTOM;
    } else if (nativeChainId == uint16(116)) {
      return MainnetChainIds.HARMONY;
    } else if (nativeChainId == uint16(10121)) {
      return TestnetChainIds.ETHEREUM_GOERLI;
    } else if (nativeChainId == uint16(10106)) {
      return TestnetChainIds.AVALANCHE_FUJI;
    } else if (nativeChainId == uint16(10132)) {
      return TestnetChainIds.OPTIMISM_GOERLI;
    } else if (nativeChainId == uint16(10109)) {
      return TestnetChainIds.POLYGON_MUMBAI;
    } else if (nativeChainId == uint16(10143)) {
      return TestnetChainIds.ARBITRUM_GOERLI;
    } else if (nativeChainId == uint16(10112)) {
      return TestnetChainIds.FANTOM_TESTNET;
    } else if (nativeChainId == uint16(10133)) {
      return TestnetChainIds.HARMONY_TESTNET;
    } else if (nativeChainId == uint16(10161)) {
      return TestnetChainIds.ETHEREUM_SEPOLIA;
    } else {
      return 0;
    }
  }

  /// @inheritdoc ILayerZeroAdapter
  function infraToNativeChainId(uint256 infraChainId) public pure returns (uint16) {
    if (infraChainId == MainnetChainIds.ETHEREUM) {
      return uint16(101);
    } else if (infraChainId == MainnetChainIds.AVALANCHE) {
      return uint16(106);
    } else if (infraChainId == MainnetChainIds.POLYGON) {
      return uint16(109);
    } else if (infraChainId == MainnetChainIds.ARBITRUM) {
      return uint16(110);
    } else if (infraChainId == MainnetChainIds.OPTIMISM) {
      return uint16(111);
    } else if (infraChainId == MainnetChainIds.FANTOM) {
      return uint16(112);
    } else if (infraChainId == MainnetChainIds.HARMONY) {
      return uint16(116);
    } else if (infraChainId == TestnetChainIds.ETHEREUM_GOERLI) {
      return uint16(10121);
    } else if (infraChainId == TestnetChainIds.AVALANCHE_FUJI) {
      return uint16(10106);
    } else if (infraChainId == TestnetChainIds.OPTIMISM_GOERLI) {
      return uint16(10132);
    } else if (infraChainId == TestnetChainIds.POLYGON_MUMBAI) {
      return uint16(10109);
    } else if (infraChainId == TestnetChainIds.ARBITRUM_GOERLI) {
      return uint16(10143);
    } else if (infraChainId == TestnetChainIds.FANTOM_TESTNET) {
      return uint16(10112);
    } else if (infraChainId == TestnetChainIds.HARMONY_TESTNET) {
      return uint16(10133);
    } else if (infraChainId == TestnetChainIds.ETHEREUM_SEPOLIA) {
      return uint16(10161);
    } else {
      return uint16(0);
    }
  }

  /// @notice method called when receiving a message by layerZero Bridge infra
  function _nonblockingLzReceive(
    uint16 _srcChainId,
    bytes memory _srcAddress,
    uint64 _nonce,
    bytes memory _payload
  ) internal override {
    uint256 originChainId = nativeToInfraChainId(_srcChainId);
    // use assembly to extract the address from the bytes memory parameter
    address fromAddress;
    // use assembly to extract the address from the bytes memory parameter
    // remote address concatenated with local address packed into 40 bytes
    assembly {
      fromAddress := mload(add(_srcAddress, 20))
    }

    _registerReceivedMessage(_payload, originChainId);
    emit LZPayloadProcessed(originChainId, _nonce, fromAddress, _payload);
  }

  /**
   * @notice method that updates from where a message can be received
   * @param originConfigs array of configurations with origin address and chainId
   */
  function _updateTrustedRemotes(TrustedRemotesConfig[] memory originConfigs) internal {
    for (uint256 i = 0; i < originConfigs.length; i++) {
      TrustedRemotesConfig memory originConfig = originConfigs[i];
      uint16 nativeOriginChain = infraToNativeChainId(originConfig.originChainId);
      bytes memory srcBytes = abi.encodePacked(originConfig.originForwarder, address(this));
      trustedRemoteLookup[nativeOriginChain] = srcBytes;
      emit SetTrustedRemote(nativeOriginChain, srcBytes);
    }
  }
}
