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

def test_constructor(setup_protocol):
    """
    Testing the constructor
    """

    base_adapter = setup_protocol["base_adapter"]
    cross_chain_controller = setup_protocol["cross_chain_controller"]

    # Validation
    assert base_adapter.CROSS_CHAIN_CONTROLLER() == cross_chain_controller.address


def test_get_trusted_remote_by_chain_id(setup_protocol, MainnetChainIds, alice, carol, constants):
    """
    Testing `getTrustedRemoteByChainId()`
    """

    base_adapter = setup_protocol["base_adapter"]

    assert base_adapter.getTrustedRemoteByChainId(chain.id) == alice.address
    assert base_adapter.getTrustedRemoteByChainId(MainnetChainIds.POLYGON) == carol.address
    assert base_adapter.getTrustedRemoteByChainId(13371337) == constants.ZERO_ADDRESS


def test_register_received_message(setup_protocol, owner, MainnetChainIds, carol):
    """
    Testing `_registerReceivedMessage()`
    """

    base_adapter = setup_protocol["base_adapter"]
    cross_chain_controller = setup_protocol["cross_chain_controller"]

    # Add this bridge adapter as a bridge to the ETHEREUM Mainnet
    bridge_adapters_input = [base_adapter.address, [chain.id]]
    cross_chain_controller.allowReceiverBridgeAdapters([bridge_adapters_input], {"from": owner})

    destination_chain_id = chain.id
    origin_chain_id = chain.id
    destination = setup_protocol["destination_chain_bridge_adapter"]
    message = b"test message"
    # envelope
    envelope = [0, carol.address, destination.address, origin_chain_id, destination_chain_id, message]
    envelope_data = encode_single("((uint256,address,address,uint256,uint256,bytes))", [envelope])
    envelope_id = web3.keccak(envelope_data)
    encoded_envelope = [envelope_id, envelope_data]
    gas_limit = 2000

    # transaction
    transaction = [0, envelope_data]
    encode_transaction = encode_single("((uint256,bytes))", [transaction])
    origin_chain_id = chain.id
    transaction_id = web3.keccak(encode_transaction)


    tx = base_adapter.registerReceivedMessage(encode_transaction, origin_chain_id, {"from": carol})

    # Logs
    # TransactionReceived event
    assert tx.events["TransactionReceived"]["transactionId"] == transaction_id.hex()
    assert tx.events["TransactionReceived"]["envelopeId"] == envelope_id.hex()
    assert tx.events["TransactionReceived"]["originChainId"] == origin_chain_id
    assert tx.events["TransactionReceived"]["transaction"][0] == transaction[0]
    assert tx.events["TransactionReceived"]["transaction"][1].hex() == transaction[1].hex()
    assert tx.events["TransactionReceived"]["bridgeAdapter"] == base_adapter
    assert tx.events["TransactionReceived"]["confirmations"] == 1


def test_register_received_message_delegatecall(setup_protocol, owner, MainnetChainIds, carol, SigpDelegatecall):
    """
    Testing `_registerReceivedMessage()`, calling through delegatecall
    """

    base_adapter = setup_protocol["base_adapter"]
    cross_chain_controller = setup_protocol["cross_chain_controller"]

    # Deploy `SigpDelegatecall`
    sigp_delegatecall = SigpDelegatecall.deploy(base_adapter.address, {"from": owner})

    # Add this bridge adapter as a bridge to the ETHEREUM Mainnet
    bridge_adapters_input = [sigp_delegatecall.address, [chain.id]]
    cross_chain_controller.allowReceiverBridgeAdapters([bridge_adapters_input], {"from": owner})

    destination_chain_id = chain.id
    origin_chain_id = chain.id
    destination = setup_protocol["destination_chain_bridge_adapter"]
    message = b"test message"
    # envelope
    envelope = [0, carol.address, destination.address, origin_chain_id, destination_chain_id, message]
    envelope_data = encode_single("((uint256,address,address,uint256,uint256,bytes))", [envelope])
    envelope_id = web3.keccak(envelope_data)


    # transaction
    transaction = [0, envelope_data]
    encode_transaction = encode_single("((uint256,bytes))", [transaction])
    origin_chain_id = chain.id

    with reverts('24'): #DELEGATE_CALL_FORBIDDEN
        sigp_delegatecall.delegateRegisterReceivedMessage(encode_transaction, origin_chain_id, {"from": carol})




