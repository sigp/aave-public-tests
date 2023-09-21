import brownie
import pytest

from brownie import (
    # Brownie helpers
    accounts,
    web3,
    reverts,
    Wei,
    chain,
    Contract,
)


def test_basic(setup_protocol):
    """
    Sanity check to ensure match between the proxy and the implemention contract
    """
    proxy_admin = setup_protocol["proxy_admin"]
    governance = setup_protocol["governance"]
    governance_logic = setup_protocol["governance_logic"]

    info = proxy_admin.getProxyImplementation(governance)

    assert info == governance_logic.address


def test_constructor(setup_protocol, constants):
    """
    checking the immutable variables inside the governance proxy
    """
    governance = setup_protocol["governance"]
    cross_chain_controller = setup_protocol["cross_chain_controller"]

    assert governance.getGasLimit() == constants.EXECUTION_GAS_LIMIT
    assert governance.CROSS_CHAIN_CONTROLLER() == cross_chain_controller.address
    assert governance.COOLDOWN_PERIOD() == constants.COOLDOWN_PERIOD


def test_initialize(setup_protocol, owner, guardian, voting_config_level1, voting_config_level2):
    """
    Testing `initialize()`, ensure that all the variables are set correctly
    """
    governance = setup_protocol["governance"]
    power_strategy_mock = setup_protocol["power_strategy_mock"]
    voting_portal = setup_protocol["voting_portal"]
    voting_config_1 = voting_config_level1["voting_config"]
    voting_config_2 = voting_config_level2["voting_config"]
    # validation
    assert governance.getPowerStrategy() == power_strategy_mock
    assert governance.guardian() == guardian
    assert governance.owner() == owner
    assert governance.getVotingPortalsCount() == 1
    assert governance.isVotingPortalApproved(voting_portal) is True
    access_level = 1
    voting_config_level_1 = governance.getVotingConfig(access_level)
    assert voting_config_1[1] == voting_config_level_1[0]
    assert voting_config_1[2] == voting_config_level_1[1]
    assert voting_config_1[3] // 10 ** 18 == voting_config_level_1[2] # // 10 ** 18 as the values are normilized 
    assert voting_config_1[4] // 10 ** 18 == voting_config_level_1[3] 
    assert voting_config_1[5] // 10 ** 18 == voting_config_level_1[4]
    access_level = 2
    voting_config_level_2 = governance.getVotingConfig(access_level)
    assert voting_config_2[1] == voting_config_level_2[0]
    assert voting_config_2[2] == voting_config_level_2[1]
    assert voting_config_2[3] // 10 ** 18 == voting_config_level_2[2] # // 10 ** 18 as the values are normilized 
    assert voting_config_2[4] // 10 ** 18 == voting_config_level_2[3] 
    assert voting_config_2[5] // 10 ** 18 == voting_config_level_2[4]


def test_create_proposal(setup_protocol, owner, alice, constants):
    """
    Testing `createProposal()`
    """
    #Setup    
    governance = setup_protocol["governance"]
    power_strategy_mock = setup_protocol["power_strategy_mock"]
    voting_portal = setup_protocol["voting_portal"]

    # Set proposition power in the mock contract
    power_strategy_mock.setFullPropositionPower(90_000 * 10 ** 18, {"from": owner})

    proposal_count_before = governance.getProposalsCount()
    access_level_payload_1 = 1
    # call `createProposal`
    payload_1 = [
        1, # chainId
        access_level_payload_1, 
        owner, # payloadController
        7, # payloadId
    ]
    access_level_payload_2 = 2
    payload_2 = [
        1, # chainId
        access_level_payload_2,
        owner, # payloadController
        13, # payloadId
    ]
    payloads = [payload_1, payload_2]
    ipfs_hash =  b"\xa1" + b"\x00" * 31

    tx = governance.createProposal(payloads, voting_portal, ipfs_hash, {"from": alice})

    # Validation
    assert governance.getProposalsCount() == proposal_count_before + 1
    proposal = governance.getProposal(proposal_count_before)
    assert proposal["state"] == constants.proposalState["Created"] # Created
    assert proposal["creator"] == alice
    assert proposal["accessLevel"] == max(access_level_payload_1, access_level_payload_2)
    assert proposal["votingPortal"] == voting_portal
    assert proposal["creationTime"] == tx.timestamp
    assert proposal["ipfsHash"].hex() == ipfs_hash.hex()
    # logs
    assert tx.events["ProposalCreated"]["proposalId"] == proposal_count_before 
    assert tx.events["ProposalCreated"]["creator"] == alice
    assert tx.events["ProposalCreated"]["accessLevel"] == max(access_level_payload_1, access_level_payload_2)
    assert tx.events["ProposalCreated"]["ipfsHash"].hex() == ipfs_hash.hex()


def test_create_proposal_without_payload(setup_protocol, alice):
    """
    Testing `createProposal()` without a payload
    """
    #Setup    
    governance = setup_protocol["governance"]
    voting_portal = setup_protocol["voting_portal"]

    ipfs_hash =  b"\xa1" + b"\x00" * 31
    empty_payload = []
    with reverts("2"): #AT_LEAST_ONE_PAYLOAD
        governance.createProposal(empty_payload, voting_portal, ipfs_hash, {"from": alice})
    

