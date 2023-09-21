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

def test_basic(setup_protocol):
    """
    basic check to ensure the correctness of the setup
    """
    proxy_admin = setup_protocol["proxy_admin"]
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    cross_chain_controller_logic = setup_protocol["cross_chain_controller_logic"]

    info = proxy_admin.getProxyImplementation(cross_chain_controller)

    assert info == cross_chain_controller_logic.address


def test_initialize(
    setup_protocol, owner, guardian, MainnetChainIds, bridge_adapter, carol
):
    """
    Testing the initialization
    """
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    current_chain_bridge_adapter = setup_protocol["current_chain_bridge_adapter"]
    destination_chain_bridge_adapter = setup_protocol["destination_chain_bridge_adapter"]
    # Validation
    assert cross_chain_controller.guardian() == guardian
    assert cross_chain_controller.owner() == owner
    adapters = cross_chain_controller.getReceiverBridgeAdaptersByChain(chain.id)
    assert adapters[0] == bridge_adapter
    bridge_config = cross_chain_controller.getForwarderBridgeAdaptersByChain(MainnetChainIds.POLYGON)[0]
    assert bridge_config[0] == destination_chain_bridge_adapter  # destinationBridgeAdapter
    assert bridge_config[1] == current_chain_bridge_adapter  # currentChainBridgeAdapter
    assert cross_chain_controller.isSenderApproved(carol) is True


###########################################
##### Tests for CrossChainForwarder #######
###########################################


def test_forward_message(setup_protocol, carol, MainnetChainIds):
    """
    Testing `forwardMessage()`
    """
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    current_chain_bridge_adapter = setup_protocol["current_chain_bridge_adapter"]
    # call `forwardMessage()`
    destination_chain_id = MainnetChainIds.POLYGON
    origin_chain_id = chain.id
    destination = setup_protocol["destination_chain_bridge_adapter"]  # just for testing
    gas_limit = 2000
    message = b"test message"
    tx = cross_chain_controller.forwardMessage(
        destination_chain_id, destination, gas_limit, message, {"from": carol}
    )
    # envelope
    envelope = [0, carol.address, destination.address, origin_chain_id, destination_chain_id, message]
    envelope_data = encode_single("((uint256,address,address,uint256,uint256,bytes))", [envelope])
    envelope_id = web3.keccak(envelope_data)
    encoded_envelope = [envelope_id, envelope_data]
    # transaction
    transaction = [0, envelope_data]
    transaction_data = encode_single("((uint256,bytes))", [transaction])
    transaction_id = web3.keccak(transaction_data)
    encoded_transaction = [transaction_id, transaction_data]

    # Validation
    assert cross_chain_controller.getCurrentTransactionNonce() == 1
    assert cross_chain_controller.getCurrentEnvelopeNonce() == 1
    assert cross_chain_controller.isEnvelopeRegistered['bytes32'](envelope_id) is True
    assert cross_chain_controller.isTransactionForwarded['bytes32'](transaction_id) is True
    # return_values
    assert tx.return_value[0] == envelope_id.hex()
    assert tx.return_value[1] == transaction_id.hex()
    # logs
    # EnvelopeRegistered event
    assert tx.events["EnvelopeRegistered"]["envelopeId"] == envelope_id.hex()
    assert tx.events["EnvelopeRegistered"]["envelope"][0] == envelope[0]
    assert tx.events["EnvelopeRegistered"]["envelope"][1] == envelope[1]
    assert tx.events["EnvelopeRegistered"]["envelope"][2] == envelope[2]
    assert tx.events["EnvelopeRegistered"]["envelope"][3] == envelope[3]
    assert tx.events["EnvelopeRegistered"]["envelope"][4] == envelope[4]
    assert tx.events["EnvelopeRegistered"]["envelope"][5].hex() == envelope[5].hex()
    # TransactionForwardingAttempted event
    assert tx.events["TransactionForwardingAttempted"]["transactionId"] == transaction_id.hex()
    assert tx.events["TransactionForwardingAttempted"]["envelopeId"] == envelope_id.hex()
    assert tx.events["TransactionForwardingAttempted"]["destinationChainId"] == destination_chain_id
    assert tx.events["TransactionForwardingAttempted"]["bridgeAdapter"] == current_chain_bridge_adapter
    assert tx.events["TransactionForwardingAttempted"]["destinationBridgeAdapter"] == destination
    assert tx.events["TransactionForwardingAttempted"]["adapterSuccessful"] is True
    assert tx.events["TransactionForwardingAttempted"]["returnData"] == '0x00'



