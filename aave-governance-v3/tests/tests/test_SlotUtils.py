"""✅❎⛔

External Functions:
getAccountSlotHash ✅
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


def test_getAccountSlotHash(setup_protocol, constants, owner, UseSlotUtils):
    slot_utils = setup_protocol["slot_utils"]
    use_slot_utils = UseSlotUtils.deploy({"from": owner})

    # Get 10 random uint256s
    random_uint256s = [secrets.randbits(256) for i in range(10)]
    # Get 10 random addresses
    random_addresses = [accounts.add() for i in range(10)]

    # Loop through the random uint256s and addresses and test the calculation for each one
    for i in range(10):
        # Convert the address to an integer
        address_bytes = int(random_addresses[i].address, 16).to_bytes(32, byteorder="big")

        expected_slot_hash = web3.keccak(
            encode_abi(
                ["bytes32", "uint256"],
                [address_bytes, random_uint256s[i]],
            )
        ).hex()

        # Call the function to get its result
        slot_hash = use_slot_utils.getAccountSlotHash(random_addresses[i], random_uint256s[i])

        # Check the result
        assert slot_hash == expected_slot_hash