def test_create_proposal_not_approved_voting_portal(setup_protocol, alice, owner):
    """
    Testing `createProposal()` when the voting portal is not approved
    """
    #Setup    
    governance = setup_protocol["governance"]
    voting_portal = owner
    payload_1 = [
        1, # chainId
        1, # Level_1
        owner, # payloadController
        7, # payloadId
    ]

    payloads = [payload_1]
    ipfs_hash =  b"\xa1" + b"\x00" * 31

    with reverts("3"): # VOTING_PORTAL_NOT_APPROVED
        governance.createProposal(payloads, voting_portal, ipfs_hash, {"from": alice})

    

def test_create_proposal_proposition_power_low(setup_protocol, owner, alice):
    """
    Testing `createProposal()` when the proposition power is not enough
    """
    #Setup    
    governance = setup_protocol["governance"]
    power_strategy_mock = setup_protocol["power_strategy_mock"]
    voting_portal = setup_protocol["voting_portal"]

    payload_1 = [
        1, # chainId
        1, # Level_1
        owner, # payloadController
        7, # payloadId
    ]
    payloads = [payload_1]
    ipfs_hash =  b"\xa1" + b"\x00" * 31

    # Set proposition power in the mock contract to a value lower to minPropositionPower
    power_strategy_mock.setFullPropositionPower(49_000 * 10 ** 18, {"from": owner})

    with reverts("4"): #PROPOSITION_POWER_IS_TOO_LOW
        governance.createProposal(payloads, voting_portal, ipfs_hash, {"from": alice})


def test_activate_voting(setup_protocol, owner, alice, voting_config_level2, constants):
    """
    Testing `activateVoting()`
    """
    #Setup    
    governance = setup_protocol["governance"]
    power_strategy_mock = setup_protocol["power_strategy_mock"]
    voting_portal = setup_protocol["voting_portal"]

    # Set proposition power in the mock contract
    power_strategy_mock.setFullPropositionPower(81_000 * 10 ** 18, {"from": owner})

    access_level_payload_1 = 1
    # call `createProposal`
    payload_1 = [
        1, # chainId
        access_level_payload_1, 
        owner, # payloadController
        7, # payloadId
    ]
    access_level_payload_2 = 2
    payload_2 = [
        1, # chainId
        access_level_payload_2,
        owner, # payloadController
        13, # payloadId
    ]
    payloads = [payload_1, payload_2]
    ipfs_hash =  b"\xa1" + b"\x00" * 31
    tx = governance.createProposal(payloads, voting_portal, ipfs_hash, {"from": alice})
    proposal_id = tx.events["ProposalCreated"]["proposalId"] 

    # time warp
    cooldown_before_voting_start = voting_config_level2["cooldown_before_voting_start"]
    delta = cooldown_before_voting_start + 20
    chain.mine(timedelta=delta)
    # call `activateVoting()`
    tx = governance.activateVoting(proposal_id, {"from": owner})

    # Validation
    proposal = governance.getProposal(proposal_id)
    assert proposal["state"] == constants.proposalState["Active"]
    assert proposal["votingActivationTime"] == tx.timestamp
    assert proposal["votingDuration"] == voting_config_level2["voting_duration"]
    # Logs
    assert tx.events["VotingActivated"]["proposalId"] == proposal_id
    assert tx.events["VotingActivated"]["votingDuration"] == voting_config_level2["voting_duration"]


def test_activate_voting_proposal_not_created_state(setup_protocol, owner):
    """
    Testing `activateVoting()` when the proposal not in created state
    """
    #Setup    
    governance = setup_protocol["governance"]

    proposal_id = 1337
    with reverts("5"): #PROPOSAL_NOT_IN_CREATED_STATE
        governance.activateVoting(proposal_id, {"from": owner})

    
def test_activate_voting_cooldown_period_not_passed(setup_protocol, owner, alice, voting_config_level1):
    """
    Testing `activateVoting()` when the cooldown voting period is not passed
    """
    #Setup        
    governance = setup_protocol["governance"]
    power_strategy_mock = setup_protocol["power_strategy_mock"]
    voting_portal = setup_protocol["voting_portal"]

    payload_1 = [
        1, # chainId
        1, # Level_1
        owner, # payloadController
        7, # payloadId
    ]
    payloads = [payload_1]
    ipfs_hash =  b"\xa1" + b"\x00" * 31

    # Set proposition power in the mock contract 
    power_strategy_mock.setFullPropositionPower(51_000 * 10 ** 18, {"from": owner})

    payloads = [payload_1]
    ipfs_hash =  b"\xa1" + b"\x00" * 31
    tx = governance.createProposal(payloads, voting_portal, ipfs_hash, {"from": alice})
    proposal_id = tx.events["ProposalCreated"]["proposalId"] 

    # time warp
    cooldown_before_voting_start = voting_config_level1["cooldown_before_voting_start"]
    delta = cooldown_before_voting_start - 20
    chain.mine(timedelta=delta)
    with reverts("8"): #VOTING_START_COOLDOWN_PERIOD_NOT_PASSED
        governance.activateVoting(proposal_id, {"from": owner})



