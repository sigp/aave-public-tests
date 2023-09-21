"""✅❎⛔
Note that this is also partially tested in the PayloadController test test_executePayload

External Functions:
executeTransaction ✅
"""

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

from helpers import custom_error
from eth_abi import encode_single, encode_abi


def test_executeTransaction(setup_protocol, owner, alice, constants, ForceDonate):
    proxy_admin = setup_protocol["proxy_admin"]
    payload_controller = setup_protocol["payload_controller"]
    executor = setup_protocol["executor1"]

    # Transfer ownership of the executor back to the owner
    executor.transferOwnership(owner, {"from": payload_controller})

    # Execute without enough ETH
    with brownie.reverts("31"):  # NOT_ENOUGH_MSG_VALUE
        executor.executeTransaction(
            proxy_admin,
            10**18,
            "getProxyAdmin()",
            encode_abi(["address"], [payload_controller.address]),
            True,
            {"from": owner, "value": 10**17},
        )

    # Execute a failed transaction
    with brownie.reverts("32"):  # FAILED_ACTION_EXECUTION
        executor.executeTransaction(
            proxy_admin,
            0,
            "getProxyAdmin()",
            encode_abi(["address"], [alice.address]),
            False,
            {"from": owner},
        )

    # Execute a successful transaction - force donate
    force_donate = ForceDonate.deploy({"from": owner})
    donate_amount = 894563894908464
    alice.transfer(force_donate, donate_amount)

    assert force_donate.balance() == donate_amount
    assert payload_controller.balance() == 0
    assert bytes(web3.eth.get_code(force_donate.address)) != b""

    # Execute the self destruction, sending the eth to the payload controller
    executor.executeTransaction(
        force_donate,
        0,
        "boom(address)",
        encode_abi(["address"], [payload_controller.address]),
        False,
        {"from": owner},
    )

    # Force donate should be self destructed (ie. have no code)
    # web3.eth.get_code returns in HexBytes, so convert to bytes for comparison
    assert bytes(web3.eth.get_code(force_donate.address)) == b""

    # Force donate should have no ETH left
    assert force_donate.balance() == 0

    # Force donate should have sent all ETH to the payload controller
    assert payload_controller.balance() == donate_amount


def test_executeTransaction_selfdestruction(setup_protocol, owner, alice, constants, ForceDonate):
    """
    Delegate call to selfdestruct to demonstrate that it really is a delegate call
    """
    proxy_admin = setup_protocol["proxy_admin"]
    payload_controller = setup_protocol["payload_controller"]
    executor = setup_protocol["executor1"]

    # Transfer ownership of the executor back to the owner
    executor.transferOwnership(owner, {"from": payload_controller})

    # Get ETH into the executor
    force_donate = ForceDonate.deploy({"from": owner})
    donate_amount = 894563894908464
    alice.transfer(force_donate, donate_amount)
    force_donate.boom(executor, {"from": alice})

    # Create a new force donate contract
    force_donate = ForceDonate.deploy({"from": owner})

    assert executor.balance() == donate_amount
    assert force_donate.balance() == 0
    assert payload_controller.balance() == 0

    # Both contracts should have code, of course
    assert bytes(web3.eth.get_code(executor.address)) != b""
    assert bytes(web3.eth.get_code(force_donate.address)) != b""

    # Execute the self destruction, sending the eth to the payload controller
    executor.executeTransaction(
        force_donate,
        0,
        "boom(address)",
        encode_abi(["address"], [payload_controller.address]),
        True,
        {"from": owner},
    )

    # Force donate still has code
    assert bytes(web3.eth.get_code(force_donate.address)) != b""

    # Executor should be self destructed (ie. have no code)
    # web3.eth.get_code returns in HexBytes, so convert to bytes for comparison
    assert bytes(web3.eth.get_code(executor.address)) == b""

    # Executor should have no ETH left
    assert executor.balance() == 0

    # Executor should have sent all ETH to the payload controller
    assert payload_controller.balance() == donate_amount
