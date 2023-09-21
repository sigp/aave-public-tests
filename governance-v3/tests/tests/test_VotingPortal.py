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
import secrets

from eth_abi import encode_abi


def test_constructor(setup_protocol, constants):
    """
    checking the immutable variables inside the votingPortal contrat
    """
    voting_portal = setup_protocol["voting_portal"]
    governance = setup_protocol["governance"]
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    voting_machine = setup_protocol["voting_machine"]

    assert voting_portal.GOVERNANCE() == governance
    assert voting_portal.getStartVotingGasLimit() == 0
    assert voting_portal.getVoteViaPortalGasLimit() == 0
    assert voting_portal.CROSS_CHAIN_CONTROLLER() == cross_chain_controller.address
    assert voting_portal.VOTING_MACHINE() == voting_machine
    assert voting_portal.VOTING_MACHINE_CHAIN_ID() == constants.VOTING_MACHINE_CHAIN_ID


def test_receive_cross_chain_message_delivered_vote_case_1(setup_protocol, owner, alice, constants, voting_config_level1 ):
    """
    Testing `receiveCrossChainMessage()` when the the message is delivered and executed
    Case 1 : proposal queued
    """
    #Setup    
    governance = setup_protocol["governance"]
    power_strategy_mock = setup_protocol["power_strategy_mock"]
    voting_portal = setup_protocol["voting_portal"]
    voting_machine = setup_protocol["voting_machine"]
    cross_chain_controller = setup_protocol["cross_chain_controller"]

    # Set proposition power in the mock contract
    power_strategy_mock.setFullPropositionPower(60_000 * 10 ** 18, {"from": owner})
    acces_level = 1 # Level_1
    # Create proposal 
    payload_1 = [
        1, # chainId
        acces_level, # Level_1
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


    # call `receiveCrossChainMessage()`
    origin_sender = voting_machine
    origin_chain_id = constants.VOTING_MACHINE_CHAIN_ID
    for_votes = voting_config_level1["yes_threshold"] + 10_000 * 10 ** 18
    against_votes = 5_000 * 10 ** 18
    message = encode_abi(["uint256", "uint128", "uint128"], [proposal_id, for_votes, against_votes])
    
    # time wrap
    voting_duration = voting_config_level1["voting_duration"]
    chain.mine(timedelta=voting_duration + 1)

    tx = voting_portal.receiveCrossChainMessage(
        origin_sender, 
        origin_chain_id,
        message,
        {"from": cross_chain_controller}
    )

    # Validation 
    proposal = governance.getProposal(proposal_id)
    assert proposal["state"] == constants.proposalState["Queued"]
    assert proposal["forVotes"] == for_votes
    assert proposal["againstVotes"] == against_votes
    #logs
    assert tx.events["ProposalQueued"]["proposalId"] == proposal_id
    assert tx.events["ProposalQueued"]["votesFor"] == for_votes
    assert tx.events["ProposalQueued"]["votesAgainst"] == against_votes
    assert tx.events["VoteMessageReceived"]["originSender"] == origin_sender
    assert tx.events["VoteMessageReceived"]["originChainId"] == origin_chain_id
    assert tx.events["VoteMessageReceived"]["delivered"] is True
    assert tx.events["VoteMessageReceived"]["message"].hex() == message.hex()


def test_receive_cross_chain_message_delivered_vote_case_2(setup_protocol, owner, alice, constants, voting_config_level1 ):
    """
    Testing `receiveCrossChainMessage()` when the the message is delivered and executed
    Case 2 : proposal failed
    """
    #Setup    
    governance = setup_protocol["governance"]
    power_strategy_mock = setup_protocol["power_strategy_mock"]
    voting_portal = setup_protocol["voting_portal"]
    voting_machine = setup_protocol["voting_machine"]
    cross_chain_controller = setup_protocol["cross_chain_controller"]

    # Set proposition power in the mock contract
    power_strategy_mock.setFullPropositionPower(60_000 * 10 ** 18, {"from": owner})

    # Create proposal 
    acces_level = 1 # Level_1
    payload_1 = [
        1, # chainId
        acces_level, # Level_1
        owner, # payloadController
        7, # payloadId
    ]
    payloads = [payload_1]
    acces_level = 1 # Level_1
    ipfs_hash =  b"\xa1" + b"\x00" * 31
    tx = governance.createProposal(payloads, voting_portal, ipfs_hash, {"from": alice})
    proposal_id = tx.events["ProposalCreated"]["proposalId"] 

    # time warp
    cooldown_before_voting_start = voting_config_level1["cooldown_before_voting_start"]
    delta = cooldown_before_voting_start + 20
    chain.mine(timedelta=delta)
    # call `activateVoting()`
    governance.activateVoting(proposal_id, {"from": owner})


    # call `receiveCrossChainMessage()`
    origin_sender = voting_machine
    origin_chain_id = constants.VOTING_MACHINE_CHAIN_ID
    for_votes = voting_config_level1["yes_threshold"] - 10_000 * 10 ** 18
    against_votes = 5_000 * 10 ** 18
    message = encode_abi(["uint256", "uint128", "uint128"], [proposal_id, for_votes, against_votes])

    # time wrap
    voting_duration = voting_config_level1["voting_duration"]
    chain.mine(timedelta=voting_duration + 1)

    tx = voting_portal.receiveCrossChainMessage(
        origin_sender, 
        origin_chain_id,
        message,
        {"from": cross_chain_controller}
    )

    # Validation 
    proposal = governance.getProposal(proposal_id)
    assert proposal["state"] == constants.proposalState["Failed"]
    assert proposal["forVotes"] == for_votes
    assert proposal["againstVotes"] == against_votes
    #logs
    assert tx.events["ProposalFailed"]["proposalId"] == proposal_id
    assert tx.events["ProposalFailed"]["votesFor"] == for_votes
    assert tx.events["ProposalFailed"]["votesAgainst"] == against_votes
    assert tx.events["VoteMessageReceived"]["originSender"] == origin_sender
    assert tx.events["VoteMessageReceived"]["originChainId"] == origin_chain_id
    assert tx.events["VoteMessageReceived"]["delivered"] is True
    assert tx.events["VoteMessageReceived"]["message"].hex() == message.hex()



def test_receive_cross_chain_message_not_delivered(setup_protocol, constants, voting_config_level1 ):
    """
    Testing `receiveCrossChainMessage()` when the the message isn't delivered
    """
    #Setup    
    governance = setup_protocol["governance"]
    voting_portal = setup_protocol["voting_portal"]
    voting_machine = setup_protocol["voting_machine"]
    cross_chain_controller = setup_protocol["cross_chain_controller"]

    # call `receiveCrossChainMessage()`
    proposal_id = 1337
    origin_sender = voting_machine
    origin_chain_id = constants.VOTING_MACHINE_CHAIN_ID
    # an invalid message
    random_message = secrets.token_bytes(47)

    tx = voting_portal.receiveCrossChainMessage(
        origin_sender, 
        origin_chain_id,
        random_message,
        {"from": cross_chain_controller}
    )

    # Validation 
    assert tx.events["VoteMessageReceived"]["originSender"] == origin_sender
    assert tx.events["VoteMessageReceived"]["originChainId"] == origin_chain_id
    assert tx.events["VoteMessageReceived"]["delivered"] is False
    assert tx.events["VoteMessageReceived"]["message"].hex() == random_message.hex()


def test_forward_start_voting_message(setup_protocol):
    """
    Testing `forwardStartVotingMessage()`
    """
    #Setup    
    governance = setup_protocol["governance"]
    voting_portal = setup_protocol["voting_portal"]

    # Call forwardStartVotingMessage()
    proposal_id = 123
    block_hash = b"\xaa" + b"\x00" * 31
    voting_duration = 60 * 60 * 24 * 10 # 10 days
    tx = voting_portal.forwardStartVotingMessage(
        proposal_id, 
        block_hash,
        voting_duration,
        {"from": governance}
    )

def test_forward_start_voting_message_wrong_caller(setup_protocol, alice):
    """
    Testing `forwardStartVotingMessage()`when the caller is not the governance
    """
    #Setup       
    voting_portal = setup_protocol["voting_portal"]
    proposal_id = 123
    block_hash = b"\xaa" + b"\x00" * 31
    voting_duration = 60 * 60 * 24 * 10 # 10 days
    with reverts('13'): #CALLER_NOT_GOVERNANCE
        voting_portal.forwardStartVotingMessage(
        proposal_id, 
        block_hash,
        voting_duration,
        {"from": alice}
    )
        

def test_forward_vote_message(setup_protocol, alice, voting_tokens):
    """
    Testing `forwardVoteMessage()`
    """
    #Setup       
    voting_portal = setup_protocol["voting_portal"]
    governance = setup_protocol["governance"]
    # Call forwardVoteMessage()
    proposal_id = 123
    voter = alice
    support = True
    token_a = voting_tokens["TokenA"]
    token_b = voting_tokens["TokenB"]
    voting_assets_with_slot = [[token_a, 0], [token_b, 0]]
    voting_portal.forwardVoteMessage(
        proposal_id, 
        voter,
        support,
        voting_assets_with_slot,
        {"from": governance}
    )
        
    assert voting_portal.didVoterVoteOnProposal(proposal_id, voter) is True
        

def test_forward_vote_message_voter_already_voted(setup_protocol, alice, voting_tokens):
    """
    Testing `forwardVoteMessage()` when the voter already voted
    """
    #Setup       
    voting_portal = setup_protocol["voting_portal"]
    governance = setup_protocol["governance"]
    # Call forwardVoteMessage()
    proposal_id = 123
    voter = alice
    support = True
    token_a = voting_tokens["TokenA"]
    token_b = voting_tokens["TokenB"]
    voting_assets_with_slot = [[token_a, 0], [token_b, 0]]
    # first vote
    voting_portal.forwardVoteMessage(
        proposal_id, 
        voter,
        support,
        voting_assets_with_slot,
        {"from": governance}
    )
        
    assert voting_portal.didVoterVoteOnProposal(proposal_id, voter) is True
    
    with reverts("14"): #VOTER_ALREADY_VOTED_ON_PROPOSAL
        voting_portal.forwardVoteMessage(
        proposal_id, 
        voter,
        support,
        voting_assets_with_slot,
        {"from": governance}
    )
        