def test_activate_voting_proposition_power_low(setup_protocol, owner, alice, voting_config_level1):
    """
     Testing `activateVoting()`when the proposition power is not enough
    """
    #Setup    
    governance = setup_protocol["governance"]
    power_strategy_mock = setup_protocol["power_strategy_mock"]
    voting_portal = setup_protocol["voting_portal"]

    payload_1 = [
        1, # chainId
        1, # Level_1
        owner, # payloadController
        7, # payloadId
    ]
    payloads = [payload_1]
    ipfs_hash =  b"\xa1" + b"\x00" * 31

    # Set proposition power in the mock contract
    power_strategy_mock.setFullPropositionPower(51_000 * 10 ** 18, {"from": owner})

    tx = governance.createProposal(payloads, voting_portal, ipfs_hash, {"from": alice})
    proposal_id = tx.events["ProposalCreated"]["proposalId"] 

    # Set proposition power in the mock contract to a value lower to minPropositionPower
    power_strategy_mock.setFullPropositionPower(49_000 * 10 ** 18, {"from": owner})
    
    # time warp
    cooldown_before_voting_start = voting_config_level1["cooldown_before_voting_start"]
    delta = cooldown_before_voting_start + 20
    chain.mine(timedelta=delta)

    with reverts("4"): # PROPOSITION_POWER_IS_TOO_LOW
        governance.activateVoting(proposal_id, {"from": owner})


def test_vote_via_portal(setup_protocol, owner, alice, bob, voting_config_level1, voting_tokens):
    """
    Testing `voteViaPortal()`
    """
    #Setup    
    governance = setup_protocol["governance"]
    power_strategy_mock = setup_protocol["power_strategy_mock"]
    voting_portal = setup_protocol["voting_portal"]

    # Set proposition power in the mock contract
    power_strategy_mock.setFullPropositionPower(60_000 * 10 ** 18, {"from": owner})

    # Create proposal 
    payload_1 = [
        1, # chainId
        1, # Level_1
        owner, # payloadController
        7, # payloadId
    ]
    payloads = [payload_1]
    ipfs_hash =  b"\xa1" + b"\x00" * 31
    tx = governance.createProposal(payloads, voting_portal, ipfs_hash, {"from": alice})
    proposal_id = tx.events["ProposalCreated"]["proposalId"] 

    # time warp
    cooldown_before_voting_start = voting_config_level1["cooldown_before_voting_start"]
    delta = cooldown_before_voting_start + 20
    chain.mine(timedelta=delta)
    # call `activateVoting()`
    governance.activateVoting(proposal_id, {"from": owner})

    # call `voteViaPortal()`
    support = True
    token_a = voting_tokens["TokenA"]
    token_b = voting_tokens["TokenB"]
    voting_assets_with_slot = [[token_a, 0], [token_b, 0]]
    tx = governance.voteViaPortal(
        proposal_id, 
        support, 
        voting_assets_with_slot,
        {"from": bob}
    )

    # Validation
    # logs
    assert tx.events["VoteForwarded"]["proposalId"] == proposal_id
    assert tx.events["VoteForwarded"]["voter"] == bob
    assert tx.events["VoteForwarded"]["support"] is support
    assert tx.events["VoteForwarded"]["votingAssetsWithSlot"][0][0] == voting_assets_with_slot[0][0]
    assert tx.events["VoteForwarded"]["votingAssetsWithSlot"][0][1] == voting_assets_with_slot[0][1]
    assert tx.events["VoteForwarded"]["votingAssetsWithSlot"][1][0] == voting_assets_with_slot[1][0]
    assert tx.events["VoteForwarded"]["votingAssetsWithSlot"][1][1] == voting_assets_with_slot[1][1]
   

def test_vote_via_portal_proposal_not_active(setup_protocol, owner, voting_tokens):
    """
    Testing `voteViaPortal()` when the proposal is not active state
    """
    #Setup    
    governance = setup_protocol["governance"]

    proposal_id = 1337
    support = True
    token_a = voting_tokens["TokenA"]
    voting_assets_with_slot = [[token_a, 0]]
    with reverts("6"): #PROPOSAL_NOT_IN_ACTIVE_STATE
        governance.voteViaPortal(
        proposal_id, 
        support, 
        voting_assets_with_slot,
        {"from": owner}
        )


def test_vote_via_portal_many_voting_tokens(setup_protocol, owner, alice, voting_config_level1, voting_tokens):
    """
    Testing `voteViaPortal()`when the number of voting tokens is bigger than the cap
    """
    #Setup    
    governance = setup_protocol["governance"]
    power_strategy_mock = setup_protocol["power_strategy_mock"]
    voting_portal = setup_protocol["voting_portal"]

    # Set proposition power in the mock contract
    power_strategy_mock.setFullPropositionPower(60_000 * 10 ** 18, {"from": owner})

    # Create proposal 
    payload_1 = [
        1, # chainId
        1, # Level_1
        owner, # payloadController
        7, # payloadId
    ]
    payloads = [payload_1]
    ipfs_hash =  b"\xa1" + b"\x00" * 31
    tx = governance.createProposal(payloads, voting_portal, ipfs_hash, {"from": alice})
    proposal_id = tx.events["ProposalCreated"]["proposalId"] 

    # time warp
    cooldown_before_voting_start = voting_config_level1["cooldown_before_voting_start"]
    delta = cooldown_before_voting_start + 20
    chain.mine(timedelta=delta)
    # call `activateVoting()`
    governance.activateVoting(proposal_id, {"from": owner})

    # call `voteViaPortal()`
    support = True
    token_a = voting_tokens["TokenA"]
    voting_assets_with_slot = []
    for i in range(10):
        voting_assets_with_slot.append([token_a, 0])

    with reverts('9'): # INVALID_VOTING_TOKENS
        governance.voteViaPortal(
        proposal_id, 
        support, 
        voting_assets_with_slot,
        {"from": owner}
        )
        

