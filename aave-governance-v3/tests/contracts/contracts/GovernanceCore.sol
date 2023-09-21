// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Initializable} from 'solidity-utils/contracts/transparent-proxy/Initializable.sol';
import {OwnableWithGuardian} from 'solidity-utils/contracts/access-control/OwnableWithGuardian.sol';
import {SafeCast} from 'solidity-utils/contracts/oz-common/SafeCast.sol';
import {IGovernanceCore, IGovernancePowerStrategy, PayloadsControllerUtils} from '../interfaces/IGovernanceCore.sol';
import {IVotingPortal} from '../interfaces/IVotingPortal.sol';
import {Errors} from './libraries/Errors.sol';
import {IVotingMachineWithProofs} from './voting/interfaces/IVotingMachineWithProofs.sol';
import {IBaseVotingStrategy} from '../interfaces/IBaseVotingStrategy.sol';

/**
 * @title GovernanceCore
 * @author BGD Labs
 * @notice this contract contains the logic to create proposals and communicate with the voting machine to vote on the
           proposals and the payloadsController to execute them, being in the same or different network.
 * @dev Abstract contract that is implemented on Governance contract
 * @dev !!!!!!!!!!! CHILD CLASS SHOULD IMPLEMENT initialize() and CALL _initializeCore METHOD FROM THERE !!!!!!!!!!!!
 */
