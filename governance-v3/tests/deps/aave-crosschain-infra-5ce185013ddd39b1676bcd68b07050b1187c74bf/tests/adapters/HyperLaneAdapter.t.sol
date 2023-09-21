// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {HyperLaneAdapter, IHyperLaneAdapter, IMailbox, IInterchainGasPaymaster} from '../../src/contracts/adapters/hyperLane/HyperLaneAdapter.sol';
import {ICrossChainReceiver} from '../../src/contracts/interfaces/ICrossChainReceiver.sol';
import {IBaseAdapter} from '../../src/contracts/adapters/IBaseAdapter.sol';
import {TypeCasts} from 'hyperlane-monorepo/contracts/libs/TypeCasts.sol';
import {MainnetChainIds} from '../../src/contracts/libs/ChainIds.sol';
import {Errors} from '../../src/contracts/libs/Errors.sol';

contract HyperLaneAdapterTest is Test {
  address public constant ORIGIN_FORWARDER = address(123);
  address public constant CROSS_CHAIN_CONTROLLER = address(1234);
  address public constant MAIL_BOX = address(12345);
  address public constant IGP = address(123456);
  address public constant RECEIVER_CROSS_CHAIN_CONTROLLER = address(1234567);
  address public constant ADDRESS_WITH_ETH = address(12301234);

  uint256 public constant ORIGIN_HL_CHAIN_ID = MainnetChainIds.ETHEREUM;

  IHyperLaneAdapter public hlAdapter;

  IHyperLaneAdapter.TrustedRemotesConfig originConfig =
    IHyperLaneAdapter.TrustedRemotesConfig({
      originForwarder: ORIGIN_FORWARDER,
      originChainId: ORIGIN_HL_CHAIN_ID
    });

  event MessageForwarded(
    address indexed receiver,
    uint32 indexed destinationChainId,
    bytes message
  );

  event SetTrustedRemote(uint256 indexed originChainId, address indexed originForwarder);

  event HLPayloadProcessed(
    uint256 indexed originChainId,
    address indexed srcAddress,
    bytes _messageBody
  );

  function setUp() public {
    IHyperLaneAdapter.TrustedRemotesConfig[]
      memory originConfigs = new IHyperLaneAdapter.TrustedRemotesConfig[](1);
    originConfigs[0] = originConfig;

    hlAdapter = new HyperLaneAdapter(CROSS_CHAIN_CONTROLLER, MAIL_BOX, IGP, originConfigs);
  }

  function testInitialize() public {
    assertEq(hlAdapter.getTrustedRemoteByChainId(ORIGIN_HL_CHAIN_ID), ORIGIN_FORWARDER);
  }

  function testGetInfraChainFromBridgeChain() public {
    assertEq(
      hlAdapter.nativeToInfraChainId(uint32(MainnetChainIds.POLYGON)),
      MainnetChainIds.POLYGON
    );
  }

  function testGetBridgeChainFromInfraChain() public {
    assertEq(
      hlAdapter.infraToNativeChainId(MainnetChainIds.POLYGON),
      uint32(MainnetChainIds.POLYGON)
    );
  }

  function testForwardMessage() public {
    uint40 payloadId = uint40(0);
    bytes memory message = abi.encode(payloadId, CROSS_CHAIN_CONTROLLER);
    uint256 dstGasLimit = 600000;
    bytes32 messageId = keccak256(abi.encode(1));
    uint32 nativeChainId = uint32(MainnetChainIds.POLYGON);

    hoax(ADDRESS_WITH_ETH, 10 ether);
    vm.expectEmit(true, true, false, true);
    emit MessageForwarded(RECEIVER_CROSS_CHAIN_CONTROLLER, nativeChainId, message);
    vm.mockCall(
      MAIL_BOX,
      abi.encodeWithSelector(IMailbox.dispatch.selector),
      abi.encode(messageId)
    );
    vm.mockCall(
      IGP,
      abi.encodeWithSelector(
        IInterchainGasPaymaster.quoteGasPayment.selector,
        nativeChainId,
        dstGasLimit
      ),
      abi.encode(10)
    );
    vm.mockCall(
      IGP,
      10,
      abi.encodeWithSelector(
        IInterchainGasPaymaster.payForGas.selector,
        messageId,
        nativeChainId,
        dstGasLimit,
        ADDRESS_WITH_ETH
      ),
      abi.encode()
    );
    (bool success, ) = address(hlAdapter).delegatecall(
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

  function testForwardMessageWhenWrongChainId() public {
    uint40 payloadId = uint40(0);
    bytes memory message = abi.encode(payloadId, CROSS_CHAIN_CONTROLLER);
    uint256 dstGasLimit = 600000;

    vm.expectRevert(bytes(Errors.DESTINATION_CHAIN_ID_NOT_SUPPORTED));
    HyperLaneAdapter(address(hlAdapter)).forwardMessage(
      RECEIVER_CROSS_CHAIN_CONTROLLER,
      dstGasLimit,
      101234,
      message
    );
  }

  function testForwardMessageWithNoValue() public {
    uint40 payloadId = uint40(0);
    bytes memory payload = abi.encode(payloadId, CROSS_CHAIN_CONTROLLER);

    vm.expectRevert(bytes(Errors.NOT_ENOUGH_VALUE_TO_PAY_BRIDGE_FEES));
    (bool success, ) = address(hlAdapter).delegatecall(
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

    vm.expectRevert(bytes(Errors.RECEIVER_NOT_SET));
    HyperLaneAdapter(address(hlAdapter)).forwardMessage(
      address(0),
      dstGasLimit,
      MainnetChainIds.POLYGON,
      message
    );
  }

  function testHandle() public {
    uint32 originChain = uint32(1);
    bytes memory message = abi.encode('some message');

    hoax(MAIL_BOX);
    vm.expectEmit(true, true, false, true);
    emit HLPayloadProcessed(1, ORIGIN_FORWARDER, message);
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
    HyperLaneAdapter(address(hlAdapter)).handle(
      originChain,
      TypeCasts.addressToBytes32(ORIGIN_FORWARDER),
      message
    );
  }

  function testHandleWhenCallerNotMailBox() public {
    uint32 originChain = uint32(1);
    bytes memory message = abi.encode('some message');

    vm.expectRevert(bytes(Errors.CALLER_NOT_HL_MAILBOX));
    HyperLaneAdapter(address(hlAdapter)).handle(
      originChain,
      TypeCasts.addressToBytes32(ORIGIN_FORWARDER),
      message
    );
  }

  function testHandleWhenWrongOriginChain() public {
    uint32 originChain = uint32(11234);
    bytes memory message = abi.encode('some message');

    hoax(MAIL_BOX);
    vm.expectRevert(bytes(Errors.INCORRECT_ORIGIN_CHAIN_ID));
    HyperLaneAdapter(address(hlAdapter)).handle(
      originChain,
      TypeCasts.addressToBytes32(ORIGIN_FORWARDER),
      message
    );
  }

  function testHandleWhenWrongSrcAddress() public {
    uint32 originChain = uint32(1);
    bytes memory message = abi.encode('some message');

    hoax(MAIL_BOX);
    vm.expectRevert(bytes(Errors.REMOTE_NOT_TRUSTED));
    HyperLaneAdapter(address(hlAdapter)).handle(
      originChain,
      TypeCasts.addressToBytes32(address(123401741)),
      message
    );
  }
}