def test_queue_proposal_passed_proposal(setup_protocol, owner, alice, voting_config_level1, constants):
    """
    Testing `queueProposal()` for a passed proposal
    """
    #Setup    
    governance = setup_protocol["governance"]
    power_strategy_mock = setup_protocol["power_strategy_mock"]
    voting_portal = setup_protocol["voting_portal"]

    # Set proposition power in the mock contract
    power_strategy_mock.setFullPropositionPower(60_000 * 10 ** 18, {"from": owner})

    # Create proposal 
    payload_1 = [
        1, # chainId
        1, # Level_1
        owner, # payloadController
        7, # payloadId
    ]
    payloads = [payload_1]
    ipfs_hash =  b"\xa1" + b"\x00" * 31
    tx = governance.createProposal(payloads, voting_portal, ipfs_hash, {"from": alice})
    proposal_id = tx.events["ProposalCreated"]["proposalId"] 

    # time warp
    cooldown_before_voting_start = voting_config_level1["cooldown_before_voting_start"]
    delta = cooldown_before_voting_start + 20
    chain.mine(timedelta=delta)
    # call `activateVoting()`
    governance.activateVoting(proposal_id, {"from": owner})

    # call `queueProposal()`
    for_votes = voting_config_level1["yes_threshold"] + 10_000 * 10 ** 18
    against_votes = 5_000 * 10 ** 18
    # time warp
    voting_duration = voting_config_level1["voting_duration"]
    delta = voting_duration + 20
    chain.mine(timedelta=delta)
    tx = governance.queueProposal(proposal_id, for_votes, against_votes, {"from": voting_portal})

    # Validation
    proposal = governance.getProposal(proposal_id)
    assert proposal["state"] == constants.proposalState["Queued"]
    assert proposal["forVotes"] == for_votes
    assert proposal["againstVotes"] == against_votes
    #logs
    assert tx.events["ProposalQueued"]["proposalId"] == proposal_id
    assert tx.events["ProposalQueued"]["votesFor"] == for_votes
    assert tx.events["ProposalQueued"]["votesAgainst"] == against_votes


def test_queue_proposal_failed_proposal_case_1(setup_protocol, owner, alice, voting_config_level1, constants):
    """
    Testing `queueProposal()` for a failed proposal (quorum not passed)
    """
    #Setup    
    governance = setup_protocol["governance"]
    power_strategy_mock = setup_protocol["power_strategy_mock"]
    voting_portal = setup_protocol["voting_portal"]

    # Set proposition power in the mock contract
    power_strategy_mock.setFullPropositionPower(60_000 * 10 ** 18, {"from": owner})

    # Create proposal 
    payload_1 = [
        1, # chainId
        1, # Level_1
        owner, # payloadController
        7, # payloadId
    ]
    payloads = [payload_1]
    ipfs_hash =  b"\xa1" + b"\x00" * 31
    tx = governance.createProposal(payloads, voting_portal, ipfs_hash, {"from": alice})
    proposal_id = tx.events["ProposalCreated"]["proposalId"] 

    # time warp
    cooldown_before_voting_start = voting_config_level1["cooldown_before_voting_start"]
    delta = cooldown_before_voting_start + 20
    chain.mine(timedelta=delta)
    # call `activateVoting()`
    governance.activateVoting(proposal_id, {"from": owner})

    # call `queueProposal()`
    for_votes = voting_config_level1["yes_threshold"] - 10_000 * 10 ** 18
    against_votes = 5_000 * 10 ** 18
    # time warp
    voting_duration = voting_config_level1["voting_duration"]
    delta = voting_duration + 20
    chain.mine(timedelta=delta)
    
    tx = governance.queueProposal(proposal_id, for_votes, against_votes, {"from": voting_portal})

    # Validation
    proposal = governance.getProposal(proposal_id)
    assert proposal["state"] == constants.proposalState["Failed"]
    assert proposal["forVotes"] == for_votes
    assert proposal["againstVotes"] == against_votes
    #logs
    assert tx.events["ProposalFailed"]["proposalId"] == proposal_id
    assert tx.events["ProposalFailed"]["votesFor"] == for_votes
    assert tx.events["ProposalFailed"]["votesAgainst"] == against_votes


def test_queue_proposal_failed_proposal_case_2(setup_protocol, owner, alice, voting_config_level1, constants):
    """
    Testing `queueProposal()` for a failed proposal (differential not passed)
    """
    #Setup    
    governance = setup_protocol["governance"]
    power_strategy_mock = setup_protocol["power_strategy_mock"]
    voting_portal = setup_protocol["voting_portal"]

    # Set proposition power in the mock contract
    power_strategy_mock.setFullPropositionPower(60_000 * 10 ** 18, {"from": owner})

    # Create proposal 
    payload_1 = [
        1, # chainId
        1, # Level_1
        owner, # payloadController
        7, # payloadId
    ]
    payloads = [payload_1]
    ipfs_hash =  b"\xa1" + b"\x00" * 31
    tx = governance.createProposal(payloads, voting_portal, ipfs_hash, {"from": alice})
    proposal_id = tx.events["ProposalCreated"]["proposalId"] 

    # time warp
    cooldown_before_voting_start = voting_config_level1["cooldown_before_voting_start"]
    delta = cooldown_before_voting_start + 20
    chain.mine(timedelta=delta)
    # call `activateVoting()`
    governance.activateVoting(proposal_id, {"from": owner})

    # call `queueProposal()`
    for_votes = voting_config_level1["yes_threshold"] + 10_000 * 10 ** 18
    against_votes = for_votes - voting_config_level1["yes_no_differential"] + 5_000 * 10 ** 18
    assert for_votes - against_votes <= voting_config_level1["yes_no_differential"]

    # time warp
    voting_duration = voting_config_level1["voting_duration"]
    delta = voting_duration + 20
    chain.mine(timedelta=delta)
    
    tx = governance.queueProposal(proposal_id, for_votes, against_votes, {"from": voting_portal})

    # Validation
    proposal = governance.getProposal(proposal_id)
    assert proposal["state"] == constants.proposalState["Failed"]
    assert proposal["forVotes"] == for_votes
    assert proposal["againstVotes"] == against_votes
    #logs
    assert tx.events["ProposalFailed"]["proposalId"] == proposal_id
    assert tx.events["ProposalFailed"]["votesFor"] == for_votes
    assert tx.events["ProposalFailed"]["votesAgainst"] == against_votes