def test_forward_message_same_chain_adapter(setup_protocol, carol, MainnetChainIds, owner):
    """
    Testing `forwardMessage()` using the SameChainAdapter
    """
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    same_chain_adapter = setup_protocol["same_chain_adapter"]
    destination_chain_bridge_adapter = setup_protocol["destination_chain_bridge_adapter"]

    destination_chain_id = chain.id
    origin_chain_id = chain.id
    destination = setup_protocol["destination_chain_bridge_adapter"]  # just for testing

    bridge_adapter = [
            same_chain_adapter, # currentChainBridgeAdapter
            destination_chain_bridge_adapter, # destinationBridgeAdapter
            destination_chain_id, # destinationChainId
    ]

    tx = cross_chain_controller.enableBridgeAdapters([bridge_adapter], {"from": owner})
    gas_limit = 2000
    message = b"test message"
    tx = cross_chain_controller.forwardMessage(
        destination_chain_id, destination, gas_limit, message, {"from": carol}
    )
    # envelope
    envelope = [0, carol.address, destination.address, origin_chain_id, destination_chain_id, message]
    envelope_data = encode_single("((uint256,address,address,uint256,uint256,bytes))", [envelope])
    envelope_id = web3.keccak(envelope_data)
    encoded_envelope = [envelope_id, envelope_data]
    # transaction
    transaction = [0, envelope_data]
    transaction_data = encode_single("((uint256,bytes))", [transaction])
    transaction_id = web3.keccak(transaction_data)
    encoded_transaction = [transaction_id, transaction_data]

    # Validation
    assert cross_chain_controller.getCurrentTransactionNonce() == 1
    assert cross_chain_controller.getCurrentEnvelopeNonce() == 1
    assert cross_chain_controller.isEnvelopeRegistered['bytes32'](envelope_id) is True
    assert cross_chain_controller.isTransactionForwarded['bytes32'](transaction_id) is True
    # return_values
    assert tx.return_value[0] == envelope_id.hex()
    assert tx.return_value[1] == transaction_id.hex()
    # logs
    # EnvelopeRegistered event
    assert tx.events["EnvelopeRegistered"]["envelopeId"] == envelope_id.hex()
    assert tx.events["EnvelopeRegistered"]["envelope"][0] == envelope[0]
    assert tx.events["EnvelopeRegistered"]["envelope"][1] == envelope[1]
    assert tx.events["EnvelopeRegistered"]["envelope"][2] == envelope[2]
    assert tx.events["EnvelopeRegistered"]["envelope"][3] == envelope[3]
    assert tx.events["EnvelopeRegistered"]["envelope"][4] == envelope[4]
    assert tx.events["EnvelopeRegistered"]["envelope"][5].hex() == envelope[5].hex()
    # TransactionForwardingAttempted event
    assert tx.events["TransactionForwardingAttempted"]["transactionId"] == transaction_id.hex()
    assert tx.events["TransactionForwardingAttempted"]["envelopeId"] == envelope_id.hex()
    assert tx.events["TransactionForwardingAttempted"]["destinationChainId"] == destination_chain_id
    assert tx.events["TransactionForwardingAttempted"]["bridgeAdapter"] == same_chain_adapter
    assert tx.events["TransactionForwardingAttempted"]["destinationBridgeAdapter"] == destination
    assert tx.events["TransactionForwardingAttempted"]["adapterSuccessful"] is True
    return_data = encode_single("((address,uint256))", [[destination.address, 0]])
    assert tx.events["TransactionForwardingAttempted"]["returnData"].hex() == return_data.hex()


def test_forward_message_no_bridge_adapter(setup_protocol, carol, MainnetChainIds):
    """
    Testing `forwardMessage()` for a chain without bridge adapters
    """

    cross_chain_controller = setup_protocol["cross_chain_controller"]
    destination_chain_id = MainnetChainIds.AVALANCHE
    destination = setup_protocol["destination_chain_bridge_adapter"]  # just for testing
    gas_limit = 2000
    message = b"test message"
    with reverts("14"): # NO_BRIDGE_ADAPTERS_FOR_SPECIFIED_CHAIN
        cross_chain_controller.forwardMessage(
            destination_chain_id, destination, gas_limit, message, {"from": carol}
        )


def test_forward_message_wrong_caller(setup_protocol, alice, MainnetChainIds):
    """
    Testing `forwardMessage()` when the caller is not approved
    """
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    destination_chain_id = MainnetChainIds.POLYGON
    destination = setup_protocol["destination_chain_bridge_adapter"]  # just for testing
    gas_limit = 2000
    message = b"test message"
    with reverts("2"): # CALLER_IS_NOT_APPROVED_SENDER
        cross_chain_controller.forwardMessage(
            destination_chain_id, destination, gas_limit, message, {"from": alice}
        )


def test_retry_envelope(setup_protocol, carol, MainnetChainIds, owner):
    """
    Testing `retryEnvelope()`
    """
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    current_chain_bridge_adapter = setup_protocol["current_chain_bridge_adapter"]
    # call to `forwardMessage()` to register the envelope
    destination_chain_id = MainnetChainIds.POLYGON
    origin_chain_id = chain.id
    destination = setup_protocol["destination_chain_bridge_adapter"]  # just for testing
    gas_limit = 2000
    message = b"test message"
    tx = cross_chain_controller.forwardMessage(
        destination_chain_id, destination, gas_limit, message, {"from": carol}
    )
    # envelope
    envelope = [0, carol.address, destination.address, origin_chain_id, destination_chain_id, message]
    envelope_data = encode_single("((uint256,address,address,uint256,uint256,bytes))", [envelope])
    envelope_id = web3.keccak(envelope_data)
    encoded_envelope = [envelope_id, envelope_data]
    gas_limit = 2000

    # transaction
    transaction = [1, envelope_data]
    transaction_data = encode_single("((uint256,bytes))", [transaction])
    transaction_id = web3.keccak(transaction_data)
    tx = cross_chain_controller.retryEnvelope(envelope, gas_limit, {"from": owner})
    # TransactionForwardingAttempted event
    assert tx.return_value == transaction_id.hex()
    assert tx.events["TransactionForwardingAttempted"]["transactionId"] == transaction_id.hex()
    assert tx.events["TransactionForwardingAttempted"]["envelopeId"] == envelope_id.hex()
    assert tx.events["TransactionForwardingAttempted"]["destinationChainId"] == destination_chain_id
    assert tx.events["TransactionForwardingAttempted"]["bridgeAdapter"] == current_chain_bridge_adapter
    assert tx.events["TransactionForwardingAttempted"]["destinationBridgeAdapter"] == destination
    assert tx.events["TransactionForwardingAttempted"]["adapterSuccessful"] is True
    assert tx.events["TransactionForwardingAttempted"]["returnData"] == '0x00'


def test_retry_envelope_non_registered_envelope(setup_protocol, carol, MainnetChainIds, owner):
    """
    Testing `retryEnvelope()` for a non registered envelope
    """
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    # call to `forwardMessage()` to register the envelope
    destination_chain_id = MainnetChainIds.POLYGON
    destination = setup_protocol["destination_chain_bridge_adapter"]  # just for testing
    gas_limit = 2000
    message = b"test message"
    # envelope
    envelope = [0, carol.address, destination.address, 1, destination_chain_id, message]
    gas_limit = 2000

    with reverts("3"): # ENVELOPE_NOT_PREVIOUSLY_REGISTERED
        cross_chain_controller.retryEnvelope(envelope, gas_limit, {"from": owner})



