"""✅❎⛔

External Functions:
constructor ✅
updateL1VotingPortal (removed)
getL1VotingPortal (removed)
receiveCrossChainMessage ✅
decodeVoteMessage ✅
decodeProposalMessage ✅
decodeMessage ✅

Internal Functions:
_updateL1VotingPortal (removed)
_sendVoteResults ✅ (in closeAndSendVote test)

VotingMachineWithProofs External Functions:
constructor ✅
getBridgedVoteInfo ✅ (in receiveCrossChainMessage test)
getProposalVoteConfiguration ✅ (in receiveCrossChainMessage test)
getDataWarehouse ✅ (in setDataWarehouse test)
getVotingStrategy ✅ (in setVotingStrategy test)
startProposalVote ✅ (in receiveCrossChainMessage test)
submitVoteBySignature ⛔
settleVoteFromPortal ✅
submitVote ✅
getUserProposalVote ✅ (in submitVote test)
closeAndSendVote ✅
getProposalById ✅ (in receiveCrossChainMessage test)
getProposalState
setDataWarehouse (removed)
setVotingStrategy (removed)
getProposalsVoteConfigurationIds ✅ (in test_receiveCrossChainMessage_create_proposal)

VotingMachineWithProofs Internal Functions:
_submitVote ✅ (in submitVote test)
_setDataWarehouse ✅ (in setDataWarehouse test)
_setVotingStrategy ✅ (in setVotingStrategy test)
_getProposalState ✅
_getCurrentTimeRef ✅ (in closeAndSendVote test)
_getChainId ✅ (in submitVoteBySignature test)
_createBridgedProposalVote ✅ (in receiveCrossChainMessage test)
_registerBridgedVote ✅ (in receiveCrossChainMessage test)
"""
import json
import brownie
import pytest
import secrets

from brownie import (
    # Brownie helpers
    accounts,
    web3,
    reverts,
    Wei,
    chain,
    Contract,
)

from helpers import custom_error
from eth_abi import encode_single, encode_abi, decode_single, decode_abi
from eth_abi.packed import encode_abi_packed


def test_constructor(setup_protocol, constants, owner):
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    data_warehouse = setup_protocol["data_warehouse"]
    voting_strategy = setup_protocol["voting_strategy"]
    voting_portal = setup_protocol["voting_portal"]
    voting_machine = setup_protocol["voting_machine"]

    # values directly set in VotingMachine constructor
    assert voting_machine.CROSS_CHAIN_CONTROLLER() == cross_chain_controller
    assert voting_machine.L1_VOTING_PORTAL_CHAIN_ID() == chain.id
    assert voting_machine.L1_VOTING_PORTAL() == voting_portal

    # values set in VotingMachine constructor via internal functions
    assert voting_machine.getGasLimit() == 0

    # values set in VotingMachineWithProofs constructor via internal functions
    assert voting_machine.DATA_WAREHOUSE() == data_warehouse
    assert voting_machine.VOTING_STRATEGY() == voting_strategy