def test_queue_proposal_invalid_caller(setup_protocol, owner, alice, voting_config_level1):
    """
    Testing `queueProposal()` when the caller is not the voting portal
    """
    #Setup    
    governance = setup_protocol["governance"]
    power_strategy_mock = setup_protocol["power_strategy_mock"]
    voting_portal = setup_protocol["voting_portal"]

    # Set proposition power in the mock contract
    power_strategy_mock.setFullPropositionPower(60_000 * 10 ** 18, {"from": owner})

    # Create proposal 
    payload_1 = [
        1, # chainId
        1, # Level_1
        owner, # payloadController
        7, # payloadId
    ]
    payloads = [payload_1]
    ipfs_hash =  b"\xa1" + b"\x00" * 31
    tx = governance.createProposal(payloads, voting_portal, ipfs_hash, {"from": alice})

    proposal_id = tx.events["ProposalCreated"]["proposalId"] 
    for_votes = voting_config_level1["yes_threshold"] + 10_000 * 10 ** 18
    against_votes = 5_000 * 10 ** 18 

    with reverts("10"): #CALLER_NOT_A_VALID_VOTING_PORTAL
        governance.queueProposal(proposal_id, for_votes, against_votes, {"from": owner})



def test_queue_proposal_not_active(setup_protocol, owner, alice, voting_config_level1):
    """
    Testing `queueProposal()` when the proposal is not in active state
    """
    #Setup    
    governance = setup_protocol["governance"]
    power_strategy_mock = setup_protocol["power_strategy_mock"]
    voting_portal = setup_protocol["voting_portal"]

    # Set proposition power in the mock contract
    power_strategy_mock.setFullPropositionPower(60_000 * 10 ** 18, {"from": owner})

    # Create proposal 
    payload_1 = [
        1, # chainId
        1, # Level_1
        owner, # payloadController
        7, # payloadId
    ]
    payloads = [payload_1]
    ipfs_hash =  b"\xa1" + b"\x00" * 31
    tx = governance.createProposal(payloads, voting_portal, ipfs_hash, {"from": alice})
    
    proposal_id = tx.events["ProposalCreated"]["proposalId"] 
    for_votes = voting_config_level1["yes_threshold"] + 10_000 * 10 ** 18
    against_votes = 5_000 * 10 ** 18 

    with reverts("6"): #PROPOSAL_NOT_IN_ACTIVE_STATE
        governance.queueProposal(proposal_id, for_votes, against_votes, {"from": voting_portal})



def test_execute_proposal(setup_protocol, owner, alice, voting_config_level2, constants):
    """
    Testing `executeProposal()` 
    """
    #Setup    
    governance = setup_protocol["governance"]
    power_strategy_mock = setup_protocol["power_strategy_mock"]
    voting_portal = setup_protocol["voting_portal"]

    # Set proposition power in the mock contract
    power_strategy_mock.setFullPropositionPower(81_000 * 10 ** 18, {"from": owner})

    # Create proposal 
    # proposal_1
    chain_id = 1
    access_level = 1
    payload_controller = owner # just for testing
    payload_id = 7 
    payload_1 = [ chain_id, access_level, payload_controller, payload_id]

    # proposal_2
    chain_id = 1
    access_level = 2
    payload_controller = alice # just for testing
    payload_id = 13
    payload_2 = [ chain_id, access_level, payload_controller, payload_id]
   
    payloads = [payload_1, payload_2]
    ipfs_hash =  b"\xa1" + b"\x00" * 31
    tx = governance.createProposal(payloads, voting_portal, ipfs_hash, {"from": alice})
    proposal_id = tx.events["ProposalCreated"]["proposalId"] 

    # time warp
    cooldown_before_voting_start = voting_config_level2["cooldown_before_voting_start"]
    delta = cooldown_before_voting_start + 20
    chain.mine(timedelta=delta)
    # call `activateVoting()`
    governance.activateVoting(proposal_id, {"from": owner})

    # call `queueProposal()`
    for_votes = voting_config_level2["yes_threshold"] + 10_000 * 10 ** 18
    against_votes = 5_000 * 10 ** 18

    # time warp
    voting_duration = voting_config_level2["voting_duration"]
    delta = voting_duration + 20
    chain.mine(timedelta=delta)
    governance.queueProposal(proposal_id, for_votes, against_votes, {"from": voting_portal})

    # call `executeProposal()`
    delta = constants.COOLDOWN_PERIOD + 20
    chain.mine(timedelta=delta)
    tx = governance.executeProposal(proposal_id, {"from": owner})

    # Validation
    proposal = governance.getProposal(proposal_id)
    assert proposal["state"] == constants.proposalState["Executed"]
    # logs
    for i,payload in enumerate(payloads):
        assert tx.events["PayloadSent"][i]["proposalId"] == proposal_id
        assert tx.events["PayloadSent"][i]["chainId"] == payload[0]
        assert tx.events["PayloadSent"][i]["payloadsController"] == payload[2]
        assert tx.events["PayloadSent"][i]["payloadId"] == payload[3]
        assert tx.events["PayloadSent"][i]["payloadNumberOnProposal"] == i
        assert tx.events["PayloadSent"][i]["numberOfPayloadsOnProposal"] == len(payloads)

    assert tx.events["ProposalExecuted"]["proposalId"] == proposal_id



