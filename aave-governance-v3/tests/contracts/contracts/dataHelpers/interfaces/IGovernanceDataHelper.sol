// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PayloadsControllerUtils} from '../../payloads/PayloadsControllerUtils.sol';
import {IGovernanceCore} from '../../../interfaces/IGovernanceCore.sol';

/**
 * @title IGovernanceDataHelper
 * @author BGD Labs
 * @notice interface containing the objects, events and methods definitions of the GovernanceDataHelper contract
 */
interface IGovernanceDataHelper {
  struct Proposal {
    uint256 id;
    uint256 votingChainId;
    IGovernanceCore.Proposal proposalData;
  }

  /**
   * @notice Object storing the vote configuration for a specific access level
   * @param accessLevel access level of the configuration
   * @param config voting configuration
   */
  struct VotingConfig {
    PayloadsControllerUtils.AccessControl accessLevel;
    IGovernanceCore.VotingConfig config;
  }

  /**
   * @notice Object storing the vote configuration for a specific access level
   * @param accessLevel access level of the configuration
   * @param config voting configuration
   */
  struct Constants {
    VotingConfig[] votingConfigs;
    uint256 precisionDivider;
    uint256 cooldownPeriod;
    uint256 expirationTime;
  }

  /**
   * @notice method to get proposals list
   * @param govCore instance of the goverment core contract
   * @param from proposal number to start fetching from
   * @param to proposal number to end fetching
   * @param pageSize size of the page to get
   * @return list of the proposals
   */
  function getProposalsData(
    IGovernanceCore govCore,
    uint256 from,
    uint256 to,
    uint256 pageSize
  ) external view returns (Proposal[] memory);

  /**
   * @notice method to get voting config and governance setup constants
   * @param govCore instance of the goverment core contract
   * @param accessLevels list of the access levels to retreive votings configs for
   * @return list of the voting configs and values of the governance constants
   */
  function getConstants(
    IGovernanceCore govCore,
    PayloadsControllerUtils.AccessControl[] calldata accessLevels
  ) external view returns (Constants memory);
}
