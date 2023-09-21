// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {Ownable} from 'solidity-utils/contracts/oz-common/Ownable.sol';
import {CrossChainForwarder, ICrossChainForwarder} from '../src/contracts/CrossChainForwarder.sol';
import {IBaseAdapter} from '../src/contracts/adapters/IBaseAdapter.sol';
import {OwnableWithGuardian} from 'solidity-utils/contracts/access-control/OwnableWithGuardian.sol';
import {LayerZeroAdapter, ILayerZeroAdapter} from '../src/contracts/adapters/layerZero/LayerZeroAdapter.sol';
import {ILayerZeroEndpoint} from 'solidity-examples/interfaces/ILayerZeroEndpoint.sol';
import {MainnetChainIds} from '../src/contracts/libs/ChainIds.sol';
import {Errors} from '../src/contracts/libs/Errors.sol';

contract CrossChainForwarderTest is Test {
  address public constant OWNER = address(123);
  address public constant GUARDIAN = address(12);
  // mock addresses
  address public constant DESTINATION_BRIDGE_ADAPTER = address(12345);
  address public constant SENDER = address(123456);

  uint256 public constant ORIGIN_LZ_CHAIN_ID = MainnetChainIds.ETHEREUM;
  address public constant ORIGIN_SENDER = address(1234567);
  address public constant LZ_ENDPOINT = address(12345678);

  LayerZeroAdapter.TrustedRemotesConfig originConfig =
    ILayerZeroAdapter.TrustedRemotesConfig({
      originForwarder: ORIGIN_SENDER,
      originChainId: ORIGIN_LZ_CHAIN_ID
    });

  ICrossChainForwarder public crossChainForwarder;
  LayerZeroAdapter public lzAdapter;

  ICrossChainForwarder.BridgeAdapterConfigInput bridgeAdapterConfig;

  // events
  event SenderUpdated(address indexed sender, bool indexed isApproved);

  event BridgeAdapterUpdated(
    uint256 indexed destinationChainId,
    address indexed bridgeAdapter,
    address destinationBridgeAdapter,
    bool indexed allowed
  );

  function setUp() public {
    address[] memory sendersToApprove = new address[](1);
    sendersToApprove[0] = SENDER;

    crossChainForwarder = new CrossChainForwarder(
      new ICrossChainForwarder.BridgeAdapterConfigInput[](0),
      sendersToApprove
    );

    Ownable(address(crossChainForwarder)).transferOwnership(OWNER);
    OwnableWithGuardian(address(crossChainForwarder)).updateGuardian(GUARDIAN);

    // lz bridge adapter configuration
    LayerZeroAdapter.TrustedRemotesConfig[]
      memory originConfigs = new LayerZeroAdapter.TrustedRemotesConfig[](1);
    originConfigs[0] = originConfig;

    lzAdapter = new LayerZeroAdapter(LZ_ENDPOINT, address(crossChainForwarder), originConfigs);

    ICrossChainForwarder.BridgeAdapterConfigInput[]
      memory bridgeAdaptersToAllow = new ICrossChainForwarder.BridgeAdapterConfigInput[](1);
    bridgeAdapterConfig = ICrossChainForwarder.BridgeAdapterConfigInput({
      currentChainBridgeAdapter: address(lzAdapter),
      destinationBridgeAdapter: DESTINATION_BRIDGE_ADAPTER,
      destinationChainId: MainnetChainIds.POLYGON
    });
    bridgeAdaptersToAllow[0] = bridgeAdapterConfig;

    hoax(OWNER);
    crossChainForwarder.enableBridgeAdapters(bridgeAdaptersToAllow);
  }

  function testSetUp() public {
    assertEq(crossChainForwarder.getCurrentNonce(), 0);
    assertEq(Ownable(address(crossChainForwarder)).owner(), OWNER);
  }

  // TEST GETTERS
  function testIsForwarderAllowed() public {
    assertEq(crossChainForwarder.isSenderApproved(SENDER), true);
    assertEq(crossChainForwarder.isSenderApproved(OWNER), false);
  }

  function testGetBridgeAdapterByChain() public {
    ICrossChainForwarder.ChainIdBridgeConfig[] memory configs = crossChainForwarder
      .getBridgeAdaptersByChain(MainnetChainIds.POLYGON);
    assertEq(configs.length, 1);
    assertEq(configs[0].destinationBridgeAdapter, DESTINATION_BRIDGE_ADAPTER);
    assertEq(configs[0].currentChainBridgeAdapter, address(lzAdapter));
  }

  function testGetBridgeAdapterByChainWhenConfigNotSet() public {
    ICrossChainForwarder.ChainIdBridgeConfig[] memory configs = crossChainForwarder
      .getBridgeAdaptersByChain(MainnetChainIds.AVALANCHE);

    assertEq(configs.length, 0);
  }

  // TEST SETTERS
  function testApproveSenders() public {
    address[] memory newSenders = new address[](2);
    address newSender1 = address(101);
    address newSender2 = address(102);
    newSenders[0] = newSender1;
    newSenders[1] = newSender2;

    hoax(OWNER);
    vm.expectEmit(true, true, false, true);
    emit SenderUpdated(newSender1, true);
    emit SenderUpdated(newSender2, true);
    crossChainForwarder.approveSenders(newSenders);

    assertEq(crossChainForwarder.isSenderApproved(SENDER), true);
    assertEq(crossChainForwarder.isSenderApproved(newSender1), true);
    assertEq(crossChainForwarder.isSenderApproved(newSender2), true);
  }

  function testApproveSendersWhenNotOwner() public {
    address[] memory newSenders = new address[](1);
    address newSender = address(101);
    newSenders[0] = newSender;

    vm.expectRevert(bytes('Ownable: caller is not the owner'));
    crossChainForwarder.approveSenders(newSenders);
  }

  function testRemoveSenders() public {
    address[] memory newSenders = new address[](1);
    newSenders[0] = SENDER;

    hoax(OWNER);
    vm.expectEmit(true, true, false, true);
    emit SenderUpdated(SENDER, false);
    crossChainForwarder.removeSenders(newSenders);

    assertEq(crossChainForwarder.isSenderApproved(SENDER), false);
  }

  function testRemoveSendersWhenNotOwner() public {
    address[] memory newSenders = new address[](1);
    newSenders[0] = SENDER;

    vm.expectRevert(bytes('Ownable: caller is not the owner'));
    crossChainForwarder.removeSenders(newSenders);

    assertEq(crossChainForwarder.isSenderApproved(SENDER), true);
  }

  function testAllowBridgeAdaptersWhenNotOwner() public {
    ICrossChainForwarder.BridgeAdapterConfigInput[]
      memory newBridgeAdaptersToEnable = new ICrossChainForwarder.BridgeAdapterConfigInput[](0);

    vm.expectRevert(bytes('Ownable: caller is not the owner'));
    crossChainForwarder.enableBridgeAdapters(newBridgeAdaptersToEnable);
  }

  function testAllowBridgeAdapters() public {
    ICrossChainForwarder.BridgeAdapterConfigInput[]
      memory newBridgeAdaptersToEnable = new ICrossChainForwarder.BridgeAdapterConfigInput[](3);

    address NEW_BRIDGE_ADAPTER_1 = address(201);
    address NEW_BRIDGE_ADAPTER_2 = address(202);
    address NEW_DESTINATION_BRIDGE_ADAPTER_A = address(203);

    // this one overwrites
    newBridgeAdaptersToEnable[0] = ICrossChainForwarder.BridgeAdapterConfigInput({
      currentChainBridgeAdapter: address(lzAdapter),
      destinationBridgeAdapter: DESTINATION_BRIDGE_ADAPTER,
      destinationChainId: MainnetChainIds.POLYGON
    });
    // new one on same network
    newBridgeAdaptersToEnable[1] = ICrossChainForwarder.BridgeAdapterConfigInput({
      currentChainBridgeAdapter: NEW_BRIDGE_ADAPTER_1,
      destinationBridgeAdapter: DESTINATION_BRIDGE_ADAPTER,
      destinationChainId: MainnetChainIds.POLYGON
    });
    // new one on different network but same bridge adapter
    newBridgeAdaptersToEnable[2] = ICrossChainForwarder.BridgeAdapterConfigInput({
      currentChainBridgeAdapter: NEW_BRIDGE_ADAPTER_2,
      destinationBridgeAdapter: NEW_DESTINATION_BRIDGE_ADAPTER_A,
      destinationChainId: MainnetChainIds.AVALANCHE
    });

    hoax(OWNER);
    vm.expectEmit(true, true, true, true);
    emit BridgeAdapterUpdated(
      MainnetChainIds.POLYGON,
      NEW_BRIDGE_ADAPTER_1,
      DESTINATION_BRIDGE_ADAPTER,
      true
    );
    emit BridgeAdapterUpdated(
      MainnetChainIds.AVALANCHE,
      NEW_BRIDGE_ADAPTER_2,
      NEW_DESTINATION_BRIDGE_ADAPTER_A,
      true
    );
    crossChainForwarder.enableBridgeAdapters(newBridgeAdaptersToEnable);

    ICrossChainForwarder.ChainIdBridgeConfig[] memory configsPolygon = crossChainForwarder
      .getBridgeAdaptersByChain(MainnetChainIds.POLYGON);
    assertEq(configsPolygon.length, 2);
    assertEq(configsPolygon[0].destinationBridgeAdapter, DESTINATION_BRIDGE_ADAPTER);
    assertEq(configsPolygon[0].currentChainBridgeAdapter, address(lzAdapter));

    assertEq(configsPolygon[1].destinationBridgeAdapter, DESTINATION_BRIDGE_ADAPTER);
    assertEq(configsPolygon[1].currentChainBridgeAdapter, NEW_BRIDGE_ADAPTER_1);

    ICrossChainForwarder.ChainIdBridgeConfig[] memory configsAvalanche = crossChainForwarder
      .getBridgeAdaptersByChain(MainnetChainIds.AVALANCHE);
    assertEq(configsAvalanche.length, 1);
    assertEq(configsAvalanche[0].destinationBridgeAdapter, NEW_DESTINATION_BRIDGE_ADAPTER_A);
    assertEq(configsAvalanche[0].currentChainBridgeAdapter, NEW_BRIDGE_ADAPTER_2);
  }

  function testAllowBridgeAdaptersWhenNoCurrentBridgeAdapter() public {
    ICrossChainForwarder.BridgeAdapterConfigInput[]
      memory newBridgeAdaptersToEnable = new ICrossChainForwarder.BridgeAdapterConfigInput[](3);

    // this one overwrites
    newBridgeAdaptersToEnable[0] = ICrossChainForwarder.BridgeAdapterConfigInput({
      currentChainBridgeAdapter: address(0),
      destinationBridgeAdapter: DESTINATION_BRIDGE_ADAPTER,
      destinationChainId: MainnetChainIds.POLYGON
    });

    hoax(OWNER);
    vm.expectRevert(bytes(Errors.CURRENT_OR_DESTINATION_CHAIN_ADAPTER_NOT_SET));

    crossChainForwarder.enableBridgeAdapters(newBridgeAdaptersToEnable);
  }

  function testAllowBridgeAdaptersWhenNoDestinationBridgeAdapter() public {
    ICrossChainForwarder.BridgeAdapterConfigInput[]
      memory newBridgeAdaptersToEnable = new ICrossChainForwarder.BridgeAdapterConfigInput[](3);

    // this one overwrites
    newBridgeAdaptersToEnable[0] = ICrossChainForwarder.BridgeAdapterConfigInput({
      currentChainBridgeAdapter: address(lzAdapter),
      destinationBridgeAdapter: address(0),
      destinationChainId: MainnetChainIds.POLYGON
    });

    hoax(OWNER);
    vm.expectRevert(bytes(Errors.CURRENT_OR_DESTINATION_CHAIN_ADAPTER_NOT_SET));

    crossChainForwarder.enableBridgeAdapters(newBridgeAdaptersToEnable);
  }

  function testAllowBridgeAdaptersOverwrite() public {
    ICrossChainForwarder.BridgeAdapterConfigInput[]
      memory newBridgeAdaptersToEnable = new ICrossChainForwarder.BridgeAdapterConfigInput[](1);

    address NEW_DESTINATION_BRIDGE_ADAPTER_A = address(203);

    // this one overwrites
    newBridgeAdaptersToEnable[0] = ICrossChainForwarder.BridgeAdapterConfigInput({
      currentChainBridgeAdapter: address(lzAdapter),
      destinationBridgeAdapter: NEW_DESTINATION_BRIDGE_ADAPTER_A,
      destinationChainId: MainnetChainIds.POLYGON
    });

    hoax(OWNER);
    vm.expectEmit(true, true, true, true);
    emit BridgeAdapterUpdated(
      MainnetChainIds.POLYGON,
      address(lzAdapter),
      NEW_DESTINATION_BRIDGE_ADAPTER_A,
      true
    );
    crossChainForwarder.enableBridgeAdapters(newBridgeAdaptersToEnable);

    ICrossChainForwarder.ChainIdBridgeConfig[] memory configsPolygon = crossChainForwarder
      .getBridgeAdaptersByChain(MainnetChainIds.POLYGON);
    assertEq(configsPolygon.length, 1);
    assertEq(configsPolygon[0].destinationBridgeAdapter, NEW_DESTINATION_BRIDGE_ADAPTER_A);
    assertEq(configsPolygon[0].currentChainBridgeAdapter, address(lzAdapter));
  }

  function testDisallowBridgeAdapters() public {
    ICrossChainForwarder.BridgeAdapterConfigInput[]
      memory newBridgeAdaptersToEnable = new ICrossChainForwarder.BridgeAdapterConfigInput[](2);

    address NEW_BRIDGE_ADAPTER_1 = address(201);
    address NEW_DESTINATION_BRIDGE_ADAPTER_A = address(203);

    // new one on same network
    newBridgeAdaptersToEnable[0] = ICrossChainForwarder.BridgeAdapterConfigInput({
      currentChainBridgeAdapter: NEW_BRIDGE_ADAPTER_1,
      destinationBridgeAdapter: DESTINATION_BRIDGE_ADAPTER,
      destinationChainId: MainnetChainIds.POLYGON
    });
    // new one on different network but same bridge adapter
    newBridgeAdaptersToEnable[1] = ICrossChainForwarder.BridgeAdapterConfigInput({
      currentChainBridgeAdapter: address(lzAdapter),
      destinationBridgeAdapter: NEW_DESTINATION_BRIDGE_ADAPTER_A,
      destinationChainId: MainnetChainIds.AVALANCHE
    });

    hoax(OWNER);
    crossChainForwarder.enableBridgeAdapters(newBridgeAdaptersToEnable);

    ICrossChainForwarder.BridgeAdapterToDisable[]
      memory bridgeAdaptersToDisable = new ICrossChainForwarder.BridgeAdapterToDisable[](1);

    uint256[] memory chainIdsAdapter = new uint256[](2);
    chainIdsAdapter[0] = MainnetChainIds.POLYGON;
    chainIdsAdapter[1] = MainnetChainIds.AVALANCHE;

    bridgeAdaptersToDisable[0] = ICrossChainForwarder.BridgeAdapterToDisable({
      bridgeAdapter: address(lzAdapter),
      chainIds: chainIdsAdapter
    });

    hoax(OWNER);
    vm.expectEmit(true, true, false, true);
    emit BridgeAdapterUpdated(
      MainnetChainIds.POLYGON,
      address(lzAdapter),
      DESTINATION_BRIDGE_ADAPTER,
      false
    );
    emit BridgeAdapterUpdated(
      MainnetChainIds.AVALANCHE,
      address(lzAdapter),
      NEW_DESTINATION_BRIDGE_ADAPTER_A,
      false
    );
    crossChainForwarder.disableBridgeAdapters(bridgeAdaptersToDisable);

    ICrossChainForwarder.ChainIdBridgeConfig[] memory configsPolygon = crossChainForwarder
      .getBridgeAdaptersByChain(MainnetChainIds.POLYGON);
    assertEq(configsPolygon.length, 1);
    assertEq(configsPolygon[0].destinationBridgeAdapter, DESTINATION_BRIDGE_ADAPTER);
    assertEq(configsPolygon[0].currentChainBridgeAdapter, NEW_BRIDGE_ADAPTER_1);

    ICrossChainForwarder.ChainIdBridgeConfig[] memory configsAvalanche = crossChainForwarder
      .getBridgeAdaptersByChain(MainnetChainIds.AVALANCHE);
    assertEq(configsAvalanche.length, 0);
  }

  function testDisallowBridgeAdaptersWhenNotOwner() public {
    ICrossChainForwarder.BridgeAdapterToDisable[]
      memory bridgeAdaptersToDisable = new ICrossChainForwarder.BridgeAdapterToDisable[](0);

    vm.expectRevert(bytes('Ownable: caller is not the owner'));
    crossChainForwarder.disableBridgeAdapters(bridgeAdaptersToDisable);
  }

  // TEST FORWARDING MESSAGES
  function testForwardMessage() public {
    address destination = address(301);
    bytes memory message = abi.encode(0);
    bytes memory encodedMessage = abi.encode(0, SENDER, destination, message);
    uint256 beforeNonce = crossChainForwarder.getCurrentNonce();
    hoax(SENDER);
    deal(address(crossChainForwarder), 10 ether);
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
    vm.expectCall(
      address(lzAdapter),
      0,
      abi.encodeWithSelector(
        LayerZeroAdapter.forwardMessage.selector,
        DESTINATION_BRIDGE_ADAPTER,
        0,
        MainnetChainIds.POLYGON,
        encodedMessage
      )
    );
    crossChainForwarder.forwardMessage(MainnetChainIds.POLYGON, destination, 0, message);

    assertEq(
      crossChainForwarder.isMessageForwarded(MainnetChainIds.POLYGON, SENDER, destination, message),
      true
    );
    assertEq(crossChainForwarder.getCurrentNonce(), beforeNonce + 1);
  }

  function testForwardMessageWhenAllBridgesFail() public {
    address destination = address(301);
    bytes memory message = abi.encode(0);
    uint256 beforeNonce = crossChainForwarder.getCurrentNonce();
    bytes memory encodedMessage = abi.encode(beforeNonce, SENDER, destination, message);

    hoax(SENDER);
    vm.expectCall(
      address(lzAdapter),
      0,
      abi.encodeWithSelector(
        LayerZeroAdapter.forwardMessage.selector,
        DESTINATION_BRIDGE_ADAPTER,
        0,
        MainnetChainIds.POLYGON,
        encodedMessage
      )
    );
    vm.expectRevert(bytes(Errors.NO_MESSAGE_FORWARDED_SUCCESSFULLY));
    crossChainForwarder.forwardMessage(MainnetChainIds.POLYGON, destination, 0, message);

    assertEq(
      crossChainForwarder.isMessageForwarded(MainnetChainIds.POLYGON, SENDER, destination, message),
      false
    );
    assertEq(crossChainForwarder.getCurrentNonce(), beforeNonce);
  }

  function testForwardMessageWhenNotSender() public {
    address destination = address(301);
    bytes memory message = abi.encode(0);

    uint256 beforeNonce = crossChainForwarder.getCurrentNonce();

    vm.expectRevert(bytes(Errors.CALLER_IS_NOT_APPROVED_SENDER));
    crossChainForwarder.forwardMessage(MainnetChainIds.POLYGON, destination, 0, message);
    assertEq(
      crossChainForwarder.isMessageForwarded(MainnetChainIds.POLYGON, SENDER, destination, message),
      false
    );
    assertEq(crossChainForwarder.getCurrentNonce(), beforeNonce);
  }

  function testForwardMessageWithoutAdapters() public {
    address destination = address(301);
    bytes memory message = abi.encode(0);
    uint256 beforeNonce = crossChainForwarder.getCurrentNonce();

    hoax(SENDER);
    vm.expectRevert(bytes(Errors.NO_MESSAGE_FORWARDED_SUCCESSFULLY));
    crossChainForwarder.forwardMessage(MainnetChainIds.AVALANCHE, destination, 0, message);

    assertEq(
      crossChainForwarder.isMessageForwarded(MainnetChainIds.POLYGON, SENDER, destination, message),
      false
    );
    assertEq(crossChainForwarder.getCurrentNonce(), beforeNonce);
  }

  function testReForwardMessageWhenGuardian() public {
    address destination = address(301);
    bytes memory message = abi.encode(0);

    uint256 beforeNonce = crossChainForwarder.getCurrentNonce();
    deal(address(crossChainForwarder), 100 ether);

    hoax(SENDER);
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
    crossChainForwarder.forwardMessage(MainnetChainIds.POLYGON, destination, 0, message);

    bytes memory encodedMessage = abi.encode(beforeNonce + 1, SENDER, destination, message);

    hoax(GUARDIAN);
    vm.expectCall(
      address(lzAdapter),
      0,
      abi.encodeWithSelector(
        LayerZeroAdapter.forwardMessage.selector,
        DESTINATION_BRIDGE_ADAPTER,
        0,
        MainnetChainIds.POLYGON,
        encodedMessage
      )
    );
    crossChainForwarder.retryMessage(MainnetChainIds.POLYGON, SENDER, destination, 0, message);

    assertEq(
      crossChainForwarder.isMessageForwarded(MainnetChainIds.POLYGON, SENDER, destination, message),
      true
    );
    assertEq(crossChainForwarder.getCurrentNonce(), beforeNonce + 2);
  }

  function testReForwardMessageWhenOwner() public {
    address destination = address(301);
    bytes memory message = abi.encode(0);

    uint256 beforeNonce = crossChainForwarder.getCurrentNonce();
    deal(address(crossChainForwarder), 100 ether);

    hoax(SENDER);
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
    crossChainForwarder.forwardMessage(MainnetChainIds.POLYGON, destination, 0, message);

    bytes memory encodedMessage = abi.encode(beforeNonce + 1, SENDER, destination, message);

    hoax(GUARDIAN);
    vm.expectCall(
      address(lzAdapter),
      0,
      abi.encodeWithSelector(
        LayerZeroAdapter.forwardMessage.selector,
        DESTINATION_BRIDGE_ADAPTER,
        0,
        MainnetChainIds.POLYGON,
        encodedMessage
      )
    );
    crossChainForwarder.retryMessage(MainnetChainIds.POLYGON, SENDER, destination, 0, message);

    assertEq(
      crossChainForwarder.isMessageForwarded(MainnetChainIds.POLYGON, SENDER, destination, message),
      true
    );
    assertEq(crossChainForwarder.getCurrentNonce(), beforeNonce + 2);
  }

  function testReForwardMessageWhenNotPreviouslySent() public {
    address destination = address(301);
    bytes memory message = abi.encode(0);

    hoax(GUARDIAN);
    vm.expectRevert(bytes(Errors.MESSAGE_REQUIRED_TO_HAVE_BEEN_PREVIOUSLY_FORWARDED));
    crossChainForwarder.retryMessage(MainnetChainIds.POLYGON, SENDER, destination, 0, message);
  }

  function testReForwardMessageWhenNotGuardianOrOwner() public {
    address destination = address(301);
    bytes memory message = abi.encode(0);

    vm.expectRevert(bytes('ONLY_BY_OWNER_OR_GUARDIAN'));
    crossChainForwarder.retryMessage(MainnetChainIds.POLYGON, SENDER, destination, 0, message);
  }
}