def test_execute_proposal_not_in_queued_state(setup_protocol, owner, alice):
    """
    Testing `executeProposal()` when the proposal is not in queued state
    """
    #Setup    
    governance = setup_protocol["governance"]
    power_strategy_mock = setup_protocol["power_strategy_mock"]
    voting_portal = setup_protocol["voting_portal"]

    # Set proposition power in the mock contract
    power_strategy_mock.setFullPropositionPower(60_000 * 10 ** 18, {"from": owner})

    # Create proposal 
    # proposal_1
    chain_id = 1
    access_level = 1
    payload_controller = owner # just for testing
    payload_id = 7 
    payload_1 = [ chain_id, access_level, payload_controller, payload_id]

    payloads = [payload_1]
    ipfs_hash =  b"\xa1" + b"\x00" * 31
    tx = governance.createProposal(payloads, voting_portal, ipfs_hash, {"from": alice})
    proposal_id = tx.events["ProposalCreated"]["proposalId"] 

    with reverts('7'): # PROPOSAL_NOT_IN_QUEUED_STATE
        governance.executeProposal(proposal_id, {"from": owner})



def test_execute_proposal_cooldown_period_not_passed(setup_protocol, owner, alice, voting_config_level1, constants):
    """
    Testing `executeProposal()` when the cooldown period is not passed yet
    """
    #Setup    
    governance = setup_protocol["governance"]
    power_strategy_mock = setup_protocol["power_strategy_mock"]
    voting_portal = setup_protocol["voting_portal"]

    # Set proposition power in the mock contract
    power_strategy_mock.setFullPropositionPower(60_000 * 10 ** 18, {"from": owner})

    # Create proposal 
    # proposal_1
    chain_id = 1
    access_level = 1
    payload_controller = owner # just for testing
    payload_id = 7 
    payload_1 = [ chain_id, access_level, payload_controller, payload_id]

    payloads = [payload_1]
    ipfs_hash =  b"\xa1" + b"\x00" * 31
    tx = governance.createProposal(payloads, voting_portal, ipfs_hash, {"from": alice})
    proposal_id = tx.events["ProposalCreated"]["proposalId"] 

    # time warp
    cooldown_before_voting_start = voting_config_level1["cooldown_before_voting_start"]
    delta = cooldown_before_voting_start + 20
    chain.mine(timedelta=delta)
    # call `activateVoting()`
    governance.activateVoting(proposal_id, {"from": owner})

    # call `queueProposal()`
    for_votes = voting_config_level1["yes_threshold"] + 10_000 * 10 ** 18
    against_votes = 5_000 * 10 ** 18
    # time warp
    voting_duration = voting_config_level1["voting_duration"]
    delta = voting_duration + 20
    chain.mine(timedelta=delta)
    governance.queueProposal(proposal_id, for_votes, against_votes, {"from": voting_portal})

    #time wrap
    delta = constants.COOLDOWN_PERIOD - 20
    chain.mine(timedelta=delta)

    with reverts('11'): #QUEUE_COOLDOWN_PERIOD_NOT_PASSED
        governance.executeProposal(proposal_id, {"from": owner})



def test_execute_proposal_proposition_power_low(setup_protocol, owner, alice, voting_config_level1, constants):
    """
    Testing `executeProposal()` when the proposition power is not enough
    """
    #Setup    
    governance = setup_protocol["governance"]
    power_strategy_mock = setup_protocol["power_strategy_mock"]
    voting_portal = setup_protocol["voting_portal"]

    # Set proposition power in the mock contract
    power_strategy_mock.setFullPropositionPower(60_000 * 10 ** 18, {"from": owner})

    # Create proposal 
    # proposal_1
    chain_id = 1
    access_level = 1
    payload_controller = owner # just for testing
    payload_id = 7 
    payload_1 = [ chain_id, access_level, payload_controller, payload_id]

    payloads = [payload_1]
    ipfs_hash =  b"\xa1" + b"\x00" * 31
    tx = governance.createProposal(payloads, voting_portal, ipfs_hash, {"from": alice})
    proposal_id = tx.events["ProposalCreated"]["proposalId"] 

    # time warp
    cooldown_before_voting_start = voting_config_level1["cooldown_before_voting_start"]
    delta = cooldown_before_voting_start + 20
    chain.mine(timedelta=delta)
    # call `activateVoting()`
    governance.activateVoting(proposal_id, {"from": owner})

    # call `queueProposal()`
    for_votes = voting_config_level1["yes_threshold"] + 10_000 * 10 ** 18
    against_votes = 5_000 * 10 ** 18
    # time warp
    voting_duration = voting_config_level1["voting_duration"]
    delta = voting_duration + 20
    chain.mine(timedelta=delta)
    governance.queueProposal(proposal_id, for_votes, against_votes, {"from": voting_portal})

    # time wrap
    delta = constants.COOLDOWN_PERIOD + 20
    chain.mine(timedelta=delta)

    # Set proposition power in the mock contract to  a value lower to minPropositionPower
    power_strategy_mock.setFullPropositionPower(49_000 * 10 ** 18, {"from": owner})

    with reverts("4"): #PROPOSITION_POWER_IS_TOO_LOW
        governance.executeProposal(proposal_id, {"from": owner})



