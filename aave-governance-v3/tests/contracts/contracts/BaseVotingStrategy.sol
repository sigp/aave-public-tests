// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IBaseVotingStrategy} from '../interfaces/IBaseVotingStrategy.sol';
import {Errors} from './libraries/Errors.sol';

//import {AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';

/**
 * @title BaseVotingStrategy
 * @author BGD Labs
 * @notice This contract contains the base logic of a voting strategy, being on governance chain or voting machine chain.
 */
abstract contract BaseVotingStrategy is IBaseVotingStrategy {
  function AAVE() public pure virtual returns (address) {
    return 0x64033B2270fd9D6bbFc35736d2aC812942cE75fE; // edited SigP
  }

  function STK_AAVE() public pure virtual returns (address) {
    return 0xA4FDAbdE9eF3045F0dcF9221bab436B784B7e42D; // edited SigP
  }

  function A_AAVE() public pure virtual returns (address) {
    return 0x7d9EB767eEc260d1bCe8C518276a894aE5535F04; // edited SigP
  }

  uint128 public constant BASE_BALANCE_SLOT = 0;
  uint128 public constant A_AAVE_BASE_BALANCE_SLOT = 52;
  uint128 public constant A_AAVE_DELEGATED_STATE_SLOT = 64;

  /// @dev on the constructor we get all the voting assets and emit the different asset configurations
  constructor() {
    address[] memory votingAssetList = getVotingAssetList();

    // Check that voting strategy at least has one asset
    require(votingAssetList.length != 0, Errors.NO_VOTING_ASSETS);

    for (uint256 i = 0; i < votingAssetList.length; i++) {
      for (uint256 j = i + 1; j < votingAssetList.length; j++) {
        require(
          votingAssetList[i] != votingAssetList[j],
          Errors.REPEATED_STRATEGY_ASSET
        );
      }
      VotingAssetConfig memory votingAssetConfig = getVotingAssetConfig(
        votingAssetList[i]
      );

      require(
        votingAssetConfig.storageSlots.length > 0,
        Errors.EMPTY_ASSET_STORAGE_SLOTS
      );

      for (uint256 k = 0; k < votingAssetConfig.storageSlots.length; k++) {
        for (
          uint256 l = k + 1;
          l < votingAssetConfig.storageSlots.length;
          l++
        ) {
          require(
            votingAssetConfig.storageSlots[k] !=
              votingAssetConfig.storageSlots[l],
            Errors.REPEATED_STRATEGY_ASSET_SLOT
          );
        }
      }

      emit VotingAssetAdd(votingAssetList[i], votingAssetConfig.storageSlots);
    }
  }

  /// @inheritdoc IBaseVotingStrategy
  function getVotingAssetList() public pure returns (address[] memory) {
    address[] memory votingAssets = new address[](3);

    votingAssets[0] = AAVE();
    votingAssets[1] = STK_AAVE();
    votingAssets[2] = A_AAVE();

    return votingAssets;
  }

  /// @inheritdoc IBaseVotingStrategy
  function getVotingAssetConfig(
    address asset
  ) public pure returns (VotingAssetConfig memory) {
    VotingAssetConfig memory votingAssetConfig;

    if (asset == AAVE() || asset == STK_AAVE()) {
      votingAssetConfig.storageSlots = new uint128[](1);
      votingAssetConfig.storageSlots[0] = BASE_BALANCE_SLOT;
    } else if (asset == A_AAVE()) {
      votingAssetConfig.storageSlots = new uint128[](2);
      votingAssetConfig.storageSlots[0] = A_AAVE_BASE_BALANCE_SLOT;
      votingAssetConfig.storageSlots[1] = A_AAVE_DELEGATED_STATE_SLOT;
    } else {
      return votingAssetConfig;
    }

    return votingAssetConfig;
  }

  /// @inheritdoc IBaseVotingStrategy
  function isTokenSlotAccepted(
    address token,
    uint128 slot
  ) external pure returns (bool) {
    VotingAssetConfig memory votingAssetConfig = getVotingAssetConfig(token);
    for (uint256 i = 0; i < votingAssetConfig.storageSlots.length; i++) {
      if (slot == votingAssetConfig.storageSlots[i]) {
        return true;
      }
    }
    return false;
  }
}
