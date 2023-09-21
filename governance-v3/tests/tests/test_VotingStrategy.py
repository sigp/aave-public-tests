"""✅❎⛔

External Functions:
constructor ✅
getVotingAssetList ✅
getVotingAssetConfig ✅
getWeightedPower ✅
hasRequiredRoots ✅
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

from helpers import custom_error
from eth_abi import encode_single, encode_abi


def test_constructor(setup_protocol, constants, owner, VotingStrategy):
    data_warehouse = setup_protocol["data_warehouse"]

    # Deploy our own contract, just to test the constructor
    voting_strategy = VotingStrategy.deploy(data_warehouse, {"from": owner})

    # We are used to using "tx" for the transaction
    tx = voting_strategy.tx

    assert voting_strategy.DATA_WAREHOUSE() == data_warehouse

    # Check the events
    assert tx.events[0].address == voting_strategy
    assert tx.events[0].name == "VotingAssetAdd"
    assert tx.events[0]["asset"] == voting_strategy.AAVE()
    assert tx.events[0]["storageSlots"][0] == 0

    assert tx.events[1].address == voting_strategy
    assert tx.events[1].name == "VotingAssetAdd"
    assert tx.events[1]["asset"] == voting_strategy.STK_AAVE()
    assert tx.events[1]["storageSlots"][0] == 0

    assert tx.events[2].address == voting_strategy
    assert tx.events[2].name == "VotingAssetAdd"
    assert tx.events[2]["asset"] == voting_strategy.A_AAVE()
    assert tx.events[2]["storageSlots"][0] == 52
    assert tx.events[2]["storageSlots"][1] == 64


def test_getVotingAssetList(setup_protocol, constants, owner):
    voting_strategy = setup_protocol["voting_strategy"]

    assert voting_strategy.getVotingAssetList() == [
        voting_strategy.AAVE(),
        voting_strategy.STK_AAVE(),
        voting_strategy.A_AAVE(),
    ]


def test_getVotingAssetConfig(setup_protocol, constants, owner):
    voting_strategy = setup_protocol["voting_strategy"]

    # These results are all hardcoded
    assert voting_strategy.getVotingAssetConfig(voting_strategy.AAVE())[0][0] == 0
    assert voting_strategy.getVotingAssetConfig(voting_strategy.STK_AAVE())[0][0] == 0
    assert voting_strategy.getVotingAssetConfig(voting_strategy.A_AAVE())[0][0] == 52
    assert voting_strategy.getVotingAssetConfig(voting_strategy.A_AAVE())[0][1] == 64


def test_hasRequiredRoots(setup_protocol, constants, owner):
    voting_strategy = setup_protocol["voting_strategy"]

    # This function just has to not revert to pass
    tx = voting_strategy.hasRequiredRoots(constants.DATA_BLOCK_HASH)

    # Generate a random 32 byte hash
    random_hash = secrets.token_hex(32)

    # This function should revert
    with brownie.reverts("27"):  # MISSING_AAVE_ROOTS
        tx = voting_strategy.hasRequiredRoots(random_hash)


def test_getVotingPower_aave(setup_protocol, constants, proofs):
    voting_strategy = setup_protocol["voting_strategy"]

    # Values from AAVE's test
    aaveRawBalance = proofs["AAVE"]["balance"]
    expect_weighted_power = int(proofs["AAVE"]["votingPower"], 16)

    # Get the weighted power from the contract
    aave_power = voting_strategy.getVotingPower(
        voting_strategy.AAVE(), 0, aaveRawBalance, constants.DATA_BLOCK_HASH
    )

    # Check the result
    assert aave_power == expect_weighted_power


def test_getVotingPower_stkaave(setup_protocol, constants, proofs):
    voting_strategy = setup_protocol["voting_strategy"]

    # Values from AAVE's test
    stkaaveRawBalance = proofs["STK_AAVE"]["balance"]
    expect_weighted_power = int(proofs["STK_AAVE"]["votingPower"], 16)

    # Get the weighted power from the contract
    aave_power = voting_strategy.getVotingPower(
        voting_strategy.STK_AAVE(),
        0,
        stkaaveRawBalance,
        constants.DATA_BLOCK_HASH,
    )

    # Check the result
    assert aave_power == expect_weighted_power


def test_getVotingPower_a_aave(setup_protocol, constants, proofs):
    voting_strategy = setup_protocol["voting_strategy"]

    # Values from AAVE's test
    a_aaveRawBalance = proofs["A_AAVE"]["balance"]

    # Get the weighted power from the contract
    aave_power = voting_strategy.getVotingPower(
        voting_strategy.A_AAVE(),
        52, # 52 is the delegation slot
        a_aaveRawBalance,
        constants.DATA_BLOCK_HASH,
    )

    # The result should be non-negative as the voter account is delegated to and 52 is the
    # delegation slot
    assert aave_power ==  int(proofs["A_AAVE"]["votingPower"], 16)
