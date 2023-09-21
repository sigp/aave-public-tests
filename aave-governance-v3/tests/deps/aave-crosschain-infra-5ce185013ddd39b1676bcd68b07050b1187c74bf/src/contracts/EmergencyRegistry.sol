// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {Ownable} from 'solidity-utils/contracts/oz-common/Ownable.sol';
import {IEmergencyRegistry} from './interfaces/IEmergencyRegistry.sol';

/**
 * @title EmergencyRegistry
 * @author BGD Labs
 * @notice Registry smart contract, to be used by the Aave Governance through one of its Executors to signal if an
 *         emergency mode should be triggered on a different network
 */
contract EmergencyRegistry is IEmergencyRegistry, Ownable {
  mapping(uint256 => int256) internal _emergencyStateByNetwork;

  /// @inheritdoc IEmergencyRegistry
  function getNetworkEmergencyCount(uint256 chainId) external view returns (int256) {
    return _emergencyStateByNetwork[chainId];
  }

  /// @inheritdoc IEmergencyRegistry
  function setEmergency(uint256[] memory emergencyChains) external onlyOwner {
    for (uint256 i = 0; i < emergencyChains.length; i++) {
      unchecked {
        _emergencyStateByNetwork[emergencyChains[i]]++;
      }

      emit NetworkEmergencyStateUpdated(
        emergencyChains[i],
        _emergencyStateByNetwork[emergencyChains[i]]
      );
    }
  }
}
