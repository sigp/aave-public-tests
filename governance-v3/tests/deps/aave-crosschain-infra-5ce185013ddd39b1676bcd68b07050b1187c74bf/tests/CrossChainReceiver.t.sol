// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {Ownable} from 'solidity-utils/contracts/oz-common/Ownable.sol';
import {CrossChainReceiver, ICrossChainReceiver} from '../src/contracts/CrossChainReceiver.sol';
import {OwnableWithGuardian} from 'solidity-utils/contracts/access-control/OwnableWithGuardian.sol';
import {IBaseReceiverPortal} from '../src/contracts/interfaces/IBaseReceiverPortal.sol';
import {Errors} from '../src/contracts/libs/Errors.sol';

contract CrossChainReceiverTest is Test {
  address public constant GUARDIAN = address(12);
  address public constant OWNER = address(123);
  address public constant BRIDGE_ADAPTER = address(1234);

  address public constant GOVERNANCE_CORE = address(12345);
  address public constant VOTING_MACHINE = address(123456);

  uint256 public constant BRIDGED_CONFIRMATIONS = 1;

  ICrossChainReceiver public crossChainReceiver;

  // events
  event ConfirmationsUpdated(uint256 newConfirmations);
  event ReceiverBridgeAdaptersUpdated(address indexed brigeAdapter, bool indexed allowed);
  event MessageReceived(
    bytes32 internalId,
    address indexed bridgeAdapter,
    address indexed msgDestination,
    address indexed msgOrigin,
    bytes message,
    uint256 confirmations
  );
  event MessageConfirmed(address indexed msgDestination, address indexed msgOrigin, bytes message);
  event NewInvalidation(uint256 invalidTimestamp);

  function setUp() public {
    address[] memory bridgeAdaptersToAllow = new address[](1);
    bridgeAdaptersToAllow[0] = BRIDGE_ADAPTER;

    crossChainReceiver = new CrossChainReceiver(BRIDGED_CONFIRMATIONS, bridgeAdaptersToAllow);

    Ownable(address(crossChainReceiver)).transferOwnership(OWNER);
    OwnableWithGuardian(address(crossChainReceiver)).updateGuardian(GUARDIAN);
  }

  function testSetUp() public {
    assertEq(crossChainReceiver.getValidityTimestamp(), 0);
    assertEq(crossChainReceiver.getRequiredConfirmations(), BRIDGED_CONFIRMATIONS);
    assertEq(Ownable(address(crossChainReceiver)).owner(), OWNER);
    assertEq(OwnableWithGuardian(address(crossChainReceiver)).guardian(), GUARDIAN);
  }

  // TEST GETTERS
  function testIsReceiverBridgeAdapterAllowed() public {
    assertEq(crossChainReceiver.isReceiverBridgeAdapterAllowed(BRIDGE_ADAPTER), true);
  }

  // TEST SETTERS
  function testUpdateConfirmations() public {
    uint256 newConfirmations = 3;

    hoax(OWNER);
    vm.expectEmit(false, false, false, true);
    emit ConfirmationsUpdated(newConfirmations);
    crossChainReceiver.updateConfirmations(newConfirmations);

    assertEq(crossChainReceiver.getRequiredConfirmations(), newConfirmations);
  }

  function testUpdateConfirmationsWhenNotOwner() public {
    uint256 newConfirmations = 3;

    vm.expectRevert(bytes('Ownable: caller is not the owner'));
    crossChainReceiver.updateConfirmations(newConfirmations);

    assertEq(crossChainReceiver.getRequiredConfirmations(), BRIDGED_CONFIRMATIONS);
  }

  function testAllowReceiverBridgeAdapters() public {
    address newBridgeAdapter = address(101);
    address[] memory newBridges = new address[](1);
    newBridges[0] = newBridgeAdapter;

    hoax(OWNER);
    vm.expectEmit(true, true, false, true);
    emit ReceiverBridgeAdaptersUpdated(newBridgeAdapter, true);
    crossChainReceiver.allowReceiverBridgeAdapters(newBridges);

    assertEq(crossChainReceiver.isReceiverBridgeAdapterAllowed(newBridgeAdapter), true);
  }

  function testAllowReceiverBridgeAdaptersWhenNotOwner() public {
    address newBridgeAdapter = address(101);
    address[] memory newBridges = new address[](1);
    newBridges[0] = newBridgeAdapter;

    vm.expectRevert(bytes('Ownable: caller is not the owner'));
    crossChainReceiver.allowReceiverBridgeAdapters(newBridges);

    assertEq(crossChainReceiver.isReceiverBridgeAdapterAllowed(newBridgeAdapter), false);
  }

  function testDisallowReceiverBridgeAdapters() public {
    address[] memory disallowBridges = new address[](1);
    disallowBridges[0] = BRIDGE_ADAPTER;

    hoax(OWNER);
    vm.expectEmit(true, true, false, true);
    emit ReceiverBridgeAdaptersUpdated(BRIDGE_ADAPTER, false);
    crossChainReceiver.disallowReceiverBridgeAdapters(disallowBridges);

    assertEq(crossChainReceiver.isReceiverBridgeAdapterAllowed(BRIDGE_ADAPTER), false);
  }

  function testDisallowReceiverBridgeAdaptersWhenNotOwner() public {
    address[] memory disallowBridges = new address[](1);
    disallowBridges[0] = BRIDGE_ADAPTER;

    vm.expectRevert(bytes('Ownable: caller is not the owner'));
    crossChainReceiver.disallowReceiverBridgeAdapters(disallowBridges);

    assertEq(crossChainReceiver.isReceiverBridgeAdapterAllowed(BRIDGE_ADAPTER), true);
  }

  // TEST RECEIVE MESSAGES
  function testReceiveCrossChainMessage() public {
    uint256 nonce = 0;
    address msgOrigin = GOVERNANCE_CORE;
    address msgDestination = VOTING_MACHINE;
    bytes memory message = abi.encode('this is the message');
    bytes memory payload = abi.encode(nonce, msgOrigin, msgDestination, message);

    bytes32 internalId = keccak256(abi.encode(1, payload));

    hoax(BRIDGE_ADAPTER);
    vm.mockCall(
      msgDestination,
      abi.encodeWithSelector(IBaseReceiverPortal.receiveCrossChainMessage.selector),
      abi.encode()
    );
    vm.expectCall(
      msgDestination,
      abi.encodeWithSelector(
        IBaseReceiverPortal.receiveCrossChainMessage.selector,
        msgOrigin,
        1,
        message
      )
    );
    vm.expectEmit(true, true, true, true);
    emit MessageReceived(internalId, BRIDGE_ADAPTER, msgDestination, msgOrigin, message, 1);
    vm.expectEmit(true, true, false, true);
    emit MessageConfirmed(msgDestination, msgOrigin, message);
    crossChainReceiver.receiveCrossChainMessage(payload, 1);

    // check internal message
    assertEq(
      crossChainReceiver.isInternalMessageReceivedByAdapter(internalId, BRIDGE_ADAPTER),
      true
    );
    ICrossChainReceiver.InternalBridgedMessageStateWithoutAdapters
      memory internalMessageState = crossChainReceiver.getInternalMessageState(internalId);

    assertEq(internalMessageState.confirmations, 1);
    assertEq(internalMessageState.firstBridgedAt, block.timestamp);
    assertEq(internalMessageState.delivered, true);
  }

  function testReceiveCrossChainMessageWhenCallerNotBridge() public {
    uint256 nonce = 0;
    address msgOrigin = GOVERNANCE_CORE;
    address msgDestination = VOTING_MACHINE;
    bytes memory message = abi.encode('this is the message');
    bytes memory payload = abi.encode(nonce, msgOrigin, msgDestination, message);

    vm.expectRevert(bytes(Errors.CALLER_NOT_APPROVED_BRIDGE));
    crossChainReceiver.receiveCrossChainMessage(payload, 1);
  }

  function testReceiveMessageButNotConfirmation() public {
    uint256 newConfirmations = 2;
    address newAdapter = address(201);
    address[] memory newAdapters = new address[](1);
    newAdapters[0] = newAdapter;
    vm.startPrank(OWNER);
    crossChainReceiver.updateConfirmations(newConfirmations);
    crossChainReceiver.allowReceiverBridgeAdapters(newAdapters);
    vm.stopPrank();

    uint256 nonce = 0;
    address msgOrigin = GOVERNANCE_CORE;
    address msgDestination = VOTING_MACHINE;
    bytes memory message = abi.encode('this is the message');
    bytes memory payload = abi.encode(nonce, msgOrigin, msgDestination, message);

    bytes32 internalId = keccak256(abi.encode(1, payload));

    hoax(BRIDGE_ADAPTER);
    vm.expectEmit(true, true, true, true);
    emit MessageReceived(internalId, BRIDGE_ADAPTER, msgDestination, msgOrigin, message, 1);
    crossChainReceiver.receiveCrossChainMessage(payload, 1);

    // check internal message
    assertEq(
      crossChainReceiver.isInternalMessageReceivedByAdapter(internalId, BRIDGE_ADAPTER),
      true
    );
    ICrossChainReceiver.InternalBridgedMessageStateWithoutAdapters
      memory internalMessageState = crossChainReceiver.getInternalMessageState(internalId);

    assertEq(internalMessageState.confirmations, 1);
    assertEq(internalMessageState.firstBridgedAt, block.timestamp);
    assertEq(internalMessageState.delivered, false);

    hoax(newAdapter);
    vm.mockCall(
      msgDestination,
      abi.encodeWithSelector(IBaseReceiverPortal.receiveCrossChainMessage.selector),
      abi.encode()
    );
    vm.expectCall(
      msgDestination,
      abi.encodeWithSelector(
        IBaseReceiverPortal.receiveCrossChainMessage.selector,
        msgOrigin,
        1,
        message
      )
    );
    vm.expectEmit(true, true, true, true);
    emit MessageReceived(internalId, newAdapter, msgDestination, msgOrigin, message, 2);
    vm.expectEmit(true, true, false, true);
    emit MessageConfirmed(msgDestination, msgOrigin, message);
    crossChainReceiver.receiveCrossChainMessage(payload, 1);

    //     check internal message
    assertEq(crossChainReceiver.isInternalMessageReceivedByAdapter(internalId, address(201)), true);
    ICrossChainReceiver.InternalBridgedMessageStateWithoutAdapters
      memory internalMessageState2 = crossChainReceiver.getInternalMessageState(internalId);

    assertEq(internalMessageState2.confirmations, 2);
    assertEq(internalMessageState2.firstBridgedAt, block.timestamp);
    assertEq(internalMessageState2.delivered, true);
  }

  // TEST INVALIDATIONS
  function testInvalidatePreviousMessages() public {
    uint120 timestamp = uint120(block.timestamp);
    hoax(OWNER);
    vm.expectEmit(false, false, false, true);
    emit NewInvalidation(timestamp);
    crossChainReceiver.updateMessagesValidityTimestamp(timestamp);

    assertEq(crossChainReceiver.getValidityTimestamp(), timestamp);
  }

  function testInvalidatePreviousMessagesWhenNotOwner() public {
    uint120 timestamp = uint120(block.timestamp);
    vm.expectRevert(bytes('Ownable: caller is not the owner'));
    crossChainReceiver.updateMessagesValidityTimestamp(timestamp);

    assertEq(crossChainReceiver.getValidityTimestamp(), uint120(0));
  }

  function testInvalidatePreviousMessagesWhenPastTimestamp() public {
    uint120 timestamp = uint120(block.timestamp);
    hoax(OWNER);
    vm.expectEmit(false, false, false, true);
    emit NewInvalidation(timestamp);
    crossChainReceiver.updateMessagesValidityTimestamp(timestamp);

    assertEq(crossChainReceiver.getValidityTimestamp(), timestamp);

    hoax(OWNER);
    vm.expectRevert(bytes(Errors.TIMESTAMP_ALREADY_PASSED));
    crossChainReceiver.updateMessagesValidityTimestamp(uint120(timestamp - 1));

    assertEq(crossChainReceiver.getValidityTimestamp(), timestamp);
  }

  function testInvalidation() public {
    uint256 newConfirmations = 2;
    address newAdapter = address(201);
    address[] memory newAdapters = new address[](1);
    newAdapters[0] = newAdapter;
    vm.startPrank(OWNER);
    crossChainReceiver.updateConfirmations(newConfirmations);
    crossChainReceiver.allowReceiverBridgeAdapters(newAdapters);
    vm.stopPrank();

    uint256 nonce = 0;
    address msgOrigin = GOVERNANCE_CORE;
    address msgDestination = VOTING_MACHINE;
    bytes memory message = abi.encode('this is the message');
    bytes memory payload = abi.encode(nonce, msgOrigin, msgDestination, message);

    bytes32 internalId = keccak256(abi.encode(1, payload));

    // send message
    hoax(BRIDGE_ADAPTER);
    crossChainReceiver.receiveCrossChainMessage(payload, 1);

    // check internal message
    assertEq(
      crossChainReceiver.isInternalMessageReceivedByAdapter(internalId, BRIDGE_ADAPTER),
      true
    );
    ICrossChainReceiver.InternalBridgedMessageStateWithoutAdapters
      memory internalMessageState = crossChainReceiver.getInternalMessageState(internalId);
    assertEq(internalMessageState.confirmations, 1);

    // invalidate
    hoax(OWNER);
    crossChainReceiver.updateMessagesValidityTimestamp(
      uint120(internalMessageState.firstBridgedAt + 1)
    );

    skip(10);

    // send message with same nonce from other adapter
    hoax(newAdapter);
    crossChainReceiver.receiveCrossChainMessage(payload, 1);
    ICrossChainReceiver.InternalBridgedMessageStateWithoutAdapters
      memory internalMessageStateAfter = crossChainReceiver.getInternalMessageState(internalId);

    assertEq(internalMessageStateAfter.confirmations, 1);

    // send message with new nonce
    bytes memory payloadWithNewNonce = abi.encode(nonce + 1, msgOrigin, msgDestination, message);

    bytes32 internalIdNonce = keccak256(abi.encode(1, payloadWithNewNonce));

    hoax(BRIDGE_ADAPTER);
    crossChainReceiver.receiveCrossChainMessage(payloadWithNewNonce, 1);
    ICrossChainReceiver.InternalBridgedMessageStateWithoutAdapters
      memory internalMessageStateNonce = crossChainReceiver.getInternalMessageState(
        internalIdNonce
      );

    assertEq(internalMessageStateNonce.confirmations, 1);
  }
}