def test_cancel_proposal_case_1(setup_protocol, owner, alice, constants):
    """
    Testing `cancelProposal()`
    case 1: the caller is the proposalCreator 
    """
    #Setup    
    governance = setup_protocol["governance"]
    power_strategy_mock = setup_protocol["power_strategy_mock"]
    voting_portal = setup_protocol["voting_portal"]

    # Set proposition power in the mock contract
    power_strategy_mock.setFullPropositionPower(60_000 * 10 ** 18, {"from": owner})

    # Create proposal 
    # proposal_1
    chain_id = 1
    access_level = 1
    payload_controller = owner # just for testing
    payload_id = 7 
    payload_1 = [ chain_id, access_level, payload_controller, payload_id]

    payloads = [payload_1]
    ipfs_hash =  b"\xa1" + b"\x00" * 31
    proposal_creator = alice
    tx = governance.createProposal(payloads, voting_portal, ipfs_hash, {"from": proposal_creator})
    proposal_id = tx.events["ProposalCreated"]["proposalId"] 

    # Set proposition power in the mock contract to  a value lower to minPropositionPower
    # Even if the proposalCreator power is less than the minPropositionPower
    # the call to `cancelProposal()` succeeds as the caller is the proposalCreator
    power_strategy_mock.setFullPropositionPower(49_000 * 10 ** 18, {"from": owner})

    # call `cancelProposal()`
    tx = governance.cancelProposal(proposal_id, {"from": proposal_creator})

    # Validation
    proposal = governance.getProposal(proposal_id)
    assert proposal["state"] == constants.proposalState["Cancelled"]
    assert proposal["cancelTimestamp"] == tx.timestamp
    # logs 
    assert tx.events["ProposalCanceled"]["proposalId"] == proposal_id


def test_cancel_proposal_case_2(setup_protocol, owner, alice, constants, guardian):
    """
    Testing `cancelProposal()`
    case 2: the caller is the guardian & the proposalCreator has enough proposition power
    """
    #Setup    
    governance = setup_protocol["governance"]
    power_strategy_mock = setup_protocol["power_strategy_mock"]
    voting_portal = setup_protocol["voting_portal"]

    # Set proposition power in the mock contract
    power_strategy_mock.setFullPropositionPower(60_000 * 10 ** 18, {"from": owner})

    # Create proposal 
    # proposal_1
    chain_id = 1
    access_level = 1
    payload_controller = owner # just for testing
    payload_id = 7 
    payload_1 = [ chain_id, access_level, payload_controller, payload_id]

    payloads = [payload_1]
    ipfs_hash =  b"\xa1" + b"\x00" * 31
    proposal_creator = alice
    tx = governance.createProposal(payloads, voting_portal, ipfs_hash, {"from": proposal_creator})
    proposal_id = tx.events["ProposalCreated"]["proposalId"] 

    # call `cancelProposal()`
    tx = governance.cancelProposal(proposal_id, {"from": guardian})

    # Validation
    proposal = governance.getProposal(proposal_id)
    assert proposal["state"] == constants.proposalState["Cancelled"]
    assert proposal["cancelTimestamp"] == tx.timestamp
    # logs 
    assert tx.events["ProposalCanceled"]["proposalId"] == proposal_id


def test_cancel_proposal_wrong_proposal_state_case_1(setup_protocol, owner):
    """
    Testing `cancelProposal()` for a wrong proposal state
    Case 1 : State = Null - proposal not cretaed yet
    """
    #Setup    
    governance = setup_protocol["governance"]

    proposal_id = 2015 # doesn't exist
    with reverts("12"): #PROPOSAL_NOT_IN_THE_CORRECT_STATE
        governance.cancelProposal(proposal_id, {"from": owner})


def test_cancel_proposal_wrong_proposal_state_case_2(setup_protocol, owner, alice, voting_config_level1):
    """
    Testing `cancelProposal()` for a wrong proposal state
    Case 2:Proposal created but not in a state >= Executed ( e.g: Failed)
    """
    #Setup    
    governance = setup_protocol["governance"]
    power_strategy_mock = setup_protocol["power_strategy_mock"]
    voting_portal = setup_protocol["voting_portal"]

    # Set proposition power in the mock contract
    power_strategy_mock.setFullPropositionPower(60_000 * 10 ** 18, {"from": owner})

    # Create proposal 
    payload_1 = [
        1, # chainId
        1, # Level_1
        owner, # payloadController
        7, # payloadId
    ]
    payloads = [payload_1]
    ipfs_hash =  b"\xa1" + b"\x00" * 31
    tx = governance.createProposal(payloads, voting_portal, ipfs_hash, {"from": alice})
    proposal_id = tx.events["ProposalCreated"]["proposalId"] 

    # time warp
    cooldown_before_voting_start = voting_config_level1["cooldown_before_voting_start"]
    delta = cooldown_before_voting_start + 20
    chain.mine(timedelta=delta)
    # call `activateVoting()`
    governance.activateVoting(proposal_id, {"from": owner})

    # call `queueProposal()`
    for_votes = voting_config_level1["yes_threshold"] + 10_000 * 10 ** 18
    against_votes = for_votes - voting_config_level1["yes_no_differential"] + 5_000 * 10 ** 18
    assert for_votes - against_votes <= voting_config_level1["yes_no_differential"]

    # time warp
    voting_duration = voting_config_level1["voting_duration"]
    delta = voting_duration + 20
    chain.mine(timedelta=delta)
    governance.queueProposal(proposal_id, for_votes, against_votes, {"from": voting_portal})

    with reverts("12"): #PROPOSAL_NOT_IN_THE_CORRECT_STATE
        governance.cancelProposal(proposal_id, {"from": owner})



