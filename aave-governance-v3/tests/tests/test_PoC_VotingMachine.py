"""✅❎⛔
"""

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

from eth_abi import encode_single, encode_abi, decode_single, decode_abi
from eth_abi.packed import encode_abi_packed


def test_submitVote_separate(setup_protocol, constants, proofs):
    """
    POC that voting twice is not allowed for the same address
    even if the voting tokens are different
    """
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
        ],
        {"from": voter},
    )

    # Check the proposal's vote count has changed
    proposal_info = voting_machine.getProposalById(proposal_id)
    assert proposal_info["forVotes"] == initial_for_votes + voting_power_aave
    assert proposal_info["againstVotes"]== initial_against_votes

    # Submit another vote, this time with STK_AAVE, same voter
    with reverts("23"):  # PROPOSAL_VOTE_ALREADY_EXISTS
        tx = voting_machine.submitVote(
            proposal_id,
            support,
            [
                [
                    voting_strategy.STK_AAVE(),
                    0,
                    stk_aave_storage_proof,
                ],  # [underlyingAsset, slot, proof]
            ],
            {"from": voter},
        )
