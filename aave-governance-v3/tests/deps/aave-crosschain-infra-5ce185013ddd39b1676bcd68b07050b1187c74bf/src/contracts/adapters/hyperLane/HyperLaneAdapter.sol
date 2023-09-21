// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BaseAdapter, IBaseAdapter} from '../BaseAdapter.sol';
import {IHyperLaneAdapter, IMailbox, IInterchainGasPaymaster} from './IHyperLaneAdapter.sol';
import {IMessageRecipient} from 'hyperlane-monorepo/interfaces/IMessageRecipient.sol';
import {TypeCasts} from 'hyperlane-monorepo/contracts/libs/TypeCasts.sol';
import {MainnetChainIds, TestnetChainIds} from '../../libs/ChainIds.sol';
import {Errors} from '../../libs/Errors.sol';

/**
 * @title HyperLaneAdapter
 * @author BGD Labs
 * @notice HyperLane bridge adapter. Used to send and receive messages cross chain
 * @dev it uses the eth balance of CrossChainController contract to pay for message bridging as the method to bridge
        is called via delegate call
 */
contract HyperLaneAdapter is BaseAdapter, IHyperLaneAdapter, IMessageRecipient {
  /// @inheritdoc IHyperLaneAdapter
  IMailbox public immutable HL_MAIL_BOX;

  /// @inheritdoc IHyperLaneAdapter
  IInterchainGasPaymaster public immutable IGP;

  // (standard chain id -> origin forwarder address) saves for every chain the address that can forward messages to this adapter
  mapping(uint256 => address) internal _trustedRemotes;

  /// @notice modifier to check that caller is hyper lane mailBox
  modifier onlyMailbox() {
    require(msg.sender == address(HL_MAIL_BOX), Errors.CALLER_NOT_HL_MAILBOX);
    _;
  }

  /**
   * @param crossChainController address of the cross chain controller that will use this bridge adapter
   * @param mailBox HyperLane router contract address to send / receive cross chain messages
   * @param igp HyperLane contract to get the gas estimation to pay for sending messages
   * @param trustedRemotes list of remote configurations to set as trusted
   */
  constructor(
    address crossChainController,
    address mailBox,
    address igp,
    TrustedRemotesConfig[] memory trustedRemotes
  ) BaseAdapter(crossChainController) {
    HL_MAIL_BOX = IMailbox(mailBox);
    IGP = IInterchainGasPaymaster(igp);
    _updateTrustedRemotes(trustedRemotes);
  }

  /// @inheritdoc IHyperLaneAdapter
  function getTrustedRemoteByChainId(uint256 chainId) external view returns (address) {
    return _trustedRemotes[chainId];
  }

  /// @inheritdoc IBaseAdapter
  function forwardMessage(
    address receiver,
    uint256 destinationGasLimit,
    uint256 destinationChainId,
    bytes memory message
  ) external {
    uint32 nativeChainId = infraToNativeChainId(destinationChainId);
    require(nativeChainId != uint32(0), Errors.DESTINATION_CHAIN_ID_NOT_SUPPORTED);
    require(receiver != address(0), Errors.RECEIVER_NOT_SET);

    bytes32 messageId = HL_MAIL_BOX.dispatch(
      nativeChainId,
      TypeCasts.addressToBytes32(receiver),
      message
    );

    // Get the required payment from the IGP.
    uint256 quotedPayment = IGP.quoteGasPayment(nativeChainId, destinationGasLimit);

    require(quotedPayment <= address(this).balance, Errors.NOT_ENOUGH_VALUE_TO_PAY_BRIDGE_FEES);

    // Pay from the contract's balance
    IGP.payForGas{value: quotedPayment}(
      messageId, // The ID of the message that was just dispatched
      nativeChainId, // The destination domain of the message
      destinationGasLimit,
      address(this) // refunds go to msg.sender, who paid the msg.value
    );

    emit MessageForwarded(receiver, nativeChainId, message);
  }

  /// @inheritdoc IMessageRecipient
  function handle(
    uint32 _origin,
    bytes32 _sender,
    bytes calldata _messageBody
  ) external onlyMailbox {
    address srcAddress = TypeCasts.bytes32ToAddress(_sender);

    uint256 originChainId = nativeToInfraChainId(_origin);

    require(originChainId != 0, Errors.INCORRECT_ORIGIN_CHAIN_ID);

    require(_trustedRemotes[originChainId] == srcAddress, Errors.REMOTE_NOT_TRUSTED);
    _registerReceivedMessage(_messageBody, originChainId);
    emit HLPayloadProcessed(originChainId, srcAddress, _messageBody);
  }

  /// @inheritdoc IHyperLaneAdapter
  function nativeToInfraChainId(uint32 nativeChainId) public pure returns (uint256) {
    if (nativeChainId == uint32(MainnetChainIds.ETHEREUM)) {
      return MainnetChainIds.ETHEREUM;
    } else if (nativeChainId == uint32(MainnetChainIds.AVALANCHE)) {
      return MainnetChainIds.AVALANCHE;
    } else if (nativeChainId == uint32(MainnetChainIds.POLYGON)) {
      return MainnetChainIds.POLYGON;
    } else if (nativeChainId == uint32(MainnetChainIds.ARBITRUM)) {
      return MainnetChainIds.ARBITRUM;
    } else if (nativeChainId == uint32(MainnetChainIds.OPTIMISM)) {
      return MainnetChainIds.OPTIMISM;
    } else if (nativeChainId == uint32(TestnetChainIds.ETHEREUM_GOERLI)) {
      return TestnetChainIds.ETHEREUM_GOERLI;
    } else if (nativeChainId == uint32(TestnetChainIds.AVALANCHE_FUJI)) {
      return TestnetChainIds.AVALANCHE_FUJI;
    } else if (nativeChainId == uint32(TestnetChainIds.OPTIMISM_GOERLI)) {
      return TestnetChainIds.OPTIMISM_GOERLI;
    } else if (nativeChainId == uint32(TestnetChainIds.POLYGON_MUMBAI)) {
      return TestnetChainIds.POLYGON_MUMBAI;
    } else if (nativeChainId == uint32(TestnetChainIds.ARBITRUM_GOERLI)) {
      return TestnetChainIds.ARBITRUM_GOERLI;
    } else if (nativeChainId == uint32(TestnetChainIds.ETHEREUM_SEPOLIA)) {
      return TestnetChainIds.ETHEREUM_SEPOLIA;
    } else {
      return 0;
    }
  }

  /// @inheritdoc IHyperLaneAdapter
  function infraToNativeChainId(uint256 infraChainId) public pure returns (uint32) {
    if (infraChainId == MainnetChainIds.ETHEREUM) {
      return uint32(MainnetChainIds.ETHEREUM);
    } else if (infraChainId == MainnetChainIds.AVALANCHE) {
      return uint32(MainnetChainIds.AVALANCHE);
    } else if (infraChainId == MainnetChainIds.POLYGON) {
      return uint32(MainnetChainIds.POLYGON);
    } else if (infraChainId == MainnetChainIds.ARBITRUM) {
      return uint32(MainnetChainIds.ARBITRUM);
    } else if (infraChainId == MainnetChainIds.OPTIMISM) {
      return uint32(MainnetChainIds.OPTIMISM);
    } else if (infraChainId == TestnetChainIds.ETHEREUM_GOERLI) {
      return uint32(TestnetChainIds.ETHEREUM_GOERLI);
    } else if (infraChainId == TestnetChainIds.AVALANCHE_FUJI) {
      return uint32(TestnetChainIds.AVALANCHE_FUJI);
    } else if (infraChainId == TestnetChainIds.OPTIMISM_GOERLI) {
      return uint32(TestnetChainIds.OPTIMISM_GOERLI);
    } else if (infraChainId == TestnetChainIds.POLYGON_MUMBAI) {
      return uint32(TestnetChainIds.POLYGON_MUMBAI);
    } else if (infraChainId == TestnetChainIds.ARBITRUM_GOERLI) {
      return uint32(TestnetChainIds.ARBITRUM_GOERLI);
    } else if (infraChainId == TestnetChainIds.ETHEREUM_SEPOLIA) {
      return uint32(TestnetChainIds.ETHEREUM_SEPOLIA);
    } else {
      return uint32(0);
    }
  }

  /**
   * @notice method to set trusted remotes. These are addresses that are allowed to receive messages from
   * @param trustedRemotes list of objects with the trusted remotes configurations
   **/
  function _updateTrustedRemotes(TrustedRemotesConfig[] memory trustedRemotes) internal {
    for (uint256 i = 0; i < trustedRemotes.length; i++) {
      _trustedRemotes[trustedRemotes[i].originChainId] = trustedRemotes[i].originForwarder;
      emit SetTrustedRemote(trustedRemotes[i].originChainId, trustedRemotes[i].originForwarder);
    }
  }
}
