// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BaseAdapter, IBaseAdapter} from '../BaseAdapter.sol';
import {ICCIPAdapter, IRouterClient} from './ICCIPAdapter.sol';
import {IAny2EVMMessageReceiver, Client} from './interfaces/IAny2EVMMessageReceiver.sol';
import {IERC165} from './interfaces/IERC165.sol';
import {MainnetChainIds, TestnetChainIds} from '../../libs/ChainIds.sol';
import {Errors} from '../../libs/Errors.sol';

/**
 * @title CCIPAdapter
 * @author BGD Labs
 * @notice CCIP bridge adapter. Used to send and receive messages cross chain
 * @dev it uses the eth balance of CrossChainController contract to pay for message bridging as the method to bridge
        is called via delegate call
 */
contract CCIPAdapter is ICCIPAdapter, BaseAdapter, IAny2EVMMessageReceiver, IERC165 {
  /// @inheritdoc ICCIPAdapter
  IRouterClient public immutable CCIP_ROUTER;

  // (chain -> origin forwarder address) saves for every chain the address that can forward messages to this adapter
  mapping(uint256 => address) internal _trustedRemotes;

  /**
   * @notice only calls from the set router are accepted.
   */
  modifier onlyRouter() {
    require(msg.sender == address(CCIP_ROUTER), Errors.CALLER_NOT_CCIP_ROUTER);
    _;
  }

  /**
   * @param crossChainController address of the cross chain controller that will use this bridge adapter
   * @param ccipRouter ccip entry point address
   * @param trustedRemotes list of remote configurations to set as trusted
   */
  constructor(
    address crossChainController,
    address ccipRouter,
    TrustedRemotesConfig[] memory trustedRemotes
  ) BaseAdapter(crossChainController) {
    require(ccipRouter != address(0), Errors.CCIP_ROUTER_CANT_BE_ADDRESS_0);
    CCIP_ROUTER = IRouterClient(ccipRouter);

    _updateTrustedRemotes(trustedRemotes);
  }

  /// @inheritdoc ICCIPAdapter
  function getTrustedRemoteByChainId(uint256 chainId) external view returns (address) {
    return _trustedRemotes[chainId];
  }

  /// @inheritdoc IERC165
  function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
    return
      interfaceId == type(IAny2EVMMessageReceiver).interfaceId ||
      interfaceId == type(IERC165).interfaceId;
  }

  /// @inheritdoc IBaseAdapter
  function forwardMessage(
    address receiver,
    uint256 gasLimit,
    uint256 destinationChainId,
    bytes memory message
  ) external {
    uint64 nativeDestinationChainId = infraToNativeChainId(destinationChainId);

    require(
      CCIP_ROUTER.isChainSupported(nativeDestinationChainId),
      Errors.DESTINATION_CHAIN_ID_NOT_SUPPORTED
    );
    require(receiver != address(0), Errors.RECEIVER_NOT_SET);

    Client.EVMExtraArgsV1 memory evmExtraArgs = Client.EVMExtraArgsV1({
      gasLimit: gasLimit,
      strict: false
    });

    bytes memory extraArgs = Client._argsToBytes(evmExtraArgs);

    Client.EVM2AnyMessage memory payload = Client.EVM2AnyMessage({
      receiver: abi.encode(receiver),
      data: message,
      tokenAmounts: new Client.EVMTokenAmount[](0),
      feeToken: address(0), // We leave the feeToken empty indicating we'll pay with native gas tokens.,
      extraArgs: extraArgs
    });

    uint256 clFee = CCIP_ROUTER.getFee(nativeDestinationChainId, payload);

    require(address(this).balance >= clFee, Errors.NOT_ENOUGH_VALUE_TO_PAY_BRIDGE_FEES);

    bytes32 messageId = CCIP_ROUTER.ccipSend{value: clFee}(nativeDestinationChainId, payload);

    emit MessageForwarded(receiver, nativeDestinationChainId, messageId, message);
  }

  /// @inheritdoc IAny2EVMMessageReceiver
  function ccipReceive(Client.Any2EVMMessage calldata message) external onlyRouter {
    address srcAddress = abi.decode(message.sender, (address));

    uint256 originChainId = nativeToInfraChainId(message.sourceChainId);

    require(originChainId != 0, Errors.INCORRECT_ORIGIN_CHAIN_ID);

    require(_trustedRemotes[originChainId] == srcAddress, Errors.REMOTE_NOT_TRUSTED);

    _registerReceivedMessage(message.data, originChainId);
    emit CCIPPayloadProcessed(originChainId, srcAddress, message.data);
  }

  /// @inheritdoc ICCIPAdapter
  function nativeToInfraChainId(uint64 nativeChainId) public pure returns (uint256) {
    if (nativeChainId == uint64(MainnetChainIds.ETHEREUM)) {
      return MainnetChainIds.ETHEREUM;
    } else if (nativeChainId == uint64(MainnetChainIds.AVALANCHE)) {
      return MainnetChainIds.AVALANCHE;
    } else if (nativeChainId == uint64(MainnetChainIds.POLYGON)) {
      return MainnetChainIds.POLYGON;
    } else if (nativeChainId == uint64(MainnetChainIds.ARBITRUM)) {
      return MainnetChainIds.ARBITRUM;
    } else if (nativeChainId == uint64(MainnetChainIds.OPTIMISM)) {
      return MainnetChainIds.OPTIMISM;
    } else if (nativeChainId == uint64(MainnetChainIds.FANTOM)) {
      return MainnetChainIds.FANTOM;
    } else if (nativeChainId == uint64(MainnetChainIds.HARMONY)) {
      return MainnetChainIds.HARMONY;
    } else if (nativeChainId == uint64(TestnetChainIds.ETHEREUM_GOERLI)) {
      return TestnetChainIds.ETHEREUM_GOERLI;
    } else if (nativeChainId == uint64(TestnetChainIds.AVALANCHE_FUJI)) {
      return TestnetChainIds.AVALANCHE_FUJI;
    } else if (nativeChainId == uint64(TestnetChainIds.OPTIMISM_GOERLI)) {
      return TestnetChainIds.OPTIMISM_GOERLI;
    } else if (nativeChainId == uint64(TestnetChainIds.POLYGON_MUMBAI)) {
      return TestnetChainIds.POLYGON_MUMBAI;
    } else if (nativeChainId == uint64(TestnetChainIds.ETHEREUM_SEPOLIA)) {
      return TestnetChainIds.ETHEREUM_SEPOLIA;
    } else {
      return 0;
    }
  }

  /// @inheritdoc ICCIPAdapter
  function infraToNativeChainId(uint256 infraChainId) public pure returns (uint64) {
    if (infraChainId == MainnetChainIds.ETHEREUM) {
      return uint64(MainnetChainIds.ETHEREUM);
    } else if (infraChainId == MainnetChainIds.AVALANCHE) {
      return uint64(MainnetChainIds.AVALANCHE);
    } else if (infraChainId == MainnetChainIds.POLYGON) {
      return uint64(MainnetChainIds.POLYGON);
    } else if (infraChainId == MainnetChainIds.ARBITRUM) {
      return uint64(MainnetChainIds.ARBITRUM);
    } else if (infraChainId == MainnetChainIds.OPTIMISM) {
      return uint64(MainnetChainIds.OPTIMISM);
    } else if (infraChainId == MainnetChainIds.FANTOM) {
      return uint64(MainnetChainIds.FANTOM);
    } else if (infraChainId == MainnetChainIds.HARMONY) {
      return uint64(MainnetChainIds.HARMONY);
    } else if (infraChainId == TestnetChainIds.ETHEREUM_GOERLI) {
      return uint64(TestnetChainIds.ETHEREUM_GOERLI);
    } else if (infraChainId == TestnetChainIds.AVALANCHE_FUJI) {
      return uint64(TestnetChainIds.AVALANCHE_FUJI);
    } else if (infraChainId == TestnetChainIds.OPTIMISM_GOERLI) {
      return uint64(TestnetChainIds.OPTIMISM_GOERLI);
    } else if (infraChainId == TestnetChainIds.POLYGON_MUMBAI) {
      return uint64(TestnetChainIds.POLYGON_MUMBAI);
    } else if (infraChainId == TestnetChainIds.ETHEREUM_SEPOLIA) {
      return uint64(TestnetChainIds.ETHEREUM_SEPOLIA);
    } else {
      return uint64(0);
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
