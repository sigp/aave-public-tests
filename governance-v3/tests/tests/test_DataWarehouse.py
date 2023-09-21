"""✅❎⛔

External Functions:
getStorageRoots ✅ (in test for processStorageRoot)
getRegisteredSlot ✅ (in test for processStorageSlot)
processStorageRoot ✅
getStorage ✅
processStorageSlot ✅
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


def test_processStorageRoot(setup_protocol, constants, owner, DataWarehouse, VotingStrategy, proofs):
    # We deploy ourselves instead of using setup_protocol because setup_protocol
    # already does these steps for us
    data_warehouse = DataWarehouse.deploy({"from": owner})
    voting_strategy = VotingStrategy.deploy(data_warehouse, {"from": owner})

    # We have no data, so we should get no storage root
    storage_root = data_warehouse.getStorageRoots(voting_strategy.AAVE(), constants.DATA_BLOCK_HASH)
    assert storage_root ==  constants.ZERO_VALUE

    # Get the data we need from the text files
    blockHeaderRLP = proofs["AAVE"]["blockHeaderRLP"]  
    accountStateProofRLP = proofs["AAVE"]["accountStateProofRLP"]

    # Call with valid data
    tx = data_warehouse.processStorageRoot(
        voting_strategy.AAVE(), constants.DATA_BLOCK_HASH, blockHeaderRLP, accountStateProofRLP
    )

    # Check that we now have a storage root
    storage_root = data_warehouse.getStorageRoots(voting_strategy.AAVE(), constants.DATA_BLOCK_HASH)
    # This value is not calculated. We are basically just checking that the storage root is not zero
    assert storage_root == "0x28ea1a1ea691414c647d3ff6290ac4aa5d77f73a45a7db6803fad728c3e51dce"

    # Generate a random 32 byte hash
    random_hash = secrets.token_hex(32)

    # Call with this invalid block hash (unless we randomly generated the correct one!)
    with brownie.reverts():
        tx = data_warehouse.processStorageRoot(
            voting_strategy.AAVE(), random_hash, blockHeaderRLP, accountStateProofRLP
        )


def test_processStorageSlot(setup_protocol, constants, owner, DataWarehouse, VotingStrategy, proofs):
    # We deploy ourselves instead of using setup_protocol because setup_protocol
    # already does these steps for us
    data_warehouse = DataWarehouse.deploy({"from": owner})
    voting_strategy = VotingStrategy.deploy(data_warehouse, {"from": owner})

    # Get the data we need from the text files
    blockHeaderRLP = proofs["STK_AAVE"]["blockHeaderRLP"] 
    accountStateProofRLP = proofs["STK_AAVE"]["accountStateProofRLP"]
    # Slot values from AAVE test data
    slot_storage_proof_path = proofs["STK_AAVE"]["stkAaveExchangeRateStorageProofRlp"]
    slot = proofs["STK_AAVE"]["stkAaveExchangeRateSlot"]

    # Input a torage root for STK_AAVE
    tx = data_warehouse.processStorageRoot(
        voting_strategy.STK_AAVE(), constants.DATA_BLOCK_HASH, blockHeaderRLP, accountStateProofRLP
    )

    # We have no storage data, so we should get no value in the storage slot
    storage_slot_value = data_warehouse.getRegisteredSlot(
        constants.DATA_BLOCK_HASH, voting_strategy.STK_AAVE(), slot
    )
    assert storage_slot_value == 0

    # Call with a proof for a particular slot at this block hash
    tx = data_warehouse.processStorageSlot(
        voting_strategy.STK_AAVE(),
        constants.DATA_BLOCK_HASH,
        slot,
        slot_storage_proof_path,
        {"from": owner},
    )

    # Check that we now have a value for this storage slot
    storage_slot_value = data_warehouse.getRegisteredSlot(
        constants.DATA_BLOCK_HASH, voting_strategy.STK_AAVE(), slot
    )
    assert storage_slot_value == 1000000000000000000

    # Generate a random 32 byte hash
    random_hash = secrets.token_hex(32)

    # Call with this invalid block hash (unless we randomly generated the correct one!)
    with brownie.reverts():
        tx = data_warehouse.processStorageSlot(
            voting_strategy.STK_AAVE(),
            random_hash,
            slot,
            slot_storage_proof_path,
            {"from": owner},
        )


def test_getStorage(setup_protocol, constants, owner, proofs):
    data_warehouse = setup_protocol["data_warehouse"]
    voting_strategy = setup_protocol["voting_strategy"]

    # Values from AAVE test data
    slot_storage_proof_path = proofs["STK_AAVE"]["stkAaveExchangeRateStorageProofRlp"]
    slot = proofs["STK_AAVE"]["stkAaveExchangeRateSlot"]

    # Call with a proof for a particular slot at this block hash
    storage_slot_data = data_warehouse.getStorage(
        voting_strategy.STK_AAVE(),
        constants.DATA_BLOCK_HASH,
        slot,
        slot_storage_proof_path,
        {"from": owner},
    )

    # This function returns a tuple of (bool, uint256)
    assert storage_slot_data[0] == True
    assert storage_slot_data[1] == 1000000000000000000

    # Generate a random 32 byte hash
    random_hash = secrets.token_hex(32)

    # Call with this invalid block hash (unless we randomly generated the correct one!)
    with brownie.reverts():
        tx = data_warehouse.getStorage(
            voting_strategy.STK_AAVE(),
            random_hash,
            slot,
            slot_storage_proof_path,
            {"from": owner},
        )