def test_receiveCrossChainMessage_create_proposal(setup_protocol, constants, owner):
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    voting_portal = setup_protocol["voting_portal"]
    voting_machine = setup_protocol["voting_machine"]
    voting_strategy = setup_protocol["voting_strategy"]

    # MessageType: 0 Null, 1 Proposal, 2 Vote
    message_type = 1

    proposal_id = 17
    voting_duration = 86_400

    # Convert constants.DATA_BLOCK_HASH to hex
    block_hash_bytes = web3.toBytes(hexstr=constants.DATA_BLOCK_HASH)

    # Create a proposal message
    proposal_message = encode_abi(
        ["uint256", "bytes32", "uint24"],  # [proposalId, blockHash, votingDuration]
        [proposal_id, block_hash_bytes, voting_duration],  # [proposalId, blockHash, votingDuration]
    )

    # Now encode that into a message wth the message type
    message = encode_abi(
        ["uint8", "bytes"],  # [messageType, message]
        [message_type, proposal_message],  # [messageType, message]
    )

    # Send the message, but from the wrong origin
    with brownie.reverts("15"):  # WRONG_MESSAGE_ORIGIN
        voting_machine.receiveCrossChainMessage(voting_portal, chain.id, message, {"from": owner})

    # Send the message to the VotingMachine
    # If successful, this will call _createBridgedProposalVote and startProposalVote
    tx = voting_machine.receiveCrossChainMessage(
        voting_portal, chain.id, message, {"from": cross_chain_controller}
    )

    # Save some info about the creation transaction
    start_time = tx.timestamp
    end_time = start_time + voting_duration
    creation_block = tx.block_number

    # _createBridgedProposalVote will update this value:
    vote_config = voting_machine.getProposalVoteConfiguration(proposal_id)
    # Returns a ProposalVoteConfiguration struct:
    assert vote_config[0] == voting_duration
    assert vote_config[1] == constants.DATA_BLOCK_HASH
    # _createBridgedProposalVote will also add the proposal id to this array:
    assert voting_machine.getProposalsVoteConfigurationIds(0, 1) == [proposal_id]

    # createVote will update the proposal info:
    proposal_info = voting_machine.getProposalById(proposal_id)
    # Returns a ProposalWithoutVotes struct:
    assert proposal_info["id"] == proposal_id  # id
    assert proposal_info["startTime"] == start_time  # startTime
    assert proposal_info["endTime"] == end_time  # endTime
    assert proposal_info["creationBlockNumber"] == creation_block  # creationBlockNumber
    assert proposal_info["forVotes"] == 0  # forVotes
    assert proposal_info["againstVotes"] == 0  # againstVotes
    assert proposal_info["votingClosedAndSentBlockNumber"] == 0  # votingClosedAndSentBlockNumber
    assert proposal_info["votingClosedAndSentTimestamp"] == 0  # votingClosedAndSentTimestamp
    assert proposal_info["sentToGovernance"] is False  # sentToGovernance

    # First event will be from startProposalVote
    assert tx.events[0].address == voting_machine
    assert tx.events[0].name == "ProposalVoteStarted"
    assert tx.events[0]["proposalId"] == proposal_id
    assert tx.events[0]["l1BlockHash"] == constants.DATA_BLOCK_HASH
    assert tx.events[0]["startTime"] == start_time
    assert tx.events[0]["endTime"] == end_time

    # Second event will be from _createBridgedProposalVote
    assert tx.events[1].address == voting_machine
    assert tx.events[1].name == "ProposalVoteConfigurationBridged"
    assert tx.events[1]["proposalId"] == proposal_id
    assert tx.events[1]["blockHash"] == constants.DATA_BLOCK_HASH
    assert tx.events[1]["votingDuration"] == voting_duration
    assert tx.events[1]["voteCreated"] == True

    # Try to create the same vote again
    with brownie.reverts("42"):  # PROPOSAL_VOTE_CONFIGURATION_ALREADY_BRIDGED
        voting_machine.receiveCrossChainMessage(
            voting_portal, chain.id, message, {"from": cross_chain_controller}
        )