def test_retry_envelope_no_bridge(setup_protocol, carol, MainnetChainIds, owner):
    """
    Testing `retryEnvelope()` when there is no bridge adapters for the destination chain
    """
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    current_chain_bridge_adapter = setup_protocol["current_chain_bridge_adapter"]
    # call to `forwardMessage()` to register the envelope
    destination_chain_id = MainnetChainIds.POLYGON
    origin_chain_id = chain.id
    destination = setup_protocol["destination_chain_bridge_adapter"]  # just for testing
    gas_limit = 2000
    message = b"test message"
    tx = cross_chain_controller.forwardMessage(
        destination_chain_id, destination, gas_limit, message, {"from": carol}
    )
    # envelope
    envelope = [0, carol.address, destination.address, origin_chain_id, destination_chain_id, message]
    envelope_data = encode_single("((uint256,address,address,uint256,uint256,bytes))", [envelope])
    envelope_id = web3.keccak(envelope_data)
    gas_limit = 2000


    # disable bridge adapters
    bridge_adapter_to_disable = [current_chain_bridge_adapter.address, [destination_chain_id]]
    cross_chain_controller.disableBridgeAdapters([bridge_adapter_to_disable], {"from": owner})

    with reverts("14"): # NO_BRIDGE_ADAPTERS_FOR_SPECIFIED_CHAIN
        cross_chain_controller.retryEnvelope(envelope, gas_limit, {"from": owner})



def test_retry_transaction(setup_protocol, carol, MainnetChainIds, owner):
    """
    Testing `retryTransaction()`
    """
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    current_chain_bridge_adapter = setup_protocol["current_chain_bridge_adapter"]
    # call to `forwardMessage()` to register the envelope
    destination_chain_id = MainnetChainIds.POLYGON
    origin_chain_id = chain.id
    destination = setup_protocol["destination_chain_bridge_adapter"]  # just for testing
    gas_limit = 2000
    message = b"test message"
    tx = cross_chain_controller.forwardMessage(
        destination_chain_id, destination, gas_limit, message, {"from": carol}
    )
    # envelope
    envelope = [0, carol.address, destination.address, origin_chain_id, destination_chain_id, message]
    envelope_data = encode_single("((uint256,address,address,uint256,uint256,bytes))", [envelope])
    envelope_id = web3.keccak(envelope_data)
    encoded_envelope = [envelope_id, envelope_data]
    gas_limit = 2000

    # transaction
    transaction = [0, envelope_data]
    transaction_data = encode_single("((uint256,bytes))", [transaction])
    transaction_id = web3.keccak(transaction_data)
    tx = cross_chain_controller.retryTransaction(transaction_data, gas_limit, [current_chain_bridge_adapter], {"from": owner})
    # Validation
    assert tx.events["TransactionForwardingAttempted"]["transactionId"] == transaction_id.hex()
    assert tx.events["TransactionForwardingAttempted"]["envelopeId"] == envelope_id.hex()
    assert tx.events["TransactionForwardingAttempted"]["destinationChainId"] == destination_chain_id
    assert tx.events["TransactionForwardingAttempted"]["bridgeAdapter"] == current_chain_bridge_adapter
    assert tx.events["TransactionForwardingAttempted"]["destinationBridgeAdapter"] == destination
    assert tx.events["TransactionForwardingAttempted"]["adapterSuccessful"] is True
    assert tx.events["TransactionForwardingAttempted"]["returnData"] == '0x00'


def test_retry_transaction_no_bridge(setup_protocol, carol, MainnetChainIds, owner):
    """
    Testing `retryTransaction()` when there is no bridge adapters for the destination chain
    """
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    current_chain_bridge_adapter = setup_protocol["current_chain_bridge_adapter"]
    # call to `forwardMessage()` to register the envelope
    destination_chain_id = MainnetChainIds.POLYGON
    origin_chain_id = chain.id
    destination = setup_protocol["destination_chain_bridge_adapter"]  # just for testing
    gas_limit = 2000
    message = b"test message"
    tx = cross_chain_controller.forwardMessage(
        destination_chain_id, destination, gas_limit, message, {"from": carol}
    )
    # envelope
    envelope = [0, carol.address, destination.address, origin_chain_id, destination_chain_id, message]
    envelope_data = encode_single("((uint256,address,address,uint256,uint256,bytes))", [envelope])
    envelope_id = web3.keccak(envelope_data)
    gas_limit = 2000

    # transaction
    transaction = [0, envelope_data]
    transaction_data = encode_single("((uint256,bytes))", [transaction])

    # disable bridge adapters
    bridge_adapter_to_disable = [current_chain_bridge_adapter.address, [destination_chain_id]]
    cross_chain_controller.disableBridgeAdapters([bridge_adapter_to_disable], {"from": owner})

    with reverts("14"): # NO_BRIDGE_ADAPTERS_FOR_SPECIFIED_CHAIN
         cross_chain_controller.retryTransaction(transaction_data, gas_limit, [current_chain_bridge_adapter], {"from": owner})



def test_retry_transaction_not_prev_forwarded_transaction(setup_protocol, carol, MainnetChainIds, owner):
    """
    Testing `retryTransaction()` for a non previously forwarded transaction
    """
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    current_chain_bridge_adapter = setup_protocol["current_chain_bridge_adapter"]
    # call to `forwardMessage()` to register the envelope
    destination_chain_id = MainnetChainIds.POLYGON
    origin_chain_id = chain.id
    destination = setup_protocol["destination_chain_bridge_adapter"]  # just for testing
    gas_limit = 2000
    message = b"test message"
    tx = cross_chain_controller.forwardMessage(
        destination_chain_id, destination, gas_limit, message, {"from": carol}
    )
    # envelope
    envelope = [0, carol.address, destination.address, origin_chain_id, destination_chain_id, message]
    envelope_data = encode_single("((uint256,address,address,uint256,uint256,bytes))", [envelope])
    envelope_id = web3.keccak(envelope_data)
    gas_limit = 2000

    # transaction not previously forwarded
    transaction = [1337, envelope_data]
    transaction_data = encode_single("((uint256,bytes))", [transaction])

    with reverts("19"): # TRANSACTION_NOT_PREVIOUSLY_FORWARDED
         cross_chain_controller.retryTransaction(transaction_data, gas_limit, [current_chain_bridge_adapter], {"from": owner})


