// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ICrossChainForwarder} from 'aave-crosschain-infra/contracts/interfaces/ICrossChainForwarder.sol';
import {GovernanceCore, PayloadsControllerUtils} from './GovernanceCore.sol';
import {IGovernance, IGovernancePowerStrategy, IGovernanceCore} from '../interfaces/IGovernance.sol';
import {Errors} from './libraries/Errors.sol';

/**
 * @title Governance
 * @author BGD Labs
 * @notice this contract contains the logic to communicate with execution chain.
 * @dev This contract implements the abstract contract GovernanceCore
 */
contract Governance is GovernanceCore, IGovernance {
  /// @inheritdoc IGovernance
  address public immutable CROSS_CHAIN_CONTROLLER;

  // gas limit used for sending the vote result
  uint256 private _gasLimit;

  /**
   * @param crossChainController address of current network message controller (cross chain controller or same chain controller)
   * @param coolDownPeriod time that should pass before proposal will be moved to vote, in seconds
   */
  constructor(
    address crossChainController,
    uint256 coolDownPeriod
  ) GovernanceCore(coolDownPeriod) {
    require(
      crossChainController != address(0),
      Errors.G_INVALID_CROSS_CHAIN_CONTROLLER_ADDRESS
    );
    CROSS_CHAIN_CONTROLLER = crossChainController;
  }

  /// @inheritdoc IGovernance
  function initialize(
    address owner,
    address guardian,
    IGovernancePowerStrategy powerStrategy,
    IGovernanceCore.SetVotingConfigInput[] calldata votingConfigs,
    address[] calldata votingPortals,
    uint256 gasLimit
  ) external initializer {
    _initializeCore(
      owner,
      guardian,
      powerStrategy,
      votingConfigs,
      votingPortals
    );
    _updateGasLimit(gasLimit);
  }

  /// @inheritdoc IGovernance
  function getGasLimit() external view returns (uint256) {
    return _gasLimit;
  }

  /// @inheritdoc IGovernance
  function updateGasLimit(uint256 gasLimit) external onlyOwner {
    _updateGasLimit(gasLimit);
  }

  /**
   * @notice method to send a payload to execution chain
   * @param payload object with the information needed for execution
   * @param proposalVoteActivationTimestamp proposal vote activation timestamp in seconds
   */
  function _forwardPayloadForExecution(
    PayloadsControllerUtils.Payload memory payload,
    uint40 proposalVoteActivationTimestamp
  ) internal override {
    ICrossChainForwarder(CROSS_CHAIN_CONTROLLER).forwardMessage(
      payload.chain,
      payload.payloadsController,
      _gasLimit,
      abi.encode(
        payload.payloadId,
        payload.accessLevel,
        proposalVoteActivationTimestamp
      )
    );
  }

  /**
   * @notice method to update the gasLimit
   * @param gasLimit the new gas limit
   */
  function _updateGasLimit(uint256 gasLimit) internal {
    _gasLimit = gasLimit;

    emit GasLimitUpdated(gasLimit);
  }
}
