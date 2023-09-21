// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {Ownable} from 'solidity-utils/contracts/oz-common/Ownable.sol';
import {Address} from 'solidity-utils/contracts/oz-common/Address.sol';
import {OwnableWithGuardian} from 'solidity-utils/contracts/access-control/OwnableWithGuardian.sol';
import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';
import {ERC20} from './mocks/ERC20.sol';
import {CrossChainController} from 'src/contracts/CrossChainController.sol';
import {ICrossChainController, ICrossChainForwarder} from 'src/contracts/interfaces/ICrossChainController.sol';
import {TransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/TransparentProxyFactory.sol';
import {ICLEmergencyOracle} from 'solidity-utils/contracts/emergency/interfaces/ICLEmergencyOracle.sol';
import {MainnetChainIds} from '../src/contracts/libs/ChainIds.sol';

contract CrossChainControllerTest is Test {
  address public constant OWNER = address(123);
  address public constant GUARDIAN = address(1234);
  address public constant CL_EMERGENCY_ORACLE = address(12345);

  uint256 public constant CONFIRMATIONS = 1;

  TransparentProxyFactory public proxyFactory;
  ICrossChainController public crossChainController;

  bytes32 public constant PROXY_ADMIN_SALT = keccak256('proxy admin salt');
  bytes32 public constant CROSS_CHAIN_CONTROLLER_SALT = keccak256('cross chain controller salt');

  IERC20 public testToken;

  event CLEmergencyOracleUpdated(address indexed newChainlinkEmergencyOracle);

  function setUp() public {
    testToken = new ERC20('Test', 'TST');
    proxyFactory = new TransparentProxyFactory();

    // deploy admin if not deployed before
    address proxyAdmin = proxyFactory.createDeterministicProxyAdmin(OWNER, PROXY_ADMIN_SALT);

    address[] memory receiverBridgeAdaptersToAllow = new address[](1);
    receiverBridgeAdaptersToAllow[0] = address(101);
    address[] memory sendersToApprove = new address[](1);
    sendersToApprove[0] = address(102);
    ICrossChainForwarder.BridgeAdapterConfigInput[]
      memory forwarderBridgeAdaptersToEnable = new ICrossChainForwarder.BridgeAdapterConfigInput[](
        1
      );
    forwarderBridgeAdaptersToEnable[0] = ICrossChainForwarder.BridgeAdapterConfigInput({
      currentChainBridgeAdapter: address(103),
      destinationBridgeAdapter: address(110),
      destinationChainId: MainnetChainIds.POLYGON
    });

    ICrossChainController crossChainControllerImpl = new CrossChainController(
      CL_EMERGENCY_ORACLE,
      CONFIRMATIONS,
      receiverBridgeAdaptersToAllow,
      forwarderBridgeAdaptersToEnable,
      sendersToApprove
    );

    crossChainController = ICrossChainController(
      proxyFactory.createDeterministic(
        address(crossChainControllerImpl),
        proxyAdmin,
        abi.encodeWithSelector(
          ICrossChainController.initialize.selector,
          OWNER,
          GUARDIAN,
          CL_EMERGENCY_ORACLE,
          CONFIRMATIONS,
          receiverBridgeAdaptersToAllow,
          forwarderBridgeAdaptersToEnable,
          sendersToApprove
        ),
        CROSS_CHAIN_CONTROLLER_SALT
      )
    );
  }

  function testOwnership() public {
    assertEq(Ownable(address(crossChainController)).owner(), OWNER);
    assertEq(OwnableWithGuardian(address(crossChainController)).guardian(), GUARDIAN);
  }

  function testEmergencyEtherTransfer() public {
    address randomWallet = address(1239516);
    hoax(randomWallet, 50 ether);
    Address.sendValue(payable(address(crossChainController)), 5 ether);

    assertEq(address(crossChainController).balance, 5 ether);

    address recipient = address(1230123519);

    hoax(OWNER);
    crossChainController.emergencyEtherTransfer(recipient, 5 ether);

    assertEq(address(crossChainController).balance, 0 ether);
    assertEq(address(recipient).balance, 5 ether);
  }

  function testEmergencyEtherTransferWhenNotOwner() public {
    address randomWallet = address(1239516);

    hoax(randomWallet, 50 ether);
    Address.sendValue(payable(address(crossChainController)), 5 ether);

    assertEq(address(crossChainController).balance, 5 ether);

    address recipient = address(1230123519);

    vm.expectRevert((bytes('Ownable: caller is not the owner')));
    crossChainController.emergencyEtherTransfer(recipient, 5 ether);
  }

  function testEmergencyTokenTransfer() public {
    address randomWallet = address(1239516);
    deal(address(testToken), randomWallet, 10 ether);
    hoax(randomWallet);
    testToken.transfer(address(crossChainController), 3 ether);

    assertEq(testToken.balanceOf(address(crossChainController)), 3 ether);

    address recipient = address(1230123519);

    hoax(OWNER);
    crossChainController.emergencyTokenTransfer(address(testToken), recipient, 3 ether);

    assertEq(testToken.balanceOf(address(crossChainController)), 0);
    assertEq(testToken.balanceOf(address(recipient)), 3 ether);
  }

  function testEmergencyTokenTransferWhenNotOwner() public {
    address randomWallet = address(1239516);
    deal(address(testToken), randomWallet, 10 ether);
    hoax(randomWallet);
    testToken.transfer(address(crossChainController), 3 ether);

    assertEq(testToken.balanceOf(address(crossChainController)), 3 ether);

    address recipient = address(1230123519);

    vm.expectRevert((bytes('Ownable: caller is not the owner')));
    crossChainController.emergencyTokenTransfer(address(testToken), recipient, 3 ether);
  }

  function testSolveEmergency() public {
    uint256 newConfirmations = 3;
    uint120 newValidityTimestamp = uint120(block.timestamp + 5);
    address[] memory receiverBridgeAdaptersToAllow = new address[](1);
    receiverBridgeAdaptersToAllow[0] = address(201);
    address[] memory receiverBridgeAdaptersToDisallow = new address[](1);
    receiverBridgeAdaptersToDisallow[0] = address(101);
    address[] memory sendersToApprove = new address[](1);
    sendersToApprove[0] = address(202);
    address[] memory sendersToRemove = new address[](1);
    sendersToRemove[0] = address(102);
    ICrossChainForwarder.BridgeAdapterConfigInput[]
      memory forwarderBridgeAdaptersToEnable = new ICrossChainForwarder.BridgeAdapterConfigInput[](
        1
      );
    forwarderBridgeAdaptersToEnable[0] = ICrossChainForwarder.BridgeAdapterConfigInput({
      currentChainBridgeAdapter: address(203),
      destinationBridgeAdapter: address(210),
      destinationChainId: MainnetChainIds.POLYGON
    });
    ICrossChainForwarder.BridgeAdapterToDisable[]
      memory forwarderBridgeAdaptersToDisable = new ICrossChainForwarder.BridgeAdapterToDisable[](
        1
      );
    uint256[] memory chainIds = new uint256[](1);
    chainIds[0] = MainnetChainIds.POLYGON;
    forwarderBridgeAdaptersToDisable[0] = ICrossChainForwarder.BridgeAdapterToDisable({
      bridgeAdapter: address(103),
      chainIds: chainIds
    });

    hoax(GUARDIAN);
    vm.mockCall(
      CL_EMERGENCY_ORACLE,
      abi.encodeWithSelector(ICLEmergencyOracle.latestRoundData.selector),
      abi.encode(uint80(0), int256(1), 0, 0, uint80(0))
    );
    crossChainController.solveEmergency(
      newConfirmations,
      newValidityTimestamp,
      receiverBridgeAdaptersToAllow,
      receiverBridgeAdaptersToDisallow,
      sendersToApprove,
      sendersToRemove,
      forwarderBridgeAdaptersToEnable,
      forwarderBridgeAdaptersToDisable
    );

    assertEq(crossChainController.getRequiredConfirmations(), newConfirmations);
    assertEq(crossChainController.getValidityTimestamp(), newValidityTimestamp);
    assertEq(crossChainController.isReceiverBridgeAdapterAllowed(address(201)), true);
    assertEq(crossChainController.isReceiverBridgeAdapterAllowed(address(101)), false);
    assertEq(crossChainController.isSenderApproved(address(202)), true);
    assertEq(crossChainController.isSenderApproved(address(102)), false);

    ICrossChainForwarder.ChainIdBridgeConfig[] memory forwarderBridgeAdapters = crossChainController
      .getBridgeAdaptersByChain(MainnetChainIds.POLYGON);

    assertEq(forwarderBridgeAdapters.length, 1);
    assertEq(forwarderBridgeAdapters[0].destinationBridgeAdapter, address(210));
    assertEq(forwarderBridgeAdapters[0].currentChainBridgeAdapter, address(203));
  }

  function testSolveEmergencyWhenNotGuardian() public {
    vm.expectRevert(bytes('ONLY_BY_GUARDIAN'));
    crossChainController.solveEmergency(
      0,
      uint120(0),
      new address[](0),
      new address[](0),
      new address[](0),
      new address[](0),
      new ICrossChainForwarder.BridgeAdapterConfigInput[](0),
      new ICrossChainForwarder.BridgeAdapterToDisable[](0)
    );
  }

  function testSolveEmergencyWhenGuardianNotEmergencyMode() public {
    uint80 roundId = uint80(0);
    int256 answer = int256(0);
    uint256 startedAt = 0;
    uint256 updatedAt = 0;
    uint80 answeredInRound = uint80(0);

    hoax(GUARDIAN);
    vm.mockCall(
      CL_EMERGENCY_ORACLE,
      abi.encodeWithSelector(ICLEmergencyOracle.latestRoundData.selector),
      abi.encode(roundId, answer, startedAt, updatedAt, answeredInRound)
    );
    vm.expectRevert(bytes('NOT_IN_EMERGENCY'));
    crossChainController.solveEmergency(
      0,
      uint120(0),
      new address[](0),
      new address[](0),
      new address[](0),
      new address[](0),
      new ICrossChainForwarder.BridgeAdapterConfigInput[](0),
      new ICrossChainForwarder.BridgeAdapterToDisable[](0)
    );
  }

  function testUpdateCLEmergencyOracle() public {
    address newChainlinkEmergencyOracle = address(101);

    hoax(OWNER);
    vm.expectEmit(true, false, false, true);
    emit CLEmergencyOracleUpdated(newChainlinkEmergencyOracle);
    CrossChainController(payable(address(crossChainController))).updateCLEmergencyOracle(
      newChainlinkEmergencyOracle
    );

    assertEq(
      CrossChainController(payable(address(crossChainController))).getChainlinkEmergencyOracle(),
      newChainlinkEmergencyOracle
    );
  }

  function testUpdateCLEmergencyOracleWhenNotOwner() public {
    address newChainlinkEmergencyOracle = address(101);

    vm.expectRevert(bytes('Ownable: caller is not the owner'));
    CrossChainController(payable(address(crossChainController))).updateCLEmergencyOracle(
      newChainlinkEmergencyOracle
    );

    assertEq(
      CrossChainController(payable(address(crossChainController))).getChainlinkEmergencyOracle(),
      CL_EMERGENCY_ORACLE
    );
  }
}