def test_retry_transaction_use_the_same_bridge_twice(setup_protocol, carol, MainnetChainIds, owner):
    """
    Testing `retryTransaction()` when using the same bridge adapter twice
    """
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    current_chain_bridge_adapter = setup_protocol["current_chain_bridge_adapter"]
    # call to `forwardMessage()` to register the envelope
    destination_chain_id = MainnetChainIds.POLYGON
    origin_chain_id = chain.id
    destination = setup_protocol["destination_chain_bridge_adapter"]  # just for testing
    gas_limit = 2000
    message = b"test message"
    tx = cross_chain_controller.forwardMessage(
        destination_chain_id, destination, gas_limit, message, {"from": carol}
    )
    # envelope
    envelope = [0, carol.address, destination.address, origin_chain_id, destination_chain_id, message]
    envelope_data = encode_single("((uint256,address,address,uint256,uint256,bytes))", [envelope])
    envelope_id = web3.keccak(envelope_data)
    gas_limit = 2000

    # transaction
    transaction = [0, envelope_data]
    transaction_data = encode_single("((uint256,bytes))", [transaction])

    with reverts("21"): # BRIDGE_ADAPTERS_SHOULD_BE_UNIQUE
         cross_chain_controller.retryTransaction(transaction_data, gas_limit, [current_chain_bridge_adapter, current_chain_bridge_adapter], {"from": owner})


def test_approve_senders(setup_protocol, owner, alice, bob):
    """
    Testing `approveSenders()`
    """
    cross_chain_controller = setup_protocol["cross_chain_controller"]

    # call `approveSenders()`
    senders = [alice, bob]
    tx = cross_chain_controller.approveSenders(senders, {"from": owner})

    for i,sender in enumerate(senders):
        assert tx.events["SenderUpdated"][i]["sender"] == sender
        assert tx.events["SenderUpdated"][i]["isApproved"] is True
        assert cross_chain_controller.isSenderApproved(sender) is True


def test_remove_senders(setup_protocol, owner, alice, bob, carol):
    """
    Testing `removeSenders()`
    """
    cross_chain_controller = setup_protocol["cross_chain_controller"]

    # call `removeSenders()`
    senders = [alice, bob, carol]
    tx = cross_chain_controller.removeSenders(senders, {"from": owner})

    # Validation
    for i,sender in enumerate(senders):
        assert tx.events["SenderUpdated"][i]["sender"] == sender
        assert tx.events["SenderUpdated"][i]["isApproved"] is False
        assert cross_chain_controller.isSenderApproved(sender) is False


def test_enable_bridge_adapters(setup_protocol, owner, MainnetChainIds):
    """
    Testing `enableBridgeAdapters()`
    """
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    current_chain_bridge_adapter = setup_protocol["current_chain_bridge_adapter"]
    destination_chain_bridge_adapter = setup_protocol["destination_chain_bridge_adapter"]


    # call `enableBridgeAdapters()`
    bridge_adapter_1 = [
            current_chain_bridge_adapter, # currentChainBridgeAdapter
            destination_chain_bridge_adapter, # destinationBridgeAdapter
            MainnetChainIds.AVALANCHE, # destinationChainId
    ]

    bridge_adapter_2 = [
            current_chain_bridge_adapter, # currentChainBridgeAdapter
            destination_chain_bridge_adapter, # destinationBridgeAdapter
            MainnetChainIds.OPTIMISM, # destinationChainId
    ]

    bridge_adapters = [bridge_adapter_1, bridge_adapter_2]
    tx = cross_chain_controller.enableBridgeAdapters(bridge_adapters, {"from": owner})

    # Validation
    for i,bridge_adapter in enumerate(bridge_adapters):
        assert tx.events["BridgeAdapterUpdated"][i]["destinationChainId"] == bridge_adapter[2]
        assert tx.events["BridgeAdapterUpdated"][i]["bridgeAdapter"] == bridge_adapter[0]
        assert tx.events["BridgeAdapterUpdated"][i]["destinationBridgeAdapter"] == bridge_adapter[1]
        assert tx.events["BridgeAdapterUpdated"][i]["allowed"] is True
    bridge_config = cross_chain_controller.getForwarderBridgeAdaptersByChain(MainnetChainIds.AVALANCHE)[0]
    assert bridge_config[0] == destination_chain_bridge_adapter  # destinationBridgeAdapter
    assert bridge_config[1] == current_chain_bridge_adapter  # currentChainBridgeAdapter
    bridge_config = cross_chain_controller.getForwarderBridgeAdaptersByChain(MainnetChainIds.OPTIMISM)[0]
    assert bridge_config[0] == destination_chain_bridge_adapter  # destinationBridgeAdapter
    assert bridge_config[1] == current_chain_bridge_adapter  # currentChainBridgeAdapter



