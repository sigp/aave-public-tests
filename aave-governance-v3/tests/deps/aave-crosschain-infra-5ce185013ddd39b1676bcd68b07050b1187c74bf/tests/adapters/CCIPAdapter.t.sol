// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {CCIPAdapter, IRouterClient, Client, IBaseAdapter} from '../../src/contracts/adapters/ccip/CCIPAdapter.sol';
import {ICCIPAdapter} from '../../src/contracts/adapters/ccip/ICCIPAdapter.sol';
import {ICrossChainReceiver} from '../../src/contracts/interfaces/ICrossChainReceiver.sol';
import {MainnetChainIds} from '../../src/contracts/libs/ChainIds.sol';
import {Errors} from '../../src/contracts/libs/Errors.sol';

contract CCIPAdapterTest is Test {
  address public constant ORIGIN_FORWARDER = address(123);
  address public constant CROSS_CHAIN_CONTROLLER = address(1234);
  address public constant CCIP_ROUTER = address(12345);
  address public constant RECEIVER_CROSS_CHAIN_CONTROLLER = address(1234567);
  address public constant ADDRESS_WITH_ETH = address(12301234);

  uint256 public constant ORIGIN_CCIP_CHAIN_ID = MainnetChainIds.ETHEREUM;

  ICCIPAdapter.TrustedRemotesConfig originConfig =
    ICCIPAdapter.TrustedRemotesConfig({
      originForwarder: ORIGIN_FORWARDER,
      originChainId: ORIGIN_CCIP_CHAIN_ID
    });

  ICCIPAdapter ccipAdapter;

  event MessageForwarded(
    address indexed receiver,
    uint64 indexed destinationChainId,
    bytes32 indexed messageId,
    bytes message
  );

  event CCIPPayloadProcessed(uint256 indexed srcChainId, address indexed srcAddress, bytes data);

  event SetTrustedRemote(uint256 indexed originChainId, address indexed originForwarder);

  function setUp() public {
    ICCIPAdapter.TrustedRemotesConfig[]
      memory originConfigs = new ICCIPAdapter.TrustedRemotesConfig[](1);
    originConfigs[0] = originConfig;

    ccipAdapter = new CCIPAdapter(CROSS_CHAIN_CONTROLLER, CCIP_ROUTER, originConfigs);
  }

  function testInitialize() public {
    assertEq(ccipAdapter.getTrustedRemoteByChainId(ORIGIN_CCIP_CHAIN_ID), ORIGIN_FORWARDER);
  }

  function testGetInfraChainFromBridgeChain() public {
    assertEq(
      ccipAdapter.nativeToInfraChainId(uint64(MainnetChainIds.POLYGON)),
      MainnetChainIds.POLYGON
    );
  }

  function testGetBridgeChainFromInfraChain() public {
    assertEq(
      ccipAdapter.infraToNativeChainId(MainnetChainIds.POLYGON),
      uint64(MainnetChainIds.POLYGON)
    );
  }

  function testForwardMessage() public {
    uint40 payloadId = uint40(0);
    bytes memory message = abi.encode(payloadId, CROSS_CHAIN_CONTROLLER);
    uint256 dstGasLimit = 600000;
    bytes32 messageId = keccak256(abi.encode(1));
    uint64 nativeChainId = uint64(MainnetChainIds.POLYGON);

    hoax(ADDRESS_WITH_ETH, 10 ether);
    vm.expectEmit(true, true, true, true);
    emit MessageForwarded(RECEIVER_CROSS_CHAIN_CONTROLLER, nativeChainId, messageId, message);
    vm.mockCall(
      CCIP_ROUTER,
      abi.encodeWithSelector(IRouterClient.isChainSupported.selector),
      abi.encode(true)
    );
    vm.mockCall(CCIP_ROUTER, abi.encodeWithSelector(IRouterClient.getFee.selector), abi.encode(10));
    vm.mockCall(
      CCIP_ROUTER,
      10,
      abi.encodeWithSelector(IRouterClient.ccipSend.selector),
      abi.encode(messageId)
    );
    (bool success, ) = address(ccipAdapter).delegatecall(
      abi.encodeWithSelector(
        IBaseAdapter.forwardMessage.selector,
        RECEIVER_CROSS_CHAIN_CONTROLLER,
        dstGasLimit,
        MainnetChainIds.POLYGON,
        message
      )
    );
    vm.clearMockedCalls();

    assertEq(success, true);
  }

  function testForwardMessageWhenChainNotSupported() public {
    uint40 payloadId = uint40(0);
    bytes memory message = abi.encode(payloadId, CROSS_CHAIN_CONTROLLER);
    uint256 dstGasLimit = 600000;

    vm.mockCall(
      CCIP_ROUTER,
      abi.encodeWithSelector(IRouterClient.isChainSupported.selector),
      abi.encode(false)
    );
    vm.expectRevert(bytes(Errors.DESTINATION_CHAIN_ID_NOT_SUPPORTED));
    CCIPAdapter(address(ccipAdapter)).forwardMessage(
      RECEIVER_CROSS_CHAIN_CONTROLLER,
      dstGasLimit,
      10,
      message
    );
  }

  function testForwardMessageWithNoValue() public {
    uint40 payloadId = uint40(0);
    bytes memory payload = abi.encode(payloadId, CROSS_CHAIN_CONTROLLER);

    vm.mockCall(
      CCIP_ROUTER,
      abi.encodeWithSelector(IRouterClient.isChainSupported.selector),
      abi.encode(false)
    );
    vm.mockCall(CCIP_ROUTER, abi.encodeWithSelector(IRouterClient.getFee.selector), abi.encode(10));
    vm.expectRevert(bytes(Errors.NOT_ENOUGH_VALUE_TO_PAY_BRIDGE_FEES));
    (bool success, ) = address(ccipAdapter).delegatecall(
      abi.encodeWithSelector(
        IBaseAdapter.forwardMessage.selector,
        RECEIVER_CROSS_CHAIN_CONTROLLER,
        0,
        MainnetChainIds.POLYGON,
        payload
      )
    );
    assertEq(success, false);
  }

  function testForwardMessageWhenWrongReceiver() public {
    uint40 payloadId = uint40(0);
    bytes memory message = abi.encode(payloadId, CROSS_CHAIN_CONTROLLER);
    uint256 dstGasLimit = 600000;

    vm.mockCall(
      CCIP_ROUTER,
      abi.encodeWithSelector(IRouterClient.isChainSupported.selector),
      abi.encode(true)
    );
    vm.expectRevert(bytes(Errors.RECEIVER_NOT_SET));
    CCIPAdapter(address(ccipAdapter)).forwardMessage(
      address(0),
      dstGasLimit,
      MainnetChainIds.POLYGON,
      message
    );
  }

  function testCCIPReceive() public {
    uint64 originChain = uint64(1);
    bytes memory message = abi.encode('some message');
    bytes32 messageId = keccak256(abi.encode(1));

    Client.Any2EVMMessage memory payload = Client.Any2EVMMessage({
      messageId: messageId,
      sourceChainId: originChain,
      sender: abi.encode(ORIGIN_FORWARDER),
      data: message,
      tokenAmounts: new Client.EVMTokenAmount[](0)
    });

    hoax(CCIP_ROUTER);
    vm.expectEmit(true, true, false, true);
    emit CCIPPayloadProcessed(1, ORIGIN_FORWARDER, message);
    vm.mockCall(
      CROSS_CHAIN_CONTROLLER,
      abi.encodeWithSelector(ICrossChainReceiver.receiveCrossChainMessage.selector),
      abi.encode()
    );
    vm.expectCall(
      CROSS_CHAIN_CONTROLLER,
      0,
      abi.encodeWithSelector(ICrossChainReceiver.receiveCrossChainMessage.selector, message, 1)
    );
    CCIPAdapter(address(ccipAdapter)).ccipReceive(payload);
  }

  function testCCIPReceiveWhenCallerNotRouter() public {
    uint32 originChain = uint32(1);
    bytes memory message = abi.encode('some message');
    bytes32 messageId = keccak256(abi.encode(1));

    Client.Any2EVMMessage memory payload = Client.Any2EVMMessage({
      messageId: messageId,
      sourceChainId: originChain,
      sender: abi.encode(ORIGIN_FORWARDER),
      data: message,
      tokenAmounts: new Client.EVMTokenAmount[](0)
    });

    vm.expectRevert(bytes(Errors.CALLER_NOT_CCIP_ROUTER));

    CCIPAdapter(address(ccipAdapter)).ccipReceive(payload);
  }

  function testCCIPReceiveWithIncorrectOriginChain() public {
    uint32 originChain = uint32(1261);
    bytes memory message = abi.encode('some message');
    bytes32 messageId = keccak256(abi.encode(1));

    Client.Any2EVMMessage memory payload = Client.Any2EVMMessage({
      messageId: messageId,
      sourceChainId: originChain,
      sender: abi.encode(ORIGIN_FORWARDER),
      data: message,
      tokenAmounts: new Client.EVMTokenAmount[](0)
    });

    hoax(CCIP_ROUTER);
    vm.expectRevert(bytes(Errors.INCORRECT_ORIGIN_CHAIN_ID));

    CCIPAdapter(address(ccipAdapter)).ccipReceive(payload);
  }

  function testCCIPReceiveWhenRemoteNotTrusted() public {
    uint32 originChain = uint32(1);
    bytes memory message = abi.encode('some message');
    bytes32 messageId = keccak256(abi.encode(1));

    Client.Any2EVMMessage memory payload = Client.Any2EVMMessage({
      messageId: messageId,
      sourceChainId: originChain,
      sender: abi.encode(address(410298289)),
      data: message,
      tokenAmounts: new Client.EVMTokenAmount[](0)
    });

    hoax(CCIP_ROUTER);
    vm.expectRevert(bytes(Errors.REMOTE_NOT_TRUSTED));

    CCIPAdapter(address(ccipAdapter)).ccipReceive(payload);
  }
}