def test_receiveCrossChainMessage_bridge_vote(setup_protocol, constants, owner, alice):
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    voting_portal = setup_protocol["voting_portal"]
    voting_machine = setup_protocol["voting_machine"]
    voting_strategy = setup_protocol["voting_strategy"]
    # The vote should be started first
    # MessageType: 0 Null, 1 Proposal, 2 Vote
    message_type = 1

    proposal_id = 17
    voting_duration = 86_400

    # Convert constants.DATA_BLOCK_HASH to hex
    block_hash_bytes = web3.toBytes(hexstr=constants.DATA_BLOCK_HASH)

    # Create a proposal message
    proposal_message = encode_abi(
        ["uint256", "bytes32", "uint24"],  # [proposalId, blockHash, votingDuration]
        [proposal_id, block_hash_bytes, voting_duration],  # [proposalId, blockHash, votingDuration]
    )

    # Now encode that into a message wth the message type
    message = encode_abi(
        ["uint8", "bytes"],  # [messageType, message]
        [message_type, proposal_message],  # [messageType, message]
    )

    voting_machine.receiveCrossChainMessage(
        voting_portal, chain.id, message, {"from": cross_chain_controller}
    )
    # MessageType: 0 Null, 1 Proposal, 2 Vote
    message_type = 2

    proposal_id = 17
    voter = alice.address
    support = True
    voting_tokens = [[voting_strategy.AAVE(),0], [voting_strategy.A_AAVE(),52]]

    # Convert constants.DATA_BLOCK_HASH to hex
    block_hash_bytes = web3.toBytes(hexstr=constants.DATA_BLOCK_HASH)

    # Create a proposal message
    vote_message = encode_abi(
        ["uint256", "address", "bool", "(address,uint128)[]"],  # [proposalId, voter, support, VotingAssetWithSlot[]]
        [proposal_id, voter, support, voting_tokens],  # [proposalId, voter, support, VotingAssetWithSlot[]]
    )

    # Now encode that into a message wth the message type
    message = encode_abi(
        ["uint8", "bytes"],  # [messageType, message]
        [message_type, vote_message],  # [messageType, message]
    )

    # Send the message to the VotingMachine
    # If successful, this will call _registerBridgedVote
    tx = voting_machine.receiveCrossChainMessage(
        voting_portal, chain.id, message, {"from": cross_chain_controller}
    )

    # _registerBridgedVote will update this value:
    bridged_vote = voting_machine.getBridgedVoteInfo(proposal_id, voter)

    # Returns a BridgedVote struct:
    assert bridged_vote[0] == support  # support
    assert bridged_vote[1] == voting_tokens  # votingTokens

    # Check the event
    assert tx.events[0].address == voting_machine
    assert tx.events[0].name == "VoteBridged"
    assert tx.events[0]["proposalId"] == proposal_id
    assert tx.events[0]["voter"] == voter
    assert tx.events[0]["support"] == support
    assert tx.events[0]["votingAssetsWithSlot"][0][0] == voting_strategy.AAVE()
    assert tx.events[0]["votingAssetsWithSlot"][0][1] == 0
    assert tx.events[0]["votingAssetsWithSlot"][1][0] == voting_strategy.A_AAVE()
    assert tx.events[0]["votingAssetsWithSlot"][1][1] == 52


def test_receiveCrossChainMessage_encode_errors(setup_protocol, constants, owner, alice):
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    voting_portal = setup_protocol["voting_portal"]
    voting_machine = setup_protocol["voting_machine"]
    voting_strategy = setup_protocol["voting_strategy"]

    # First, a completely invalid message
    random_message = secrets.token_bytes(47)

    
    tx = voting_machine.receiveCrossChainMessage(
            voting_portal, chain.id, random_message, {"from": cross_chain_controller}
        )
    
    assert "IncorrectTypeMessageReceived" in tx.events

    # Next, an invalid proposal vote creation message
    message_type = 1

    invalid_message = encode_abi(
        ["uint8", "bytes"],  # [messageType, message]
        [message_type, random_message],  # [messageType, message]
    )

    
    tx = voting_machine.receiveCrossChainMessage(
            voting_portal, chain.id, invalid_message, {"from": cross_chain_controller}
        )

    assert tx.events["MessageReceived"]["messageType"] == message_type
    assert tx.events["MessageReceived"]["delivered"]  is False

    # Next, an invalid vote message
    message_type = 2

    invalid_message = encode_abi(
        ["uint8", "bytes"],  # [messageType, message]
        [message_type, random_message],  # [messageType, message]
    )

   
    tx = voting_machine.receiveCrossChainMessage(
            voting_portal, chain.id, invalid_message, {"from": cross_chain_controller}
        )
    assert tx.events["MessageReceived"]["messageType"] == message_type
    assert tx.events["MessageReceived"]["delivered"]  is False


def test_decodeVoteMessage(setup_protocol, constants, owner, alice):
    voting_machine = setup_protocol["voting_machine"]
    voting_strategy = setup_protocol["voting_strategy"]

    proposal_id = 17
    voter = alice.address
    support = True
    voting_tokens = [[voting_strategy.AAVE(),0], [voting_strategy.A_AAVE(),0]]

    # Create a proposal message
    vote_message = encode_abi(
        ["uint256", "address", "bool", "(address,uint128)[]"],  # [proposalId, voter, support, VotingAssetWithSlot[]]
        [proposal_id, voter, support, voting_tokens],  # [proposalId, voter, support, VotingAssetWithSlot[]]
    )

    # Decode the message
    decoded_message = voting_machine.decodeVoteMessage(vote_message)

    # Confirm the decoded message is correct
    assert decoded_message[0] == proposal_id
    assert decoded_message[1] == voter
    assert decoded_message[2] == support
    assert decoded_message[3][0][0] == voting_strategy.AAVE()
    assert decoded_message[3][0][1] == 0
    assert decoded_message[3][1][0] == voting_strategy.A_AAVE()
    assert decoded_message[3][1][1] == 0


