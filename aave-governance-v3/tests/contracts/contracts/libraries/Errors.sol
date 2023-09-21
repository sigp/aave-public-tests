// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Errors library
 * @author BGD Labs
 * @notice Defines the error messages emitted by the different contracts of the Aave Governance V3
 */
library Errors {
  string public constant VOTING_PORTALS_COUNT_NOT_0 = '1'; // to be able to rescue voting portals count must be 0
  string public constant AT_LEAST_ONE_PAYLOAD = '2'; // to create a proposal, it must have at least one payload
  string public constant VOTING_PORTAL_NOT_APPROVED = '3'; // the voting portal used to vote on proposal must be approved
  string public constant PROPOSITION_POWER_IS_TOO_LOW = '4'; // proposition power of proposal creator must be equal or higher than the specified threshold for the access level
  string public constant PROPOSAL_NOT_IN_CREATED_STATE = '5'; // proposal should be in the CREATED state
  string public constant PROPOSAL_NOT_IN_ACTIVE_STATE = '6'; // proposal must be in an ACTIVE state
  string public constant PROPOSAL_NOT_IN_QUEUED_STATE = '7'; // proposal must be in a QUEUED state
  string public constant VOTING_START_COOLDOWN_PERIOD_NOT_PASSED = '8'; // to activate a proposal vote, the cool down delay must pass
  string public constant INVALID_VOTING_TOKENS = '9'; // can not vote with more tokens than are allowed
  string public constant CALLER_NOT_A_VALID_VOTING_PORTAL = '10'; // only an allowed voting portal can queue a proposal
  string public constant QUEUE_COOLDOWN_PERIOD_NOT_PASSED = '11'; // to execute a proposal a cooldown delay must pass
  string public constant PROPOSAL_NOT_IN_THE_CORRECT_STATE = '12'; // proposal must be created but not executed yet to be able to be canceled
  string public constant CALLER_NOT_GOVERNANCE = '13'; // caller must be governance
  string public constant VOTER_ALREADY_VOTED_ON_PROPOSAL = '14'; // voter can only vote once per proposal using voting portal
  string public constant WRONG_MESSAGE_ORIGIN = '15'; // received message must come from registered source address, chain id, CrossChainController
  string public constant NO_VOTING_ASSETS = '16'; // Strategy must have voting assets
  string public constant PROPOSAL_VOTE_ALREADY_CREATED = '17'; // vote on proposal can only be created once
  string public constant INVALID_SIGNATURE = '18'; // submitted signature is not valid
  string public constant INVALID_NUMBER_OF_PROOFS_FOR_VOTING_TOKENS = '19'; // Need all the necessary proofs to validate the voting tokens
  string public constant PROOFS_NOT_FOR_VOTING_TOKENS = '20'; // provided proofs must be from the voting tokens selected (bridged from governance chain)
  string public constant PROPOSAL_VOTE_NOT_FINISHED = '21'; // proposal vote must be finished
  string public constant PROPOSAL_VOTE_NOT_IN_ACTIVE_STATE = '22'; // proposal vote must be in active state
  string public constant PROPOSAL_VOTE_ALREADY_EXISTS = '23'; // proposal vote already exists
  string public constant VOTE_ONCE_FOR_ASSET = '24'; // an asset can only be used once per vote
  string public constant USER_BALANCE_DOES_NOT_EXISTS = '25'; // to vote an user must have balance in the token the user is voting with
  string public constant USER_VOTING_BALANCE_IS_ZERO = '26'; // to vote an user must have some balance between all the tokens selected for voting
  string public constant MISSING_AAVE_ROOTS = '27'; // must have AAVE roots registered to use strategy
  string public constant MISSING_STK_AAVE_ROOTS = '28'; // must have stkAAVE roots registered to use strategy
  string public constant MISSING_STK_AAVE_SLASHING_EXCHANGE_RATE = '29'; // must have stkAAVE slashing exchange rate registered to use strategy
  string public constant UNPROCESSED_STORAGE_ROOT = '30'; // root must be registered beforehand
  string public constant NOT_ENOUGH_MSG_VALUE = '31'; // method was not called with enough value to execute the call
  string public constant FAILED_ACTION_EXECUTION = '32'; // action failed to execute
  string public constant SHOULD_BE_AT_LEAST_ONE_EXECUTOR = '33'; // at least one executor is needed
  string public constant INVALID_EMPTY_TARGETS = '34'; // target of the payload execution must not be empty
  string public constant EXECUTOR_WAS_NOT_SPECIFIED_FOR_REQUESTED_ACCESS_LEVEL =
    '35'; // payload executor must be registered for the specified payload access level
  string public constant PAYLOAD_NOT_IN_QUEUED_STATE = '36'; // payload must be en the queued state
  string public constant TIMELOCK_NOT_FINISHED = '37'; // delay has not passed before execution can be called
  string public constant PAYLOAD_NOT_IN_THE_CORRECT_STATE = '38'; // payload must be created but not executed yet to be able to be canceled
  string public constant PAYLOAD_NOT_IN_CREATED_STATE = '39'; // payload must be in the created state
  string public constant MISSING_A_AAVE_ROOTS = '40'; // must have aAAVE roots registered to use strategy
  string public constant MISSING_PROPOSAL_BLOCK_HASH = '41'; // block hash for this proposal was not bridged before
  string public constant PROPOSAL_VOTE_CONFIGURATION_ALREADY_BRIDGED = '42'; // configuration for this proposal bridged already
  string public constant INVALID_VOTING_PORTAL_ADDRESS = '43'; // voting portal address can't be 0x0
  string public constant INVALID_POWER_STRATEGY = '44'; // 0x0 is not valid as the power strategy
  string public constant INVALID_EXECUTOR_ADDRESS = '45'; // executor address can't be 0x0
  string public constant EXECUTOR_ALREADY_SET_IN_DIFFERENT_LEVEL = '46'; // executor address already being used as executor of a different level
  string public constant INVALID_VOTING_DURATION = '47'; // voting duration can not be bigger than the time it takes to execute a proposal
  string public constant VOTING_DURATION_NOT_PASSED = '48'; // at least votingDuration should have passed since voting started for a proposal to be queued
  string public constant INVALID_PROPOSAL_ACCESS_LEVEL = '49'; // the bridged proposal access level does not correspond with the maximum access level required by the payload
  string public constant PAYLOAD_NOT_CREATED_BEFORE_PROPOSAL = '50'; // payload must be created before proposal
  string public constant INVALID_CROSS_CHAIN_CONTROLLER_ADDRESS = '51';
  string public constant INVALID_MESSAGE_ORIGINATOR_ADDRESS = '51';
  string public constant INVALID_ORIGIN_CHAIN_ID = '52';
  string public constant INVALID_ACTION_TARGET = '54';
  string public constant INVALID_ACTION_ACCESS_LEVEL = '55';
  string public constant INVALID_EXECUTOR_ACCESS_LEVEL = '56';
  string public constant INVALID_VOTING_PORTAL_CROSS_CHAIN_CONTROLLER = '57';
  string public constant INVALID_VOTING_PORTAL_VOTING_MACHINE = '58';
  string public constant INVALID_VOTING_PORTAL_GOVERNANCE = '59';
  string public constant INVALID_VOTING_MACHINE_CHAIN_ID = '60';
  string public constant G_INVALID_CROSS_CHAIN_CONTROLLER_ADDRESS = '61';
  string public constant G_INVALID_IPFS_HASH = '62';
  string public constant G_INVALID_PAYLOAD_ACCESS_LEVEL = '63';
  string public constant G_INVALID_PAYLOADS_CONTROLLER = '64';
  string public constant G_INVALID_PAYLOAD_CHAIN = '65';
  string public constant POWER_STRATEGY_HAS_NO_TOKENS = '66'; // power strategy should at least have
  string public constant INVALID_VOTING_CONFIG_ACCESS_LEVEL = '67';
  string public constant VOTING_DURATION_TOO_SMALL = '68';
  string public constant NO_BRIDGED_VOTING_ASSETS = '69';
  string public constant VOTE_ALREADY_BRIDGED = '70';
  string public constant INVALID_VOTER = '71';
  string public constant INVALID_DATA_WAREHOUSE = '72';
  string public constant INVALID_VOTING_MACHINE_CROSS_CHAIN_CONTROLLER = '73';
  string public constant INVALID_L1_VOTING_PORTAL = '74';
  string public constant INVALID_VOTING_PORTAL_CHAIN_ID = '75';
  string public constant INVALID_VOTING_STRATEGY = '76';
  string public constant INVALID_VOTING_ASSETS_WITH_SLOT = '77'; // Token slot is not defined on the strategy
  string public constant PROPOSAL_VOTE_CAN_NOT_BE_REGISTERED = '78'; // to register a bridged vote proposal vote must be in NotCreated or Active state
  string public constant INVALID_VOTE_CONFIGURATION_BLOCKHASH = '79';
  string public constant INVALID_VOTE_CONFIGURATION_VOTING_DURATION = '80';
  string public constant INVALID_GAS_LIMIT = '81';
  string public constant INVALID_VOTING_CONFIGS = '82'; // a lvl2 voting configuration must be sent to initializer
  string public constant INVALID_EXECUTOR_DELAY = '83';
  string public constant INVALID_BRIDGED_VOTING_TOKEN = '84'; // A bridged voting token must be on the strategy list
  string public constant BRIDGED_REPEATED_ASSETS = '85'; // bridged voting tokens must be unique
  string public constant CAN_NOT_VOTE_WITH_REPEATED_ASSETS = '86'; // voting tokens to bridge must be unique
  string public constant REPEATED_STRATEGY_ASSET = '87';
  string public constant EMPTY_ASSET_STORAGE_SLOTS = '88';
  string public constant REPEATED_STRATEGY_ASSET_SLOT = '89';
  string public constant INVALID_EXECUTION_TARGET = '90';
  string public constant MISSING_VOTING_CONFIGURATIONS = '91'; // voting configurations for lvl1 and lvl2 must be included on initialization
  string public constant INVALID_PROPOSITION_POWER = '92';
  string public constant INVALID_YES_THRESHOLD = '93';
  string public constant INVALID_YES_NO_DIFFERENTIAL = '94';
  string public constant ETH_TRANSFER_FAILED = '95';
  string public constant INVALID_INITIAL_VOTING_CONFIGS = '96'; // initial voting configurations can not be of the same level
  string public constant INVALID_VOTING_PORTAL_ADDRESS_IN_VOTING_MACHINE = '97';
  string public constant INVALID_VOTING_PORTAL_OWNER = '98';
}