abstract contract GovernanceCore is
  IGovernanceCore,
  Initializable,
  OwnableWithGuardian
{
  using SafeCast for uint256;

  // It has been put at 10 because it is a limit that will not be reached in the near future, as we currently have
  // AAVE, stkAAVE, stkABPT, aAAVE, and probably some others from balancer, curve, etc
  /// @inheritdoc IGovernanceCore
  uint256 public constant VOTING_TOKENS_CAP = 10;

  // @inheritdoc IGovernanceCore
  uint256 public constant PRECISION_DIVIDER = 1 ether;

  // @inheritdoc IGovernanceCore
  uint256 public constant PROPOSAL_EXPIRATION_TIME = 30 days;

  // @inheritdoc IGovernanceCore
  uint256 public immutable COOLDOWN_PERIOD;

  IGovernancePowerStrategy internal _powerStrategy;

  uint256 internal _proposalsCount;

  // (votingPortal => approved) mapping to store the approved voting portals
  mapping(address => bool) internal _votingPortals;

  // counts the currently active voting portals
  uint256 internal _votingPortalsCount;

  // (proposalId => Proposal) mapping to store the information of a proposal. indexed by proposalId
  mapping(uint256 => Proposal) internal _proposals;

  // (accessLevel => VotingConfig) mapping storing the different voting configurations.
  // Indexed by access level (level 1, level 2)
  mapping(PayloadsControllerUtils.AccessControl => VotingConfig)
    internal _votingConfigs;

  /// @inheritdoc IGovernanceCore
  string public constant NAME = 'Aave Governance v3';

  /**
   * @param coolDownPeriod time that should pass before proposal will be moved to vote, in seconds
   */
  constructor(uint256 coolDownPeriod) {
    COOLDOWN_PERIOD = coolDownPeriod;
  }

  // @inheritdoc IGovernanceCore
  function ACHIEVABLE_VOTING_PARTICIPATION()
    public
    view
    virtual
    returns (uint256)
  {
    return 5_000_000 ether;
  }

  // @inheritdoc IGovernanceCore
  function MIN_VOTING_DURATION() public view virtual returns (uint256) {
    return 3 days;
  }

  /**
   * @notice method to initialize governance v3 core
   * @param owner address of the new owner of governance
   * @param guardian address of the new guardian of governance
   * @param powerStrategy address of the governance chain voting strategy
   * @param votingConfigs objects containing the information of different voting configurations depending on access level
   * @param votingPortals objects containing the information of different voting machines depending on chain id
   */
  function _initializeCore(
    address owner,
    address guardian,
    IGovernancePowerStrategy powerStrategy,
    SetVotingConfigInput[] calldata votingConfigs,
    address[] calldata votingPortals
  ) internal initializer {
    require(votingConfigs.length == 2, Errors.MISSING_VOTING_CONFIGURATIONS);
    require(
      votingConfigs[0].accessLevel != votingConfigs[1].accessLevel,
      Errors.INVALID_INITIAL_VOTING_CONFIGS
    );

    _transferOwnership(owner);
    _updateGuardian(guardian);
    _setPowerStrategy(powerStrategy);
    _setVotingConfigs(votingConfigs);
    _updateVotingPortals(votingPortals, true);
  }

  /// @inheritdoc IGovernanceCore
  function getVotingPortalsCount() external view returns (uint256) {
    return _votingPortalsCount;
  }

  /// @inheritdoc IGovernanceCore
  function getPowerStrategy() external view returns (IGovernancePowerStrategy) {
    return _powerStrategy;
  }

  /// @inheritdoc IGovernanceCore
  function getProposalsCount() external view returns (uint256) {
    return _proposalsCount;
  }

  /// @inheritdoc IGovernanceCore
  function isVotingPortalApproved(
    address votingPortal
  ) public view returns (bool) {
    return _votingPortals[votingPortal];
  }

  /// @inheritdoc IGovernanceCore
  function addVotingPortals(
    address[] calldata votingPortals
  ) external onlyOwner {
    _updateVotingPortals(votingPortals, true);
  }

  /// @inheritdoc IGovernanceCore
  function rescueVotingPortal(address votingPortal) external onlyGuardian {
    require(_votingPortalsCount == 0, Errors.VOTING_PORTALS_COUNT_NOT_0);

    address[] memory votingPortals = new address[](1);
    votingPortals[0] = votingPortal;
    _updateVotingPortals(votingPortals, true);
  }

  /// @inheritdoc IGovernanceCore
  function removeVotingPortals(
    address[] calldata votingPortals
  ) external onlyOwner {
    _updateVotingPortals(votingPortals, false);
  }

  /// @inheritdoc IGovernanceCore
  function createProposal(
    PayloadsControllerUtils.Payload[] calldata payloads,
    address votingPortal,
    bytes32 ipfsHash
  ) external returns (uint256) {
    require(payloads.length != 0, Errors.AT_LEAST_ONE_PAYLOAD);
    require(ipfsHash != bytes32(0), Errors.G_INVALID_IPFS_HASH);

    require(
      isVotingPortalApproved(votingPortal),
      Errors.VOTING_PORTAL_NOT_APPROVED
    );

    uint256 proposalId = _proposalsCount++;
    Proposal storage proposal = _proposals[proposalId];

    PayloadsControllerUtils.AccessControl maximumAccessLevelRequired;
    for (uint256 i = 0; i < payloads.length; i++) {
      require(
        payloads[i].accessLevel >
          PayloadsControllerUtils.AccessControl.Level_null,
        Errors.G_INVALID_PAYLOAD_ACCESS_LEVEL
      );
      require(
        payloads[i].payloadsController != address(0),
        Errors.G_INVALID_PAYLOADS_CONTROLLER
      );
      require(payloads[i].chain > 0, Errors.G_INVALID_PAYLOAD_CHAIN);
      proposal.payloads.push(payloads[i]);

      if (payloads[i].accessLevel > maximumAccessLevelRequired) {
        maximumAccessLevelRequired = payloads[i].accessLevel;
      }
    }

    VotingConfig memory votingConfig = _votingConfigs[
      maximumAccessLevelRequired
    ];

    address proposalCreator = msg.sender;
    require(
      _isPropositionPowerEnough(
        votingConfig,
        _powerStrategy.getFullPropositionPower(proposalCreator)
      ),
      Errors.PROPOSITION_POWER_IS_TOO_LOW
    );

    proposal.state = State.Created;
    proposal.creator = proposalCreator;
    proposal.accessLevel = maximumAccessLevelRequired;
    proposal.votingPortal = votingPortal;
    proposal.creationTime = uint40(block.timestamp);
    proposal.ipfsHash = ipfsHash;

    emit ProposalCreated(
      proposalId,
      proposalCreator,
      maximumAccessLevelRequired,
      ipfsHash
    );

    return proposalId;
  }

  /// @inheritdoc IGovernanceCore
  function activateVoting(uint256 proposalId) external {
    Proposal storage proposal = _proposals[proposalId];
    VotingConfig memory votingConfig = _votingConfigs[proposal.accessLevel];

    uint40 proposalCreationTime = proposal.creationTime;
    bytes32 blockHash = blockhash(block.number - 1);

    require(
      _getProposalState(proposal) == State.Created,
      Errors.PROPOSAL_NOT_IN_CREATED_STATE
    );

    require(
      isVotingPortalApproved(proposal.votingPortal),
      Errors.VOTING_PORTAL_NOT_APPROVED
    );

    require(
      block.timestamp - proposalCreationTime >
        votingConfig.coolDownBeforeVotingStart,
      Errors.VOTING_START_COOLDOWN_PERIOD_NOT_PASSED
    );

    require(
      _isPropositionPowerEnough(
        votingConfig,
        _powerStrategy.getFullPropositionPower(proposal.creator)
      ),
      Errors.PROPOSITION_POWER_IS_TOO_LOW
    );

    proposal.votingActivationTime = uint40(block.timestamp);
    proposal.snapshotBlockHash = blockHash;
    proposal.state = State.Active;
    proposal.votingDuration = votingConfig.votingDuration;

    IVotingPortal(proposal.votingPortal).forwardStartVotingMessage(
      proposalId,
      blockHash,
      proposal.votingDuration
    );
    emit VotingActivated(proposalId, blockHash, votingConfig.votingDuration);
  }

  /// @inheritdoc IGovernanceCore
  function voteViaPortal(
    uint256 proposalId,
    bool support,
    IVotingMachineWithProofs.VotingAssetWithSlot[] memory votingAssetsWithSlot
  ) external {
    Proposal storage proposal = _proposals[proposalId];
    require(
      _getProposalState(proposal) == State.Active,
      Errors.PROPOSAL_NOT_IN_ACTIVE_STATE
    );
    require(
      isVotingPortalApproved(proposal.votingPortal),
      Errors.VOTING_PORTAL_NOT_APPROVED
    );
    require(
      votingAssetsWithSlot.length < VOTING_TOKENS_CAP &&
        votingAssetsWithSlot.length > 0,
      Errors.INVALID_VOTING_TOKENS
    );
    for (uint256 i = 0; i < votingAssetsWithSlot.length; i++) {
      require(
        IBaseVotingStrategy(address(_powerStrategy)).isTokenSlotAccepted(
          votingAssetsWithSlot[i].underlyingAsset,
          votingAssetsWithSlot[i].slot
        ),
        Errors.INVALID_VOTING_ASSETS_WITH_SLOT
      );
      for (uint256 j = i + 1; j < votingAssetsWithSlot.length; j++) {
        require(
          votingAssetsWithSlot[j].underlyingAsset !=
            votingAssetsWithSlot[i].underlyingAsset ||
            votingAssetsWithSlot[j].slot != votingAssetsWithSlot[i].slot,
          Errors.CAN_NOT_VOTE_WITH_REPEATED_ASSETS
        );
      }
    }

    IVotingPortal(proposal.votingPortal).forwardVoteMessage(
      proposalId,
      msg.sender,
      support,
      votingAssetsWithSlot
    );

    emit VoteForwarded(proposalId, msg.sender, support, votingAssetsWithSlot);
  }

  /// @inheritdoc IGovernanceCore
  function queueProposal(
    uint256 proposalId,
    uint128 forVotes,
    uint128 againstVotes
  ) external {
    Proposal storage proposal = _proposals[proposalId];
    address votingPortal = proposal.votingPortal;

    // only the accepted portal for this proposal can queue it
    require(
      msg.sender == votingPortal && isVotingPortalApproved(votingPortal),
      Errors.CALLER_NOT_A_VALID_VOTING_PORTAL
    );

    require(
      _getProposalState(proposal) == State.Active,
      Errors.PROPOSAL_NOT_IN_ACTIVE_STATE
    );

    require(
      block.timestamp > proposal.votingDuration + proposal.votingActivationTime,
      Errors.VOTING_DURATION_NOT_PASSED
    );

    VotingConfig memory votingConfig = _votingConfigs[proposal.accessLevel];

    proposal.forVotes = forVotes;
    proposal.againstVotes = againstVotes;

    if (
      _isPropositionPowerEnough(
        votingConfig,
        _powerStrategy.getFullPropositionPower(proposal.creator)
      ) &&
      _isPassingYesThreshold(votingConfig, forVotes) &&
      _isPassingYesNoDifferential(votingConfig, forVotes, againstVotes)
    ) {
      proposal.queuingTime = uint40(block.timestamp);
      proposal.state = State.Queued;
      emit ProposalQueued(proposalId, forVotes, againstVotes);
    } else {
      proposal.state = State.Failed;
      emit ProposalFailed(proposalId, forVotes, againstVotes);
    }
  }

  /// @inheritdoc IGovernanceCore
  function executeProposal(uint256 proposalId) external {
    Proposal storage proposal = _proposals[proposalId];
    require(
      _getProposalState(proposal) == State.Queued,
      Errors.PROPOSAL_NOT_IN_QUEUED_STATE
    );
    require(
      block.timestamp >= proposal.queuingTime + COOLDOWN_PERIOD,
      Errors.QUEUE_COOLDOWN_PERIOD_NOT_PASSED
    );
    require(
      _isPropositionPowerEnough(
        _votingConfigs[proposal.accessLevel],
        _powerStrategy.getFullPropositionPower(proposal.creator)
      ),
      Errors.PROPOSITION_POWER_IS_TOO_LOW
    );

    proposal.state = State.Executed;

    for (uint256 i = 0; i < proposal.payloads.length; i++) {
      PayloadsControllerUtils.Payload memory payload = proposal.payloads[i];

      // votingActivationTime is sent to PayloadsController to force that the payload voted on the proposal
      // was registered before the vote happened, ensuring that the voters were able to check the contents
      // of the payload before emitting the vote.
      _forwardPayloadForExecution(payload, proposal.votingActivationTime);
      emit PayloadSent(
        proposalId,
        payload.payloadId,
        payload.payloadsController,
        payload.chain,
        i,
        proposal.payloads.length
      );
    }

    emit ProposalExecuted(proposalId);
  }

  /// @inheritdoc IGovernanceCore
  function cancelProposal(uint256 proposalId) external {
    Proposal storage proposal = _proposals[proposalId];
    State proposalState = _getProposalState(proposal);
    address proposalCreator = proposal.creator;

    require(
      proposalState != State.Null &&
        uint256(proposalState) < uint256(State.Executed),
      Errors.PROPOSAL_NOT_IN_THE_CORRECT_STATE
    );

    if (
      isVotingPortalApproved(proposal.votingPortal) &&
      proposalCreator != msg.sender &&
      _isPropositionPowerEnough(
        _votingConfigs[proposal.accessLevel],
        _powerStrategy.getFullPropositionPower(proposalCreator)
      )
    ) {
      _checkGuardian();
    }

    proposal.state = State.Cancelled;
    proposal.cancelTimestamp = uint40(block.timestamp);
    emit ProposalCanceled(proposalId);
  }

  /// @inheritdoc IGovernanceCore
  function getProposalState(uint256 proposalId) external view returns (State) {
    Proposal storage proposal = _proposals[proposalId];

    return _getProposalState(proposal);
  }

  /// @inheritdoc IGovernanceCore
  function setVotingConfigs(
    SetVotingConfigInput[] calldata votingConfigs
  ) external onlyOwner {
    _setVotingConfigs(votingConfigs);
  }

  /// @inheritdoc IGovernanceCore
  function setPowerStrategy(
    IGovernancePowerStrategy powerStrategy
  ) external onlyOwner {
    _setPowerStrategy(powerStrategy);
  }

  /// @inheritdoc IGovernanceCore
  function getProposal(
    uint256 proposalId
  ) external view returns (Proposal memory) {
    Proposal memory proposal = _proposals[proposalId];
    proposal.state = _getProposalState(_proposals[proposalId]);
    return proposal;
  }

  /// @inheritdoc IGovernanceCore
  function getVotingConfig(
    PayloadsControllerUtils.AccessControl accessLevel
  ) external view returns (VotingConfig memory) {
    return _votingConfigs[accessLevel];
  }

  /**
   * @notice method to override that should be in charge of sending payload for execution
   * @param payload object containing the information necessary for execution
   * @param proposalVoteActivationTimestamp proposal vote activation timestamp in seconds
   */
  function _forwardPayloadForExecution(
    PayloadsControllerUtils.Payload memory payload,
    uint40 proposalVoteActivationTimestamp
  ) internal virtual;

  /**
   * @notice method to set the voting configuration for a determined access level
   * @param votingConfigs object containing configuration for an access level
   */
  function _setVotingConfigs(
    SetVotingConfigInput[] memory votingConfigs
  ) internal {
    require(votingConfigs.length > 0, Errors.INVALID_VOTING_CONFIGS);

    for (uint256 i = 0; i < votingConfigs.length; i++) {
      require(
        votingConfigs[i].accessLevel >
          PayloadsControllerUtils.AccessControl.Level_null,
        Errors.INVALID_VOTING_CONFIG_ACCESS_LEVEL
      );
      require(
        votingConfigs[i].coolDownBeforeVotingStart +
          votingConfigs[i].votingDuration +
          COOLDOWN_PERIOD <
          PROPOSAL_EXPIRATION_TIME,
        Errors.INVALID_VOTING_DURATION
      );
      require(
        votingConfigs[i].votingDuration >= MIN_VOTING_DURATION(),
        Errors.VOTING_DURATION_TOO_SMALL
      );
      require(
        votingConfigs[i].minPropositionPower <=
          ACHIEVABLE_VOTING_PARTICIPATION(),
        Errors.INVALID_PROPOSITION_POWER
      );
      require(
        votingConfigs[i].yesThreshold <= ACHIEVABLE_VOTING_PARTICIPATION(),
        Errors.INVALID_YES_THRESHOLD
      );
      require(
        votingConfigs[i].yesNoDifferential <= ACHIEVABLE_VOTING_PARTICIPATION(),
        Errors.INVALID_YES_NO_DIFFERENTIAL
      );

      VotingConfig memory votingConfig = VotingConfig({
        coolDownBeforeVotingStart: votingConfigs[i].coolDownBeforeVotingStart,
        votingDuration: votingConfigs[i].votingDuration,
        yesThreshold: _normalize(votingConfigs[i].yesThreshold),
        yesNoDifferential: _normalize(votingConfigs[i].yesNoDifferential),
        minPropositionPower: _normalize(votingConfigs[i].minPropositionPower)
      });
      _votingConfigs[votingConfigs[i].accessLevel] = votingConfig;

      emit VotingConfigUpdated(
        votingConfigs[i].accessLevel,
        votingConfig.votingDuration,
        votingConfig.coolDownBeforeVotingStart,
        votingConfig.yesThreshold,
        votingConfig.yesNoDifferential,
        votingConfig.minPropositionPower
      );
    }

    // validation of the voting configs after change, to make it not possible for lvl2 configuration to have configs
    // lower than lvl1
    VotingConfig memory votingConfigL1 = _votingConfigs[
      PayloadsControllerUtils.AccessControl.Level_1
    ];
    VotingConfig memory votingConfigL2 = _votingConfigs[
      PayloadsControllerUtils.AccessControl.Level_2
    ];
    require(
      votingConfigL1.minPropositionPower <= votingConfigL2.minPropositionPower,
      Errors.INVALID_PROPOSITION_POWER
    );
    require(
      votingConfigL1.yesThreshold <= votingConfigL2.yesThreshold,
      Errors.INVALID_YES_THRESHOLD
    );
    require(
      votingConfigL1.yesNoDifferential <= votingConfigL2.yesNoDifferential,
      Errors.INVALID_YES_NO_DIFFERENTIAL
    );
  }

  /**
   * @notice method to set a new _powerStrategy contract
   * @param powerStrategy address of the new contract containing the voting a voting strategy
   */
  function _setPowerStrategy(IGovernancePowerStrategy powerStrategy) internal {
    require(
      address(powerStrategy) != address(0),
      Errors.INVALID_POWER_STRATEGY
    );
    require(
      IBaseVotingStrategy(address(powerStrategy)).getVotingAssetList().length >
        0,
      Errors.POWER_STRATEGY_HAS_NO_TOKENS
    );
    _powerStrategy = powerStrategy;

    emit PowerStrategyUpdated(address(powerStrategy));
  }

  /**
   * @notice method to know if proposition power is bigger than the minimum expected for the voting configuration set
         for this access level
   * @param votingConfig voting configuration from a specific access level, where to check the minimum proposition power
   * @param propositionPower power to check against the voting config minimum
   * @return boolean indicating if power is bigger than minimum
   */
  function _isPropositionPowerEnough(
    IGovernanceCore.VotingConfig memory votingConfig,
    uint256 propositionPower
  ) internal pure returns (bool) {
    return
      propositionPower > votingConfig.minPropositionPower * PRECISION_DIVIDER;
  }

  /**
   * @notice method to know if a vote is passing the yes threshold set in the vote configuration. For this it is required
             for votes to be bigger than configuration yes threshold.
   * @param votingConfig configuration of this voting, set by access level
   * @param forVotes votes in favor of passing the proposal
   * @return boolean indicating the passing of the yes threshold
   */
  function _isPassingYesThreshold(
    VotingConfig memory votingConfig,
    uint256 forVotes
  ) internal pure returns (bool) {
    return forVotes > votingConfig.yesThreshold * PRECISION_DIVIDER;
  }

  /**
   * @notice method to know if the votes pass the yes no differential set by the voting configuration
   * @param votingConfig configuration of this voting, set by access level
   * @param forVotes votes in favor of passing the proposal
   * @param againstVotes votes against passing the proposal
   * @return boolean indicating the passing of the yes no differential
   */
  function _isPassingYesNoDifferential(
    VotingConfig memory votingConfig,
    uint256 forVotes,
    uint256 againstVotes
  ) internal pure returns (bool) {
    return
      forVotes >= againstVotes &&
      forVotes - againstVotes >
      votingConfig.yesNoDifferential * PRECISION_DIVIDER;
  }

  /**
   * @notice method to get the current state of a proposal
   * @param proposal object with all pertinent proposal information
   * @return current state of the proposal
   */
  function _getProposalState(
    Proposal storage proposal
  ) internal view returns (State) {
    State state = proposal.state;
    // @dev small shortcut
    if (
      state == IGovernanceCore.State.Null ||
      state >= IGovernanceCore.State.Executed
    ) {
      return state;
    }

    uint256 expirationTime = proposal.creationTime + PROPOSAL_EXPIRATION_TIME;
    if (
      block.timestamp > expirationTime ||
      (state == IGovernanceCore.State.Created &&
        // if current time + duration of the vote is bigger than expiration time, and vote has not been activated,
        // proposal should be expired as when the vote result returns, proposal will have expired.
        block.timestamp + proposal.votingDuration > expirationTime)
    ) {
      return State.Expired;
    }

    return state;
  }

  /**
   * @notice method to remove specified decimals from a value, as to normalize it.
   * @param value number to remove decimals from
   * @return normalized value
   */
  function _normalize(uint256 value) internal pure returns (uint56) {
    uint256 normalizedValue = value / PRECISION_DIVIDER;
    return normalizedValue.toUint56();
  }

  /**
   * @notice method that approves or disapproves voting machines
   * @param votingPortals list of voting portal addresses
   * @param state boolean indicating if the list is for approval or disapproval of the voting portal addresses
   */
  function _updateVotingPortals(
    address[] memory votingPortals,
    bool state
  ) internal {
    for (uint256 i = 0; i < votingPortals.length; i++) {
      address votingPortal = votingPortals[i];

      require(votingPortal != address(0), Errors.INVALID_VOTING_PORTAL_ADDRESS);
      // if voting portal is already in the target state - just skip
      if (_votingPortals[votingPortal] == state) {
        continue;
      }

      if (state) {
        _votingPortalsCount++;
      } else {
        _votingPortalsCount--;
      }

      _votingPortals[votingPortal] = state;

      emit VotingPortalUpdated(votingPortal, state);
    }
  }
}