def test_enable_bridge_adapters_zero_address(setup_protocol, owner, MainnetChainIds, constants):
    """
    Testing `enableBridgeAdapters()` for a zero address adapters
    """
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    current_chain_bridge_adapter = setup_protocol["current_chain_bridge_adapter"]
    destination_chain_bridge_adapter = setup_protocol["destination_chain_bridge_adapter"]


    # call `enableBridgeAdapters()`
    bridge_adapter_1 = [
            current_chain_bridge_adapter, # currentChainBridgeAdapter
            destination_chain_bridge_adapter, # destinationBridgeAdapter
            MainnetChainIds.AVALANCHE, # destinationChainId
    ]

    bridge_adapter_2 = [
            current_chain_bridge_adapter, # currentChainBridgeAdapter
            constants.ZERO_ADDRESS, # destinationBridgeAdapter (address(0))
            MainnetChainIds.OPTIMISM, # destinationChainId
    ]

    bridge_adapters = [bridge_adapter_1, bridge_adapter_2]
    with reverts("4"):
        cross_chain_controller.enableBridgeAdapters(bridge_adapters, {"from": owner})



def test_disable_bridge_adapters(setup_protocol, owner, MainnetChainIds):
    """
    Testing `disableBridgeAdapters()`
    """
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    current_chain_bridge_adapter = setup_protocol["current_chain_bridge_adapter"]
    destination_chain_bridge_adapter = setup_protocol["destination_chain_bridge_adapter"]

     # disable bridge adapters
    bridge_adapter_to_disable = [current_chain_bridge_adapter.address, [MainnetChainIds.POLYGON]]
    tx = cross_chain_controller.disableBridgeAdapters([bridge_adapter_to_disable], {"from": owner})

    # Validation
    assert tx.events["BridgeAdapterUpdated"]["destinationChainId"] == MainnetChainIds.POLYGON
    assert tx.events["BridgeAdapterUpdated"]["bridgeAdapter"] == current_chain_bridge_adapter
    assert tx.events["BridgeAdapterUpdated"]["destinationBridgeAdapter"] == destination_chain_bridge_adapter
    assert tx.events["BridgeAdapterUpdated"]["allowed"] is False
    bridge_config = cross_chain_controller.getForwarderBridgeAdaptersByChain(MainnetChainIds.POLYGON)
    assert len(bridge_config) == 0


###########################################
##### Tests for CrossChainReceiver  #######
###########################################

def test_receive_cross_chain_message_case_1(setup_protocol, bridge_adapter, carol, MainnetChainIds, constants):
    """
    Testing `receiveCrossChainMessage()` when there is enough number of confirmations
    the required number of confirmation in this case is '1'
    """
    cross_chain_controller = setup_protocol["cross_chain_controller"]
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

    tx = cross_chain_controller.receiveCrossChainMessage(encode_transaction, origin_chain_id, {"from": bridge_adapter})

    #Validation
    transaction_state = cross_chain_controller.getTransactionState['bytes32'](transaction_id)
    assert transaction_state[0] == 1 # confirmations
    assert transaction_state[1] == tx.timestamp # firstBridgedAt
    envelope_state = cross_chain_controller.getEnvelopeState['bytes32'](envelope_id)
    assert envelope_state == constants.EnvelopeState["Delivered"]
    assert cross_chain_controller.isTransactionReceivedByAdapter(transaction_id, bridge_adapter) is True
    #logs
    # TransactionReceived event
    assert tx.events["TransactionReceived"]["transactionId"] == transaction_id.hex()
    assert tx.events["TransactionReceived"]["envelopeId"] == envelope_id.hex()
    assert tx.events["TransactionReceived"]["originChainId"] == origin_chain_id
    assert tx.events["TransactionReceived"]["transaction"][0] == transaction[0]
    assert tx.events["TransactionReceived"]["transaction"][1].hex() == transaction[1].hex()
    assert tx.events["TransactionReceived"]["bridgeAdapter"] == bridge_adapter
    assert tx.events["TransactionReceived"]["confirmations"] == 1
    # EnvelopeDeliveryAttempted event
    assert tx.events["EnvelopeDeliveryAttempted"]["envelopeId"] == envelope_id.hex()
    assert tx.events["EnvelopeDeliveryAttempted"]["envelope"][0] == envelope[0]
    assert tx.events["EnvelopeDeliveryAttempted"]["envelope"][1] == envelope[1]
    assert tx.events["EnvelopeDeliveryAttempted"]["envelope"][2] == envelope[2]
    assert tx.events["EnvelopeDeliveryAttempted"]["envelope"][3] == envelope[3]
    assert tx.events["EnvelopeDeliveryAttempted"]["envelope"][4] == envelope[4]
    assert tx.events["EnvelopeDeliveryAttempted"]["envelope"][5].hex() == envelope[5].hex()
    assert tx.events["EnvelopeDeliveryAttempted"]["isDelivered"] is True