def test_decodeProposalMessage(setup_protocol, constants, owner, alice):
    voting_machine = setup_protocol["voting_machine"]

    proposal_id = 17
    voting_duration = 86_400

    # Convert constants.DATA_BLOCK_HASH to hex
    block_hash_bytes = web3.toBytes(hexstr=constants.DATA_BLOCK_HASH)

    # Create a proposal message
    proposal_message = encode_abi(
        ["uint256", "bytes32", "uint24"],  # [proposalId, blockHash, votingDuration]
        [proposal_id, block_hash_bytes, voting_duration],  # [proposalId, blockHash, votingDuration]
    )

    # Decode the message
    decoded_message = voting_machine.decodeProposalMessage(proposal_message)

    # Confirm the decoded message is correct
    assert decoded_message[0] == proposal_id
    assert decoded_message[1] == constants.DATA_BLOCK_HASH
    assert decoded_message[2] == voting_duration


def test_decodeMessage(setup_protocol, constants, owner):
    voting_machine = setup_protocol["voting_machine"]

    # MessageType: 0 Null, 1 Proposal, 2 Vote
    message_type = 1

    # The message can be any bytes, so we will make a random one
    random_message = secrets.token_bytes(47)

    # Now encode that into a message wth the message type
    message = encode_abi(
        ["uint8", "bytes"],  # [messageType, message]
        [message_type, random_message],  # [messageType, message]
    )

    # Decode the message
    decoded_message = voting_machine.decodeMessage(message)

    # Confirm the decoded message is correct
    assert decoded_message[0] == message_type
    assert decoded_message[1] == "0x" + random_message.hex()


def test_submitVote(setup_protocol, constants, owner, proofs):
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    voting_portal = setup_protocol["voting_portal"]
    voting_machine = setup_protocol["voting_machine"]
    voting_strategy = setup_protocol["voting_strategy"]

    # MessageType: 0 Null, 1 Proposal, 2 Vote
    message_type = 1

    proposal_id = 0
    support = True
    voting_duration = 600
    voting_power_aave = int(proofs["AAVE"]["votingPower"], 16)
    voting_power_stkaave = int(proofs["STK_AAVE"]["votingPower"], 16)
    voting_power = voting_power_aave + voting_power_stkaave

    # Convert constants.DATA_BLOCK_HASH to hex
    block_hash_bytes = web3.toBytes(hexstr=constants.DATA_BLOCK_HASH)

    # Create a proposal message
    proposal_message = encode_abi(
        ["uint256", "bytes32", "uint24"],  # [proposalId, blockHash, votingDuration]
        [proposal_id, block_hash_bytes, voting_duration],  # [proposalId, blockHash, votingDuration]
    )

    # Now encode that into a message wth the message type
    message = encode_abi(
        ["uint8", "bytes"],  # [messageType, message]
        [message_type, proposal_message],  # [messageType, message]
    )

    # Send the message to the VotingMachine
    tx = voting_machine.receiveCrossChainMessage(
        voting_portal, chain.id, message, {"from": cross_chain_controller}
    )

    # Record the votes
    proposal_info = voting_machine.getProposalById(proposal_id)
    initial_for_votes = proposal_info["forVotes"]
    initial_against_votes = proposal_info["againstVotes"]

    # Get the proofs we need from the text files
    aave_storage_proof = proofs["AAVE"]["balanceStorageProofRlp"]
    stk_aave_storage_proof = proofs["STK_AAVE"]["balanceStorageProofRlp"]

    voter = constants.DATA_VOTER

    # Submit a vote
    tx = voting_machine.submitVote(
        proposal_id,
        support,
        [
            [voting_strategy.AAVE(), 0, aave_storage_proof],  # [underlyingAsset, slot, proof]
            [
                voting_strategy.STK_AAVE(),
                0,
                stk_aave_storage_proof,
            ],  # [underlyingAsset, slot, proof]
        ],
        {"from": voter},
    )

    # Check the proposal's vote count has changed
    proposal_info = voting_machine.getProposalById(proposal_id)
    assert proposal_info["forVotes"] == initial_for_votes + voting_power
    assert proposal_info["againstVotes"] == initial_against_votes

    # Look up the vote
    user_vote = voting_machine.getUserProposalVote(voter, proposal_id)

    # Check the vote is correct
    assert user_vote[0] == True  # support
    assert user_vote[1] == voting_power  # votingPower

    # Check the event
    assert tx.events[0].address == voting_machine
    assert tx.events[0].name == "VoteEmitted"
    assert tx.events[0]["proposalId"] == proposal_id
    assert tx.events[0]["voter"] == voter
    assert tx.events[0]["support"] == True
    assert tx.events[0]["votingPower"] == voting_power