def test_add_voting_portals(setup_protocol, owner, alice):
    """
    Testing `addVotingPortals()`
    """
    #Setup    
    governance = setup_protocol["governance"]

    voting_portal_count_before = governance.getVotingPortalsCount()

    voting_portal= alice
    voting_portals = [voting_portal]
    tx = governance.addVotingPortals(voting_portals, {"from": owner})

    # Validation 
    assert governance.isVotingPortalApproved(voting_portal) is True
    assert governance.getVotingPortalsCount() == voting_portal_count_before + len(voting_portals)
    # log
    assert tx.events["VotingPortalUpdated"]["votingPortal"] == voting_portal
    assert tx.events["VotingPortalUpdated"]["approved"] is True


def test_remove_voting_portals(setup_protocol, owner):
    """
    Testing `removeVotingPortals()`
    """
    #Setup    
    governance = setup_protocol["governance"]
    voting_portal = setup_protocol["voting_portal"]

    voting_portal_count_before = governance.getVotingPortalsCount()

    voting_portals = [voting_portal]
    tx = governance.removeVotingPortals(voting_portals, {"from": owner})

    # Validation 
    assert governance.isVotingPortalApproved(voting_portal) is False
    assert governance.getVotingPortalsCount() == voting_portal_count_before - len(voting_portals)
    # log
    assert tx.events["VotingPortalUpdated"]["votingPortal"] == voting_portal
    assert tx.events["VotingPortalUpdated"]["approved"] is False


def test_rescue_voting_portal(setup_protocol, owner, alice, guardian):
    """
    Testing `rescueVotingPortal()` 
    """
    #Setup    
    governance = setup_protocol["governance"]
    voting_portal = setup_protocol["voting_portal"]

    # Remove protal first
    voting_portals = [voting_portal]
    tx = governance.removeVotingPortals(voting_portals, {"from": owner})


    voting_portal= alice
    tx = governance.rescueVotingPortal(voting_portal, {"from": guardian})

    # Validation 
    assert governance.isVotingPortalApproved(voting_portal) is True
    # log
    assert tx.events["VotingPortalUpdated"]["votingPortal"] == voting_portal
    assert tx.events["VotingPortalUpdated"]["approved"] is True


def test_rescue_voting_portal_voting_count_not_zero(setup_protocol, alice, guardian):
    """
    Testing `rescueVotingPortal()`  when the VotingPortalsCount is not zero
    """
    #Setup    
    governance = setup_protocol["governance"]
    voting_portal = setup_protocol["voting_portal"]

    voting_portal= alice

    with reverts('1'):
        governance.rescueVotingPortal(voting_portal, {"from": guardian})


# ************************************
# ***** ****** Setters  ***************

def test_set_power_strategy(setup_protocol, owner, MockPowerStrategy):
    """
    Testing `setPowerStrategy()`
    """
    #Setup    
    governance = setup_protocol["governance"]

    new_power_strategy = MockPowerStrategy.deploy({"from": owner})
    tx = governance.setPowerStrategy(new_power_strategy, {"from": owner})

    # Validation 
    assert governance.getPowerStrategy() == new_power_strategy
    # log
    assert tx.events["PowerStrategyUpdated"]["newPowerStrategy"] == new_power_strategy


def test_set_voting_configs(setup_protocol, owner):
    """
    Testing `setVotingConfigs()`
    """
    #Setup    
    governance = setup_protocol["governance"]

    access_level = 2 #  LEVEL_2
    voting_duration = 60 * 60 * 24 * 10 # 10 days
    cooldown_before_voting_start = 60 * 60 * 24 * 3 # 3 days
    yes_threshold = 400_000 * 10 ** 18 # quorum (400000 ether)
    yes_no_differential = 150_000 * 10 ** 18 #differential (150000 ether)
    min_proposition_power = 80_000 * 10 ** 18

    voting_config_level_2 = [
        access_level,  
        cooldown_before_voting_start, 
        voting_duration,
        yes_threshold, 
        yes_no_differential,
        min_proposition_power
    ]

    tx = governance.setVotingConfigs([voting_config_level_2], {"from": owner})

    # Validation 
    voting_config = governance.getVotingConfig(access_level)
    assert voting_config["coolDownBeforeVotingStart"] == cooldown_before_voting_start
    assert voting_config["votingDuration"] == voting_duration
    assert voting_config["yesThreshold"] == yes_threshold // 10 ** 18
    assert voting_config["yesNoDifferential"] == yes_no_differential // 10 ** 18 # // 10 ** 18 as the values are normilized 
    assert voting_config["minPropositionPower"] == min_proposition_power // 10 ** 18
    # log
    assert tx.events["VotingConfigUpdated"]["accessLevel"] == access_level
    assert tx.events["VotingConfigUpdated"]["votingDuration"] == voting_duration
    assert tx.events["VotingConfigUpdated"]["coolDownBeforeVotingStart"] == cooldown_before_voting_start
    assert tx.events["VotingConfigUpdated"]["yesThreshold"] == yes_threshold // 10 ** 18
    assert tx.events["VotingConfigUpdated"]["yesNoDifferential"] == yes_no_differential // 10 ** 18
    assert tx.events["VotingConfigUpdated"]["minPropositionPower"] == min_proposition_power // 10 ** 18