def test_receive_cross_chain_message_case_2(setup_protocol, bridge_adapter, alice, owner, carol, MainnetChainIds, constants):
    """
    Testing `receiveCrossChainMessage()` when the number of confirmation is not enough
    the required number of confirmation in this case is '2'
    """
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    # Add new bridge adapter to the ETHEREUM Mainnet
    bridge_adapters_input = [alice.address, [chain.id]]
    cross_chain_controller.allowReceiverBridgeAdapters([bridge_adapters_input], {"from": owner})
    # update confirmation
    required_confirmation = 2
    chain_id = chain.id
    cross_chain_controller.updateConfirmations([[chain_id, required_confirmation]], {"from": owner})

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

    tx = cross_chain_controller.receiveCrossChainMessage(encode_transaction, origin_chain_id, {"from": bridge_adapter})

    #Validation
    transaction_state = cross_chain_controller.getTransactionState['bytes32'](transaction_id)
    first_bridge_at = tx.timestamp
    assert transaction_state[0] == 1 # confirmations
    assert transaction_state[1] == first_bridge_at # firstBridgedAt
    envelope_state = cross_chain_controller.getEnvelopeState['bytes32'](envelope_id)
    assert envelope_state == constants.EnvelopeState["None"]
    #logs
    # TransactionReceived event
    assert tx.events["TransactionReceived"]["transactionId"] == transaction_id.hex()
    assert tx.events["TransactionReceived"]["envelopeId"] == envelope_id.hex()
    assert tx.events["TransactionReceived"]["originChainId"] == origin_chain_id
    assert tx.events["TransactionReceived"]["bridgeAdapter"] == bridge_adapter
    assert tx.events["TransactionReceived"]["confirmations"] == 1
    assert "EnvelopeDeliveryAttempted" not in tx.events

    # call again receiveCrossChainMessage with the same adapter
    tx = cross_chain_controller.receiveCrossChainMessage(encode_transaction, origin_chain_id, {"from": bridge_adapter})
    # nothing should change and no event should be triggered
    # Validation
    transaction_state = cross_chain_controller.getTransactionState['bytes32'](transaction_id)
    assert transaction_state[0] == 1 # confirmations
    assert transaction_state[1] == first_bridge_at # firstBridgedAt
    envelope_state = cross_chain_controller.getEnvelopeState['bytes32'](envelope_id)
    assert envelope_state == constants.EnvelopeState["None"]
    assert "TransactionReceived" not in tx.events
    assert "EnvelopeDeliveryAttempted" not in tx.events


    # call again receiveCrossChainMessage from the other adapter to reach the number of the required confirmations
    tx = cross_chain_controller.receiveCrossChainMessage(encode_transaction, origin_chain_id, {"from": alice})

    #Validation
    transaction_state = cross_chain_controller.getTransactionState['bytes32'](transaction_id)
    assert transaction_state[0] == 2 # confirmations
    assert transaction_state[1] == first_bridge_at # firstBridgedAt
    envelope_state = cross_chain_controller.getEnvelopeState['bytes32'](envelope_id)
    assert envelope_state == constants.EnvelopeState["Delivered"]
    #logs
    # TransactionReceived event
    assert tx.events["TransactionReceived"]["transactionId"] == transaction_id.hex()
    assert tx.events["TransactionReceived"]["envelopeId"] == envelope_id.hex()
    assert tx.events["TransactionReceived"]["originChainId"] == origin_chain_id
    assert tx.events["TransactionReceived"]["bridgeAdapter"] == alice
    assert tx.events["TransactionReceived"]["confirmations"] == 2
    # EnvelopeDeliveryAttempted event
    assert tx.events["EnvelopeDeliveryAttempted"]["envelopeId"] == envelope_id.hex()
    assert tx.events["EnvelopeDeliveryAttempted"]["envelope"][0] == envelope[0]
    assert tx.events["EnvelopeDeliveryAttempted"]["envelope"][1] == envelope[1]
    assert tx.events["EnvelopeDeliveryAttempted"]["envelope"][2] == envelope[2]
    assert tx.events["EnvelopeDeliveryAttempted"]["envelope"][3] == envelope[3]
    assert tx.events["EnvelopeDeliveryAttempted"]["envelope"][4] == envelope[4]
    assert tx.events["EnvelopeDeliveryAttempted"]["envelope"][5].hex() == envelope[5].hex()
    assert tx.events["EnvelopeDeliveryAttempted"]["isDelivered"] is True


def test_receive_cross_chain_message_case_3(setup_protocol, bridge_adapter, alice, owner, carol, MainnetChainIds, constants):
    """
    Testing `receiveCrossChainMessage()` when transactionFirstBridgedAt <= configuration.validityTimestamp
    """
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    # Add new bridge adapter to the ETHEREUM Mainnet
    bridge_adapters_input = [alice.address, [chain.id]]
    cross_chain_controller.allowReceiverBridgeAdapters([bridge_adapters_input], {"from": owner})
    # update confirmation
    required_confirmation = 2
    chain_id = chain.id
    cross_chain_controller.updateConfirmations([[chain_id, required_confirmation]], {"from": owner})


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

    tx = cross_chain_controller.receiveCrossChainMessage(encode_transaction, origin_chain_id, {"from": bridge_adapter})

    #Validation
    transaction_state = cross_chain_controller.getTransactionState['bytes32'](transaction_id)
    first_bridge_at = tx.timestamp
    assert transaction_state[0] == 1 # confirmations
    assert transaction_state[1] == first_bridge_at # firstBridgedAt
    envelope_state = cross_chain_controller.getEnvelopeState['bytes32'](envelope_id)
    assert envelope_state == constants.EnvelopeState["None"]
    #logs
    # TransactionReceived event
    assert tx.events["TransactionReceived"]["transactionId"] == transaction_id.hex()
    assert tx.events["TransactionReceived"]["envelopeId"] == envelope_id.hex()
    assert tx.events["TransactionReceived"]["originChainId"] == origin_chain_id
    assert tx.events["TransactionReceived"]["bridgeAdapter"] == bridge_adapter
    assert tx.events["TransactionReceived"]["confirmations"] == 1
    assert "EnvelopeDeliveryAttempted" not in tx.events

    # time wrap
    delta = 60 * 60 * 24   # 1 day
    chain.mine(timedelta=delta)

    # update the validity validityTimestamp so that transactionFirstBridgedAt <= validityTimestamp
    chain_id = chain.id
    validity_timestamp = chain.time()
    validity_timestamp_input = [chain_id, validity_timestamp]

    cross_chain_controller.updateMessagesValidityTimestamp([validity_timestamp_input], {"from": owner})

    assert first_bridge_at <= validity_timestamp

    # call again receiveCrossChainMessage from the other adapter
    tx = cross_chain_controller.receiveCrossChainMessage(encode_transaction, origin_chain_id, {"from": alice})

    # nothing should change and no event should be triggered
    # Validation
    transaction_state = cross_chain_controller.getTransactionState['bytes32'](transaction_id)
    assert transaction_state[0] == 1 # confirmations
    assert transaction_state[1] == first_bridge_at # firstBridgedAt
    envelope_state = cross_chain_controller.getEnvelopeState['bytes32'](envelope_id)
    assert envelope_state == constants.EnvelopeState["None"]
    assert "TransactionReceived" not in tx.events
    assert "EnvelopeDeliveryAttempted" not in tx.events


