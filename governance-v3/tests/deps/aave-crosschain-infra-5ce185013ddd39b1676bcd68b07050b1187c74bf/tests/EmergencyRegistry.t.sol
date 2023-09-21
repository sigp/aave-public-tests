// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {IEmergencyRegistry} from 'src/contracts/interfaces/IEmergencyRegistry.sol';
import {EmergencyRegistry} from 'src/contracts/EmergencyRegistry.sol';

contract EmergencyRegistryTest is Test {
  uint256 public constant AVALANCHE_CHAIN_ID = 43114;
  uint256 public constant POLYGON_CHAIN_ID = 137;
  IEmergencyRegistry public emergencyRegistry;

  event NetworkEmergencyStateUpdated(uint256 indexed chainId, int256 emergencyNumber);

  function setUp() public {
    emergencyRegistry = new EmergencyRegistry();
  }

  function testSetEmergency() public {
    uint256[] memory chains = new uint256[](1);
    chains[0] = AVALANCHE_CHAIN_ID;

    vm.expectEmit(true, false, false, true);
    emit NetworkEmergencyStateUpdated(AVALANCHE_CHAIN_ID, int256(1));
    emergencyRegistry.setEmergency(chains);
  }

  function testSetEmergencyWhenNotOwner() public {
    uint256[] memory chains = new uint256[](1);
    chains[0] = AVALANCHE_CHAIN_ID;

    hoax(address(12));
    vm.expectRevert(bytes('Ownable: caller is not the owner'));
    emergencyRegistry.setEmergency(chains);
  }

  function testGetnetworkEmergencyCount() public {
    uint256[] memory chains0 = new uint256[](1);
    chains0[0] = AVALANCHE_CHAIN_ID;

    uint256[] memory chains1 = new uint256[](2);
    chains1[0] = AVALANCHE_CHAIN_ID;
    chains1[1] = POLYGON_CHAIN_ID;

    emergencyRegistry.setEmergency(chains0);

    int256 emergency0 = emergencyRegistry.getNetworkEmergencyCount(AVALANCHE_CHAIN_ID);

    emergencyRegistry.setEmergency(chains1);

    int256 emergency1 = emergencyRegistry.getNetworkEmergencyCount(AVALANCHE_CHAIN_ID);
    int256 emergency2 = emergencyRegistry.getNetworkEmergencyCount(POLYGON_CHAIN_ID);

    assertEq(emergency0, int256(1));
    assertEq(emergency1, int256(2));
    assertEq(emergency2, int256(1));
  }
}
