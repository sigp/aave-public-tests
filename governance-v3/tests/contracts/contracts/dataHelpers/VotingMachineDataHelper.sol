// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IVotingMachineWithProofs, IVotingStrategy, IDataWarehouse} from '../voting/interfaces/IVotingMachineWithProofs.sol';
import {IVotingMachineDataHelper} from './interfaces/IVotingMachineDataHelper.sol';
import {IBaseVotingStrategy} from '../../interfaces/IBaseVotingStrategy.sol';

/**
 * @title PayloadsControllerDataHelper
 * @author BGD Labs
 * @notice this contract contains the logic to get the proposals voting data.
 */
contract VotingMachineDataHelper is IVotingMachineDataHelper {
  /// @inheritdoc IVotingMachineDataHelper
  function getProposalsData(
    IVotingMachineWithProofs votingMachine,
    InitialProposal[] calldata initialProposals,
    address user
  ) external view returns (Proposal[] memory) {
    Proposal[] memory proposals = new Proposal[](initialProposals.length);
    IVotingMachineWithProofs.BridgedVote memory bridgedVote;

    Addresses memory addresses;
    addresses.votingStrategy = votingMachine.VOTING_STRATEGY();
    addresses.dataWarehouse = addresses.votingStrategy.DATA_WAREHOUSE();

    for (uint256 i = 0; i < initialProposals.length; i++) {
      proposals[i].proposalData = votingMachine.getProposalById(
        initialProposals[i].id
      );

      proposals[i].hasRequiredRoots = _hasRequiredRoots(
        addresses.votingStrategy,
        initialProposals[i].snapshotBlockHash
      );
      proposals[i].voteConfig = votingMachine.getProposalVoteConfiguration(
        initialProposals[i].id
      );

      proposals[i].strategy = addresses.votingStrategy;
      proposals[i].dataWarehouse = addresses.dataWarehouse;
      proposals[i].votingAssets = IBaseVotingStrategy(
        address(addresses.votingStrategy)
      ).getVotingAssetList();

      proposals[i].state = votingMachine.getProposalState(
        initialProposals[i].id
      );

      if (user != address(0)) {
        // direct vote
        IVotingMachineWithProofs.Vote memory vote = votingMachine
          .getUserProposalVote(user, initialProposals[i].id);

        proposals[i].votedInfo = VotedInfo({
          support: vote.support,
          votingPower: vote.votingPower
        });

        // bridged vote
        bridgedVote = votingMachine.getBridgedVoteInfo(
          initialProposals[i].id,
          user
        );
        address[] memory votingTokens = new address[](
          bridgedVote.votingAssetsWithSlot.length
        );
        for (uint256 j = 0; j < bridgedVote.votingAssetsWithSlot.length; j++) {
          votingTokens[j] = bridgedVote.votingAssetsWithSlot[j].underlyingAsset;
        }

        proposals[i].bridgedVoteInfo = BridgedVoteInfo({
          isBridgedVote: bridgedVote.votingAssetsWithSlot.length > 0,
          support: bridgedVote.support,
          votingTokens: votingTokens
        });
      }
    }

    return proposals;
  }

  function _hasRequiredRoots(
    IVotingStrategy votingStrategy,
    bytes32 snapshotBlockHash
  ) internal view returns (bool) {
    bool hasRequiredRoots;
    try votingStrategy.hasRequiredRoots(snapshotBlockHash) {
      hasRequiredRoots = true;
    } catch (bytes memory) {}

    return hasRequiredRoots;
  }
}