def test_submitVote_reverts(setup_protocol, constants, owner, alice, proofs):
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    voting_portal = setup_protocol["voting_portal"]
    voting_machine = setup_protocol["voting_machine"]
    voting_strategy = setup_protocol["voting_strategy"]

    # MessageType: 0 Null, 1 Proposal, 2 Vote
    message_type = 1

    proposal_id = 0
    support = True
    voting_duration = 600
    voting_power_aave = int(proofs["AAVE"]["votingPower"], 16)
    voting_power_stkaave = int(proofs["STK_AAVE"]["votingPower"], 16)
    voting_power = voting_power_aave + voting_power_stkaave

    # Convert constants.DATA_BLOCK_HASH to hex
    block_hash_bytes = web3.toBytes(hexstr=constants.DATA_BLOCK_HASH)

    # Create a proposal message
    proposal_message = encode_abi(
        ["uint256", "bytes32", "uint24"],  # [proposalId, blockHash, votingDuration]
        [proposal_id, block_hash_bytes, voting_duration],  # [proposalId, blockHash, votingDuration]
    )

    # Now encode that into a message wth the message type
    message = encode_abi(
        ["uint8", "bytes"],  # [messageType, message]
        [message_type, proposal_message],  # [messageType, message]
    )

    # Send the message to the VotingMachine
    tx = voting_machine.receiveCrossChainMessage(
        voting_portal, chain.id, message, {"from": cross_chain_controller}
    )

    # Record the votes
    proposal_info = voting_machine.getProposalById(proposal_id)

    # Get the proofs we need from the text files
    f = open('data/proofs.json')
    data = json.load(f)
    aave_storage_proof = data["AAVE"]["balanceStorageProofRlp"]
    stk_aave_storage_proof = data["STK_AAVE"]["balanceStorageProofRlp"]

    voter = constants.DATA_VOTER

    # Move forward in time past the voting period
    chain.mine(timedelta=voting_duration + 100)

    proposal_state = voting_machine.getProposalState(proposal_id)
    assert proposal_state == 2  # Finished

    with reverts("22"):  # PROPOSAL_VOTE_NOT_IN_ACTIVE_STATE
        tx = voting_machine.submitVote(
            proposal_id,
            support,
            [
                [voting_strategy.AAVE(), 0, aave_storage_proof],  # [underlyingAsset, slot, proof]
                [
                    voting_strategy.STK_AAVE(),
                    0,
                    stk_aave_storage_proof,
                ],  # [underlyingAsset, slot, proof]
            ],
            {"from": voter},
        )

    # Move backward in time into the voting period
    chain.mine(timedelta=-voting_duration)

    # Attempt to vote twice with the same balance in one submission
    with reverts("24"):  # VOTE_ONCE_FOR_ASSET
        tx = voting_machine.submitVote(
            proposal_id,
            support,
            [
                [voting_strategy.AAVE(), 0, aave_storage_proof],  # [underlyingAsset, slot, proof]
                [
                    voting_strategy.STK_AAVE(),
                    0,
                    stk_aave_storage_proof,
                ],  # [underlyingAsset, slot, proof]
                [voting_strategy.AAVE(), 0, aave_storage_proof],  # [underlyingAsset, slot, proof]
            ],
            {"from": voter},
        )

    # Send the transaction from the wrong address
    with reverts(""):
        tx = voting_machine.submitVote(
            proposal_id,
            support,
            [
                [voting_strategy.AAVE(), 0, aave_storage_proof],  # [underlyingAsset, slot, proof]
                [
                    voting_strategy.STK_AAVE(),
                    0,
                    stk_aave_storage_proof,
                ],  # [underlyingAsset, slot, proof]
            ],
            {"from": alice},
        )

    # Need alternative raw data to test:
    # Vote for a user with zero balance (but a valid proof)
    # Vote for a user with a balance but not voting power because it is all delegated

    # Successfully submit a vote
    tx = voting_machine.submitVote(
        proposal_id,
        support,
        [
            [voting_strategy.AAVE(), 0, aave_storage_proof],  # [underlyingAsset, slot, proof]
            [
                voting_strategy.STK_AAVE(),
                0,
                stk_aave_storage_proof,
            ],  # [underlyingAsset, slot, proof]
        ],
        {"from": voter},
    )

    # Can't vote again
    with reverts("23"):  # PROPOSAL_VOTE_ALREADY_EXISTS
        tx = voting_machine.submitVote(
            proposal_id,
            support,
            [
                [voting_strategy.AAVE(), 0, aave_storage_proof],  # [underlyingAsset, slot, proof]
                [
                    voting_strategy.STK_AAVE(),
                    0,
                    stk_aave_storage_proof,
                ],  # [underlyingAsset, slot, proof]
            ],
            {"from": voter},
        )


