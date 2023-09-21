// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {LayerZeroAdapter} from '../../src/contracts/adapters/layerZero/LayerZeroAdapter.sol';
import {ICrossChainReceiver} from '../../src/contracts/interfaces/ICrossChainReceiver.sol';
import {ILayerZeroEndpoint} from 'solidity-examples/interfaces/ILayerZeroEndpoint.sol';
import {IBaseAdapter} from '../../src/contracts/adapters/IBaseAdapter.sol';
import {ILayerZeroAdapter} from '../../src/contracts/adapters/layerZero/ILayerZeroAdapter.sol';
import {MainnetChainIds} from '../../src/contracts/libs/ChainIds.sol';
import {Errors} from '../../src/contracts/libs/Errors.sol';

contract LayerZeroAdapterTest is Test {
  uint256 public constant ORIGIN_LZ_CHAIN_ID = 1;
  address public constant ORIGIN_FORWARDER = address(1234);
  address public constant LZ_ENDPOINT = address(12345);
  address public constant CROSS_CHAIN_CONTROLLER = address(1234567);
  address public constant RECEIVER_CROSS_CHAIN_CONTROLLER = address(12345678);
  address public constant ADDRESS_WITH_ETH = address(12301234);
  uint16 public constant BRIDGE_CHAIN_ID = uint16(109);

  LayerZeroAdapter layerZeroAdapter;

  ILayerZeroAdapter.TrustedRemotesConfig originConfig =
    ILayerZeroAdapter.TrustedRemotesConfig({
      originForwarder: ORIGIN_FORWARDER,
      originChainId: ORIGIN_LZ_CHAIN_ID
    });

  event LZPayloadProcessed(
    uint256 indexed lzChainId,
    uint64 nonce,
    address indexed sender,
    bytes payload
  );
  event MessageForwarded(
    address indexed receiver,
    uint16 indexed destinationChainId,
    bytes message,
    uint256 nonce
  );

  function setUp() public {
    ILayerZeroAdapter.TrustedRemotesConfig[]
      memory originConfigs = new ILayerZeroAdapter.TrustedRemotesConfig[](1);
    originConfigs[0] = originConfig;

    layerZeroAdapter = new LayerZeroAdapter(LZ_ENDPOINT, CROSS_CHAIN_CONTROLLER, originConfigs);
  }

  function testAddressToBytes() public {
    address testAddress = 0x38090646D10B5af11D86D1Bb894CF02E98dFd33A;
    address local = 0x7d2105868e4bA9A1C296080f5F2f17ed4e610d9D;
    //0x38090646d10b5af11d86d1bb894cf02e98dfd33a7d2105868e4ba9a1c296080f5f2f17ed4e610d9d
    //0x38090646d10b5af11d86d1bb894cf02e98dfd33a7d2105868e4ba9a1c296080f5f2f17ed4e610d9d

    emit log_bytes(abi.encodePacked(testAddress, local));
  }

  function testInit() public {
    bytes memory bytesOrigin = layerZeroAdapter.trustedRemoteLookup(uint16(101));
    address originForwarder;
    assembly {
      originForwarder := mload(add(bytesOrigin, 20))
    }

    assertEq(originForwarder, ORIGIN_FORWARDER);
    assertEq(address(layerZeroAdapter.lzEndpoint()), LZ_ENDPOINT);
  }

  function testGetInfraChainFromBridgeChain() public {
    assertEq(layerZeroAdapter.nativeToInfraChainId(BRIDGE_CHAIN_ID), MainnetChainIds.POLYGON);
  }

  function testGetBridgeChainFromInfraChain() public {
    assertEq(layerZeroAdapter.infraToNativeChainId(MainnetChainIds.POLYGON), BRIDGE_CHAIN_ID);
  }

  function testLzReceive() public {
    bytes memory srcAddress = abi.encodePacked(ORIGIN_FORWARDER, address(layerZeroAdapter));
    uint64 nonce = uint64(1);

    uint40 payloadId = 0;

    bytes memory payload = abi.encode(payloadId, CROSS_CHAIN_CONTROLLER);

    hoax(LZ_ENDPOINT);
    vm.mockCall(
      CROSS_CHAIN_CONTROLLER,
      abi.encodeWithSelector(ICrossChainReceiver.receiveCrossChainMessage.selector),
      abi.encode()
    );
    vm.expectCall(
      CROSS_CHAIN_CONTROLLER,
      0,
      abi.encodeWithSelector(ICrossChainReceiver.receiveCrossChainMessage.selector, payload, 1)
    );
    vm.expectEmit(true, false, true, true);
    emit LZPayloadProcessed(ORIGIN_LZ_CHAIN_ID, nonce, ORIGIN_FORWARDER, payload);
    layerZeroAdapter.lzReceive(101, srcAddress, nonce, payload);
    vm.clearMockedCalls();
  }

  function testLzReceiveWhenNotEndpoint() public {
    bytes memory srcAddress = abi.encode(ORIGIN_FORWARDER);
    uint64 nonce = uint64(1);

    uint40 payloadId = uint40(0);

    bytes memory payload = abi.encode(payloadId, CROSS_CHAIN_CONTROLLER);

    vm.expectRevert(bytes('LzApp: invalid endpoint caller'));
    layerZeroAdapter.lzReceive(101, srcAddress, nonce, payload);
  }

  function testLzReceiveWhenIncorrectSource() public {
    bytes memory srcAddress = abi.encode(address(213450897265));
    uint64 nonce = uint64(1);

    uint40 payloadId = uint40(0);

    bytes memory payload = abi.encode(payloadId, CROSS_CHAIN_CONTROLLER);

    hoax(LZ_ENDPOINT);
    vm.expectRevert(bytes('LzApp: invalid source sending contract'));
    layerZeroAdapter.lzReceive(101, srcAddress, nonce, payload);
  }

  function testForwardPayload() public {
    uint40 payloadId = uint40(0);
    bytes memory payload = abi.encode(payloadId, CROSS_CHAIN_CONTROLLER);

    hoax(ADDRESS_WITH_ETH, 10 ether);
    vm.expectEmit(true, true, false, true);
    emit MessageForwarded(RECEIVER_CROSS_CHAIN_CONTROLLER, 109, payload, 1);
    vm.mockCall(
      LZ_ENDPOINT,
      abi.encodeWithSelector(ILayerZeroEndpoint.estimateFees.selector),
      abi.encode(10, 0)
    );
    vm.mockCall(
      LZ_ENDPOINT,
      abi.encodeWithSelector(ILayerZeroEndpoint.getOutboundNonce.selector),
      abi.encode(1)
    );
    vm.mockCall(
      LZ_ENDPOINT,
      10,
      abi.encodeWithSelector(ILayerZeroEndpoint.send.selector),
      abi.encode()
    );
    (bool success, ) = address(layerZeroAdapter).delegatecall(
      abi.encodeWithSelector(
        IBaseAdapter.forwardMessage.selector,
        RECEIVER_CROSS_CHAIN_CONTROLLER,
        0,
        MainnetChainIds.POLYGON,
        payload
      )
    );
    vm.clearMockedCalls();

    assertEq(success, true);
  }

  function testForwardPayloadWithNoValue() public {
    uint40 payloadId = uint40(0);
    bytes memory payload = abi.encode(payloadId, CROSS_CHAIN_CONTROLLER);

    vm.expectRevert(bytes(Errors.NOT_ENOUGH_VALUE_TO_PAY_BRIDGE_FEES));
    (bool success, ) = address(layerZeroAdapter).delegatecall(
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

  function testForwardPayloadWhenNoChainSet() public {
    uint40 payloadId = uint40(0);
    bytes memory payload = abi.encode(payloadId, CROSS_CHAIN_CONTROLLER);

    vm.expectRevert(bytes(Errors.DESTINATION_CHAIN_ID_NOT_SUPPORTED));
    layerZeroAdapter.forwardMessage(RECEIVER_CROSS_CHAIN_CONTROLLER, 0, 102345, payload);
  }

  function testForwardPayloadWhenNoReceiverSet() public {
    uint40 payloadId = uint40(0);
    bytes memory payload = abi.encode(payloadId, CROSS_CHAIN_CONTROLLER);
    vm.expectRevert(bytes(Errors.RECEIVER_NOT_SET));
    layerZeroAdapter.forwardMessage(address(0), 0, MainnetChainIds.POLYGON, payload);
  }
}