def test_deliver_envelope(setup_protocol, bridge_adapter, carol, MainnetChainIds, constants, alice):
    """
    Testing `deliverEnvelope()`
    """
    cross_chain_controller = setup_protocol["cross_chain_controller"]
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

    # the transaction should not be delivered, so we set the variable `toRevert` to true
    destination.setToRevert({"from": carol})

    tx = cross_chain_controller.receiveCrossChainMessage(encode_transaction, origin_chain_id, {"from": bridge_adapter})

    #Validation
    transaction_state = cross_chain_controller.getTransactionState['bytes32'](transaction_id)
    assert transaction_state[0] == 1 # confirmations
    assert transaction_state[1] == tx.timestamp # firstBridgedAt
    envelope_state = cross_chain_controller.getEnvelopeState['bytes32'](envelope_id)
    assert envelope_state == constants.EnvelopeState["Confirmed"]
    assert cross_chain_controller.isTransactionReceivedByAdapter(transaction_id, bridge_adapter) is True
    #logs
    # TransactionReceived event
    assert tx.events["TransactionReceived"]["transactionId"] == transaction_id.hex()
    assert tx.events["TransactionReceived"]["envelopeId"] == envelope_id.hex()
    assert tx.events["TransactionReceived"]["originChainId"] == origin_chain_id
    assert tx.events["TransactionReceived"]["bridgeAdapter"] == bridge_adapter
    assert tx.events["TransactionReceived"]["confirmations"] == 1
    # EnvelopeDeliveryAttempted event
    assert tx.events["EnvelopeDeliveryAttempted"]["envelopeId"] == envelope_id.hex()
    assert tx.events["EnvelopeDeliveryAttempted"]["envelope"][0] == envelope[0]
    assert tx.events["EnvelopeDeliveryAttempted"]["envelope"][1] == envelope[1]
    assert tx.events["EnvelopeDeliveryAttempted"]["envelope"][2] == envelope[2]
    assert tx.events["EnvelopeDeliveryAttempted"]["envelope"][3] == envelope[3]
    assert tx.events["EnvelopeDeliveryAttempted"]["envelope"][4] == envelope[4]
    assert tx.events["EnvelopeDeliveryAttempted"]["envelope"][5].hex() == envelope[5].hex()
    assert tx.events["EnvelopeDeliveryAttempted"]["isDelivered"] is False

    # the transaction should be delivered now, so we set the variable `toRevert` to false
    destination.setNotRevert({"from": carol})
    # call `deliverEnvelope`
    tx = cross_chain_controller.deliverEnvelope(envelope, {"from": alice})

    #Validation
    envelope_state = cross_chain_controller.getEnvelopeState['bytes32'](envelope_id)
    assert envelope_state == constants.EnvelopeState["Delivered"]
    # EnvelopeDeliveryAttempted event
    assert tx.events["EnvelopeDeliveryAttempted"]["envelopeId"] == envelope_id.hex()
    assert tx.events["EnvelopeDeliveryAttempted"]["envelope"][0] == envelope[0]
    assert tx.events["EnvelopeDeliveryAttempted"]["envelope"][1] == envelope[1]
    assert tx.events["EnvelopeDeliveryAttempted"]["envelope"][2] == envelope[2]
    assert tx.events["EnvelopeDeliveryAttempted"]["envelope"][3] == envelope[3]
    assert tx.events["EnvelopeDeliveryAttempted"]["envelope"][4] == envelope[4]
    assert tx.events["EnvelopeDeliveryAttempted"]["envelope"][5].hex() == envelope[5].hex()
    assert tx.events["EnvelopeDeliveryAttempted"]["isDelivered"] is True


def test_deliver_envelope_invalid_state(setup_protocol, carol, MainnetChainIds, alice):
    """
    Testing `deliverEnvelope()` when the envelope state is not the correct one
    """
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    destination_chain_id = chain.id
    origin_chain_id = chain.id
    destination = setup_protocol["destination_chain_bridge_adapter"]
    message = b"test message"
    # envelope
    envelope = [0, carol.address, destination.address, origin_chain_id, destination_chain_id, message]
    envelope_data = encode_single("((uint256,address,address,uint256,uint256,bytes))", [envelope])
    envelope_id = web3.keccak(envelope_data)

    with reverts("22"): #ENVELOPE_NOT_CONFIRMED_OR_DELIVERED
        cross_chain_controller.deliverEnvelope(envelope, {"from": alice})


def test_allow_receiver_bridge_adapters(setup_protocol, owner, alice, carol, MainnetChainIds):
    """
    Testing `allowReceiverBridgeAdapters()`
    """
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    bridge_adapters_input_1 = [alice.address, [chain.id]]
    bridge_adapters_input_2 = [carol.address, [MainnetChainIds.POLYGON, MainnetChainIds.AVALANCHE]]
    bridge_adapters_inputs = [bridge_adapters_input_1, bridge_adapters_input_2]

    tx = cross_chain_controller.allowReceiverBridgeAdapters(bridge_adapters_inputs, {"from": owner})

    # Validation
    assert cross_chain_controller.isReceiverBridgeAdapterAllowed(alice, chain.id) is True
    assert cross_chain_controller.isReceiverBridgeAdapterAllowed(carol, MainnetChainIds.POLYGON) is True
    assert cross_chain_controller.isReceiverBridgeAdapterAllowed(carol, MainnetChainIds.AVALANCHE) is True

    # ReceiverBridgeAdaptersUpdated event
    # 1st event for the first bridge input
    assert tx.events["ReceiverBridgeAdaptersUpdated"][0]["bridgeAdapter"] == alice
    assert tx.events["ReceiverBridgeAdaptersUpdated"][0]["allowed"] is True
    assert tx.events["ReceiverBridgeAdaptersUpdated"][0]["chainId"] == chain.id
    # 2nd event for the second bridge input and for the POLYGON network
    assert tx.events["ReceiverBridgeAdaptersUpdated"][1]["bridgeAdapter"] == carol
    assert tx.events["ReceiverBridgeAdaptersUpdated"][1]["allowed"] is True
    assert tx.events["ReceiverBridgeAdaptersUpdated"][1]["chainId"] == MainnetChainIds.POLYGON
    # last event for the second bridge input and for the AVALANCHE network
    assert tx.events["ReceiverBridgeAdaptersUpdated"][2]["bridgeAdapter"] == carol
    assert tx.events["ReceiverBridgeAdaptersUpdated"][2]["allowed"] is True
    assert tx.events["ReceiverBridgeAdaptersUpdated"][2]["chainId"] == MainnetChainIds.AVALANCHE


