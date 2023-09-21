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
from eth_abi import encode_abi, encode_single


def test_forward_message(setup_protocol, alice, owner, MainnetChainIds, carol):
    """
    Testing `forwardMessage()`
    """
    same_chain_adapter = setup_protocol["same_chain_adapter"]


    current_chain_bridge_adapter = setup_protocol["current_chain_bridge_adapter"]
    destination_chain_id = MainnetChainIds.POLYGON
    origin_chain_id = chain.id
    destination = setup_protocol["destination_chain_bridge_adapter"]  # just for testing
    gas_limit = 2000
    message = b"test message"

    # envelope
    envelope = [0, carol.address, destination.address, origin_chain_id, destination_chain_id, message]
    envelope_data = encode_single("((uint256,address,address,uint256,uint256,bytes))", [envelope])
    envelope_id = web3.keccak(envelope_data)
    encoded_envelope = [envelope_id, envelope_data]
    # transaction
    transaction = [0, envelope_data]
    transaction_data = encode_single("((uint256,bytes))", [transaction])

    destination_chain_id = chain.id
    message = transaction_data

    tx = same_chain_adapter.forwardMessage(owner, 1337, destination_chain_id, message, {"from": alice})

    assert tx.return_value[0] == destination
    assert tx.return_value[1] == 0


def test_native_to_infra_chain_id(setup_protocol, MainnetChainIds):
    """
    Testing `nativeToInfraChainId()`
    """

    same_chain_adapter = setup_protocol["same_chain_adapter"]

    native_chain_id = chain.id
    return_value = same_chain_adapter.nativeToInfraChainId(native_chain_id)

    assert return_value == native_chain_id

    return_value = same_chain_adapter.nativeToInfraChainId(1337)

    assert return_value == 1337


def test_infra_to_native_chain_id(setup_protocol, MainnetChainIds):
    """
    Testing `infraToNativeChainId()`
    """

    same_chain_adapter = setup_protocol["same_chain_adapter"]

    infra_chain_id = chain.id
    return_value = same_chain_adapter.infraToNativeChainId(infra_chain_id)

    assert return_value == infra_chain_id

    return_value = same_chain_adapter.infraToNativeChainId(1337)

    assert return_value == 1337


def test_get_trusted_remote_by_chain_id(setup_protocol, constants):
    """
    Testing `getTrustedRemoteByChainId()`
    """

    same_chain_adapter = setup_protocol["same_chain_adapter"]

    assert same_chain_adapter.getTrustedRemoteByChainId(13371337) == constants.ZERO_ADDRESS
    assert same_chain_adapter.getTrustedRemoteByChainId(1) == constants.ZERO_ADDRESS