def test_submitVoteBySignature(setup_protocol, constants, owner, alice, dartagnan):
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    voting_portal = setup_protocol["voting_portal"]
    voting_machine = setup_protocol["voting_machine"]
    voting_strategy = setup_protocol["voting_strategy"]

    # MessageType: 0 Null, 1 Proposal, 2 Vote
    message_type = 1

    proposal_id = 0
    support = True
    voting_duration = 600

    # Convert constants.DATA_BLOCK_HASH to hex
    block_hash_bytes = web3.toBytes(hexstr=constants.DATA_BLOCK_HASH)

    # Create a proposal message
    proposal_message = encode_abi(
        ["uint256", "bytes32", "uint24"],  # [proposalId, blockHash, votingDuration]
        [proposal_id, block_hash_bytes, voting_duration],  # [proposalId, blockHash, votingDuration]
    )

    # Now encode that into a message wth the message type
    message = encode_abi(
        ["uint8", "bytes"],  # [messageType, message]
        [message_type, proposal_message],  # [messageType, message]
    )

    # Send the message to the VotingMachine
    tx = voting_machine.receiveCrossChainMessage(
        voting_portal, chain.id, message, {"from": cross_chain_controller}
    )


    # Create the digest to sign
    domain_typehash = web3.keccak(
        text="EIP712Domain(string name,uint256 chainId,address verifyingContract)"
    )
    vote_submitted_typehash = voting_machine.VOTE_SUBMITTED_TYPEHASH()
    contract_name = voting_machine.NAME()
    contract_name_bytes = web3.toBytes(text=contract_name)
    digest = web3.keccak(
        encode_abi_packed(
            ["bytes2", "bytes32", "bytes32"],
            [
                web3.toBytes(hexstr="0x1901"),
                web3.keccak(
                    encode_abi(
                        ["bytes32", "bytes32", "uint256", "address"],
                        [
                            domain_typehash,
                            web3.keccak(contract_name_bytes),
                            chain.id,
                            voting_machine.address,
                        ],
                    )
                ),
                web3.keccak(
                    encode_abi(
                        ["bytes32", "uint256", "address", "bool", "(address,uint128)[]"],
                        [
                            vote_submitted_typehash,
                            proposal_id,
                            dartagnan.address,
                            support,
                            [[voting_strategy.AAVE(), 0]]
                        ],
                    )
                ),
            ],
        )
    )

    # Sign the digest
    signature = web3.eth.account.signHash(digest, dartagnan.private_key)
    assert web3.eth.account.recoverHash(digest, signature=signature.signature) == dartagnan.address
    r = signature.r.to_bytes((signature.r.bit_length() + 7) // 8, "big")
    s = signature.s.to_bytes((signature.s.bit_length() + 7) // 8, "big")
    v = signature.v

    # Not sure how to test this: the signature validates but the balance proof is wrong
    # Can see in brownie debug that it is failing after the signature validation.
    # Might be able to test by building a mock contract for data warehouse and voting strategy
    with reverts(""):
        tx = voting_machine.submitVoteBySignature(
            proposal_id,
            dartagnan.address,
            support,
            [
                [voting_strategy.AAVE(), 0, b""],  # [underlyingAsset, slot, proof]
            ],
            v,
            r,
            s,
            {"from": alice},
        )
    assert True


def test_settleVoteFromPortal(setup_protocol, constants, owner, alice, proofs):
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    voting_portal = setup_protocol["voting_portal"]
    voting_machine = setup_protocol["voting_machine"]
    voting_strategy = setup_protocol["voting_strategy"]

    # MessageType: 0 Null, 1 Proposal, 2 Vote
    message_type = 1

    proposal_id = 17
    support = True
    voting_duration = 600
    voting_power_aave = int(proofs["AAVE"]["votingPower"], 16)
    voting_power_stkaave = int(proofs["STK_AAVE"]["votingPower"], 16)
    expected_voting_power = voting_power_aave + voting_power_stkaave


    # Convert constants.DATA_BLOCK_HASH to hex
    block_hash_bytes = web3.toBytes(hexstr=constants.DATA_BLOCK_HASH)

    # Create a proposal message
    proposal_message = encode_abi(
        ["uint256", "bytes32", "uint24"],  # [proposalId, blockHash, votingDuration]
        [proposal_id, block_hash_bytes, voting_duration],  # [proposalId, blockHash, votingDuration]
    )

    # Now encode that into a message wth the message type
    message = encode_abi(
        ["uint8", "bytes"],  # [messageType, message]
        [message_type, proposal_message],  # [messageType, message]
    )

    # Send the message to the VotingMachine
    tx = voting_machine.receiveCrossChainMessage(
        voting_portal, chain.id, message, {"from": cross_chain_controller}
    )

    # Now we are going to bridge a vote
    message_type = 2

    proposal_id = 17
    voter = constants.DATA_VOTER
    support = True
    voting_tokens = [[voting_strategy.AAVE(),0], [voting_strategy.STK_AAVE(),0]]

    # Convert constants.DATA_BLOCK_HASH to hex
    block_hash_bytes = web3.toBytes(hexstr=constants.DATA_BLOCK_HASH)

    # Create a proposal message
    vote_message = encode_abi(
        ["uint256", "address", "bool", "(address,uint128)[]"],  # [proposalId, voter, support, VotingAssetWithSlot[]]
        [proposal_id, voter, support, voting_tokens],  # [proposalId, voter, support, VotingAssetWithSlot[]]
    )

    # Now encode that into a message wth the message type
    message = encode_abi(
        ["uint8", "bytes"],  # [messageType, message]
        [message_type, vote_message],  # [messageType, message]
    )

    # Send the message to the VotingMachine
    # If successful, this will call _registerBridgedVote
    tx = voting_machine.receiveCrossChainMessage(
        voting_portal, chain.id, message, {"from": cross_chain_controller}
    )

    # Get the proofs we need from the text files
    aave_storage_proof = proofs["AAVE"]["balanceStorageProofRlp"]
    stk_aave_storage_proof = proofs["STK_AAVE"]["balanceStorageProofRlp"]

    # Wrong number of proofs
    with reverts("19"):  # PORTAL_VOTE_WITH_NO_VOTING_TOKENS
        tx = voting_machine.settleVoteFromPortal(
            proposal_id,
            voter,
            [
                [voting_strategy.AAVE(), 0, aave_storage_proof],  # [underlyingAsset, slot, proof]
            ],
            {"from": alice},
        )

    # Proofs for wrong tokens
    with reverts("20"):  # PROOFS_NOT_FOR_VOTING_TOKENS
        tx = voting_machine.settleVoteFromPortal(
            proposal_id,
            voter,
            [
                [voting_strategy.AAVE(), 0, aave_storage_proof],  # [underlyingAsset, slot, proof]
                [alice.address, 0, aave_storage_proof],
            ],
            {"from": alice},
        )

    # Record the votes
    proposal_info = voting_machine.getProposalById(proposal_id)
    initial_for_votes = proposal_info["forVotes"]
    initial_against_votes = proposal_info["againstVotes"]

    # A successful vote settlement
    tx = voting_machine.settleVoteFromPortal(
        proposal_id,
        voter,
        [
            [voting_strategy.AAVE(), 0, aave_storage_proof],  # [underlyingAsset, slot, proof]
            [
                voting_strategy.STK_AAVE(),
                0,
                stk_aave_storage_proof,
            ],  # [underlyingAsset, slot, proof]
        ],
        {"from": alice},
    )

    # Check the proposal's vote count has changed
    proposal_info = voting_machine.getProposalById(proposal_id)
    assert proposal_info["forVotes"] == initial_for_votes + expected_voting_power
    assert proposal_info["againstVotes"] == initial_against_votes

    # Look up the vote
    user_vote = voting_machine.getUserProposalVote(voter, proposal_id)

    # Check the vote is correct
    assert user_vote[0] == True  # support
    assert user_vote[1] == expected_voting_power  # votingPower

    # Check the event
    assert tx.events[0].address == voting_machine
    assert tx.events[0].name == "VoteEmitted"
    assert tx.events[0]["proposalId"] == proposal_id
    assert tx.events[0]["voter"] == voter
    assert tx.events[0]["support"] == True
    assert tx.events[0]["votingPower"] == expected_voting_power


def test_closeAndSendVote(setup_protocol, constants, owner, alice, proofs):
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    voting_portal = setup_protocol["voting_portal"]
    voting_machine = setup_protocol["voting_machine"]
    voting_strategy = setup_protocol["voting_strategy"]

    # MessageType: 0 Null, 1 Proposal, 2 Vote
    message_type = 1

    proposal_id = 17
    support = True
    voting_duration = 600

    # Convert constants.DATA_BLOCK_HASH to hex
    block_hash_bytes = web3.toBytes(hexstr=constants.DATA_BLOCK_HASH)

    # Create a proposal message
    proposal_message = encode_abi(
        ["uint256", "bytes32", "uint24"],  # [proposalId, blockHash, votingDuration]
        [proposal_id, block_hash_bytes, voting_duration],  # [proposalId, blockHash, votingDuration]
    )

    # Now encode that into a message wth the message type
    message = encode_abi(
        ["uint8", "bytes"],  # [messageType, message]
        [message_type, proposal_message],  # [messageType, message]
    )

    # Send the message to the VotingMachine
    tx = voting_machine.receiveCrossChainMessage(
        voting_portal, chain.id, message, {"from": cross_chain_controller}
    )

    # Get the proofs we need from the text files

    aave_storage_proof = proofs["AAVE"]["balanceStorageProofRlp"]
    stk_aave_storage_proof = proofs["STK_AAVE"]["balanceStorageProofRlp"]

    voter = constants.DATA_VOTER

    # Submit a vote
    tx = voting_machine.submitVote(
        proposal_id,
        support,
        [
            [voting_strategy.AAVE(), 0, aave_storage_proof],  # [underlyingAsset, slot, proof]
            [
                voting_strategy.STK_AAVE(),
                0,
                stk_aave_storage_proof,
            ],  # [underlyingAsset, slot, proof]
        ],
        {"from": voter},
    )

    # Record the votes
    proposal_info = voting_machine.getProposalById(proposal_id)
    for_votes = proposal_info["forVotes"]
    against_votes = proposal_info["againstVotes"]

    # Attempt to close the vote before the voting duration has passed
    with reverts("21"):  # PROPOSAL_VOTE_NOT_FINISHED
        tx = voting_machine.closeAndSendVote(
        proposal_id,
        {"from": alice},
    )

    # Advance time to close the vote
    chain.mine(timedelta=voting_duration+100)
    
    # Close the vote
    tx = voting_machine.closeAndSendVote(
        proposal_id,
        {"from": alice},
    )
    close_timestamp = tx.timestamp
    close_block_number = tx.block_number

    proposal_info = voting_machine.getProposalById(proposal_id)

    assert proposal_info["id"] == proposal_id  # id
    assert proposal_info["forVotes"] == for_votes  # forVotes
    assert proposal_info["againstVotes"] == against_votes  # againstVotes
    assert proposal_info["votingClosedAndSentBlockNumber"] == close_block_number  # votingClosedAndSentBlockNumber
    assert proposal_info["votingClosedAndSentTimestamp"] == close_timestamp  # votingClosedAndSentTimestamp
    assert proposal_info["sentToGovernance"] is True  # sentToGovernance

    # Check the event
    assert tx.events[0].address == voting_machine
    assert tx.events[0].name == "ProposalResultsSent"
    assert tx.events[0]["proposalId"] == proposal_id
    assert tx.events[0]["forVotes"] == for_votes
    assert tx.events[0]["againstVotes"] == against_votes

    # Check the vote has been sent to the cross chain controller
    assert cross_chain_controller.sender() == voting_machine
    forwarded_data_bytes = cross_chain_controller.data()
    forwarded_data = decode_abi(["uint256", "uint256","uint256"], forwarded_data_bytes)
    assert forwarded_data[0] == proposal_id
    assert forwarded_data[1] == for_votes
    assert forwarded_data[2] == against_votes