def test_allow_receiver_bridge_adapters_same_adapter_same_chain(setup_protocol, owner, bridge_adapter, MainnetChainIds):
    """
    Testing `allowReceiverBridgeAdapters()` when adding the same adapter to the same chain
    """
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    bridge_adapters_input_1 = [bridge_adapter.address, [chain.id]]

    tx = cross_chain_controller.allowReceiverBridgeAdapters([bridge_adapters_input_1], {"from": owner})


    # ReceiverBridgeAdaptersUpdated event should not be trigerred
    assert "ReceiverBridgeAdaptersUpdated" not in tx.events


def test_allow_receiver_bridge_adapters_zero_address_bridge(setup_protocol, owner, constants, MainnetChainIds):
    """
    Testing `allowReceiverBridgeAdapters()` when adding the same adapter to the same chain
    """
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    bridge_adapters_input_1 = [constants.ZERO_ADDRESS, [chain.id]]


    with reverts("18"): #INVALID_BRIDGE_ADAPTER
        cross_chain_controller.allowReceiverBridgeAdapters([bridge_adapters_input_1], {"from": owner})



def test_disable_receiver_bridge_adapters(setup_protocol, owner, bridge_adapter, MainnetChainIds):
    """
    Testing `disallowReceiverBridgeAdapters()`
    """
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    bridge_adapters_input_1 = [bridge_adapter.address, [chain.id]]


    tx = cross_chain_controller.disallowReceiverBridgeAdapters([bridge_adapters_input_1], {"from": owner})

    # Validation
    assert cross_chain_controller.isReceiverBridgeAdapterAllowed(bridge_adapter, chain.id) is False
    # ReceiverBridgeAdaptersUpdated event
    assert tx.events["ReceiverBridgeAdaptersUpdated"][0]["bridgeAdapter"] == bridge_adapter
    assert tx.events["ReceiverBridgeAdaptersUpdated"][0]["allowed"] is False
    assert tx.events["ReceiverBridgeAdaptersUpdated"][0]["chainId"] == chain.id

def test_update_confirmations(setup_protocol, owner, alice, carol, MainnetChainIds):
    """
    testing `updateConfirmations()`
    """

    cross_chain_controller = setup_protocol["cross_chain_controller"]
    bridge_adapters_input_1 = [alice.address, [MainnetChainIds.POLYGON]]
    bridge_adapters_input_2 = [carol.address, [MainnetChainIds.POLYGON]]
    bridge_adapters_inputs = [bridge_adapters_input_1, bridge_adapters_input_2]
    # call `allowReceiverBridgeAdapters()` first to add new adapters so that the call to `updateConfirmations()` do not revert
    cross_chain_controller.allowReceiverBridgeAdapters(bridge_adapters_inputs, {"from": owner})

    # update confirmation
    required_confirmation = 2
    chain_id = MainnetChainIds.POLYGON
    tx = cross_chain_controller.updateConfirmations([[chain_id, required_confirmation]], {"from": owner})

    # Validation
    assert tx.events["ConfirmationsUpdated"]["newConfirmations"] == required_confirmation
    assert tx.events["ConfirmationsUpdated"]["chainId"] == chain_id


def test_update_confirmations_incorrect_nb_confirmation(setup_protocol, owner, MainnetChainIds):
    """
    testing `updateConfirmations()` when the the nb of the required confirmations is incorrect
    """
    # case 1:  the required confirmations is > than the number of bridges
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    # update confirmation
    required_confirmation = 2
    chain_id = MainnetChainIds.POLYGON
    with reverts("16"): #INVALID_REQUIRED_CONFIRMATIONS
        cross_chain_controller.updateConfirmations([[chain_id, required_confirmation]], {"from": owner})

    # case 2: required confirmations = 0

     # update confirmation
    required_confirmation = 0
    chain_id = MainnetChainIds.POLYGON
    with reverts("16"): #INVALID_REQUIRED_CONFIRMATIONS
        cross_chain_controller.updateConfirmations([[chain_id, required_confirmation]], {"from": owner})


def test_update_messages_validity_timestamp(setup_protocol, owner, MainnetChainIds):
    """
    Testing `updateMessagesValidityTimestamp()`
    """
    cross_chain_controller = setup_protocol["cross_chain_controller"]

    chain_id = chain.id
    validity_timestamp = 1689000000
    validity_timestamp_input = [chain_id, validity_timestamp]


    tx = cross_chain_controller.updateMessagesValidityTimestamp([validity_timestamp_input], {"from": owner})

    # Validation
    assert tx.events["NewInvalidation"]["invalidTimestamp"] == validity_timestamp
    assert tx.events["NewInvalidation"]["chainId"] == chain_id


def test_update_messages_validity_timestamp_invalid_timestamp(setup_protocol, owner, MainnetChainIds):
    """
    Testing `updateMessagesValidityTimestamp()` for a timestamp in the future
    """
    cross_chain_controller = setup_protocol["cross_chain_controller"]

    chain_id = chain.id
    validity_timestamp = 2689000000
    validity_timestamp_input = [chain_id, validity_timestamp]

    with reverts("6"): #INVALID_VALIDITY_TIMESTAMP
        cross_chain_controller.updateMessagesValidityTimestamp([validity_timestamp_input], {"from": owner})

