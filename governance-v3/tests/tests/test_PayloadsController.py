"""✅❎⛔
External Functions:
constructor ✅
receiveCrossChainMessage ✅

External Functions of PayloadsControllerCore:
initialize ✅
updateExpirationDelay ✅
createPayload ✅
executePayload ✅
cancelPayload ✅
updateExecutors ✅
getPayloadById ✅ (in createPayload test)
getPayloadsCount ✅ (in createPayload test)
getExpirationDelay ✅ (in updateExpirationDelay test)
getExecutorSettingsByAccessControl ✅ (in updateExecutors test)

Internal Functions of PayloadsControllerCore:
_queuePayload ✅ (in receiveCrossChainMessage test)
_updateExecutors ✅ (in updateExecutors test)
_updateExpirationDelay ✅ (in updateExpirationDelay test)
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


def test_basic(setup_protocol, owner, constants):
    proxy_admin = setup_protocol["proxy_admin"]
    payload_controller = setup_protocol["payload_controller"]
    payload_controller_logic = setup_protocol["payload_controller_logic"]

    info = proxy_admin.getProxyImplementation(payload_controller)

    assert info == payload_controller_logic.address


def test_constructor(setup_protocol, owner, constants):
    payload_controller = setup_protocol["payload_controller"]
    message_originator = setup_protocol["message_originator"]
    cross_chain_controller = setup_protocol["cross_chain_controller"]

    assert payload_controller.MESSAGE_ORIGINATOR() == message_originator.address
    assert payload_controller.CROSS_CHAIN_CONTROLLER() == cross_chain_controller.address
    assert payload_controller.ORIGIN_CHAIN_ID() == 1


def test_initialize(setup_protocol, owner, guardian):
    executor1 = setup_protocol["executor1"]
    executor2 = setup_protocol["executor2"]
    payload_controller = setup_protocol["payload_controller"]


    executor = payload_controller.getExecutorSettingsByAccessControl(1)

    assert executor[0] == executor1
    assert executor[1] == 86400

    executor = payload_controller.getExecutorSettingsByAccessControl(2)

    assert executor[0] == executor2
    assert executor[1] == 864000

    assert payload_controller.guardian() == guardian

    assert payload_controller.owner() == owner

def test_updateExecutors(setup_protocol, owner, constants, alice):
    payload_controller = setup_protocol["payload_controller"]
    executor2 = setup_protocol["executor2"]

    delay = 60 * 60 * 24 * 2
    new_executors = [
        [
            1,  # 0 do not use
            # 1 short executor before, listing assets, changes of assets params, updates of the protocol etc
            # 2 long executor before, payloads controller updates
            [
                alice,  # executor
                delay,  # delay time in seconds between queuing and execution
            ],
        ]
    ]

    tx = payload_controller.updateExecutors(new_executors, {"from": owner})

    executors = payload_controller.getExecutorSettingsByAccessControl(1)

    assert executors[0] == alice
    assert executors[1] == delay

    # Events check
    assert tx.events[0].address == payload_controller
    assert tx.events[0].name == "ExecutorSet"
    assert tx.events[0]["accessLevel"] == 1
    assert tx.events[0]["executor"] == alice
    assert tx.events[0]["delay"] == delay

    # We didn't update the 2nd executor, so it should be the same
    executor = payload_controller.getExecutorSettingsByAccessControl(2)

    assert executor[0] == executor2
    assert executor[1] == 864000


def test_createPayload(setup_protocol, owner, constants, alice):
    payload_controller = setup_protocol["payload_controller"]
    weth = setup_protocol["weth"]

    deposit_signature = "deposit()"
    transfer_signature = "transfer(address,uint256)"

    # Deposit some ETH to get some WETH and then send it to alice
    access_level_action1 = 2
    access_level_action2 = 1
    execution_actions = [
        [
            weth,  # target
            False,  # withDelegateCall
            access_level_action1,  # accessLevel
            10**18,  # value
            deposit_signature, # signature
            b"",  # callData
        ],
        [
            weth,  # target
            False,  # withDelegateCall
            access_level_action2,  # accessLevel
            0,  # value
            transfer_signature, # signature
            weth.transfer.encode_input(alice.address, 10**18),  # callData
        ],
    ]

    # There should be no payloads yet
    assert payload_controller.getPayloadsCount() == 0

    # Create the payload
    tx = payload_controller.createPayload(execution_actions, {"from": alice})

    transaction_timestamp = tx.timestamp

    # There should be 1 payload now
    assert payload_controller.getPayloadsCount() == 1

    # Check events
    assert tx.events[0].address == payload_controller
    assert tx.events[0].name == "PayloadCreated"
    assert tx.events[0]["payloadId"] == 0
    assert tx.events[0]["creator"] == alice
    # assert tx.events[0]["actions"] == 1
    assert tx.events[0]["maximumAccessLevelRequired"] == max(access_level_action1, access_level_action2)

    # Check the payload itself
    payload = payload_controller.getPayloadById(0)

    assert payload["creator"] == alice  # creator
    assert payload["maximumAccessLevelRequired"] == max(access_level_action1, access_level_action2)  # maximumAccessLevelRequired
    assert payload["state"] == 1  # state (1 = Created)
    assert payload["createdAt"] == transaction_timestamp  # createdAt
    assert payload["queuedAt"] == 0  # queuedAt
    assert payload["executedAt"] == 0  # executedAt
    assert payload["cancelledAt"] == 0  # cancelledAt
    assert payload["expirationTime"] == transaction_timestamp + constants.EXPIRATION_DELAY # expirationTime
    assert payload["delay"] == 864_000
    assert payload["gracePeriod"] == constants.GRACE_PERIOD # expirationTime
    
    # Actions
    assert payload["actions"][0][0] == weth  # target
    assert payload["actions"][0][1] == False  # withDelegateCall
    assert payload["actions"][0][2] == access_level_action1  # accessLevel
    assert payload["actions"][0][3] == 10**18  # value
    assert payload["actions"][0][4] == deposit_signature # signature
    assert payload["actions"][0][5] == "0x"  # callData

    assert payload["actions"][1][0] == weth  # target
    assert payload["actions"][1][1] == False  # withDelegateCall
    assert payload["actions"][1][2] == access_level_action2  # accessLevel
    assert payload["actions"][1][3] == 0  # value
    assert payload["actions"][1][4] == transfer_signature # signature
    assert payload["actions"][1][5] == weth.transfer.encode_input(alice.address, 10**18)  # callData


def test_createPayload_reverts(setup_protocol, owner, constants, alice):
    payload_controller = setup_protocol["payload_controller"]
    weth = setup_protocol["weth"]

    # Deposit some ETH to get some WETH and then send it to alice
    execution_actions = [
        [
            weth,  # target
            False,  # withDelegateCall
            0,  # accessLevel
            10**18,  # value
            "deposit()", # signature
            b"",  # callData
        ]
    ]

    # We can't create a payload without any actions
    with reverts("34"):  # INVALID_EMPTY_TARGETS
        tx = payload_controller.createPayload([], {"from": owner})

    # Create the payload (should revert because of the accessLevel)
    with reverts("55"):  # INVALID_ACTION_ACCESS_LEVEL
        tx = payload_controller.createPayload(execution_actions, {"from": owner})


def test_receiveCrossChainMessage(setup_protocol, owner, constants, alice):
    payload_controller = setup_protocol["payload_controller"]
    weth = setup_protocol["weth"]
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    message_originator = setup_protocol["message_originator"]


    # Deposit some ETH to get some WETH and then send it to alice
    execution_actions = [
        [
            weth,  # target
            False,  # withDelegateCall
            2,  # accessLevel
            10**18,  # value
            "deposit()", # signature
            b"",  # callData
        ],
        [
            weth,  # target
            False,  # withDelegateCall
            1,  # accessLevel
            0,  # value
            "transfer(address,uint256)", # signature
            weth.transfer.encode_input(alice.address, 10**18),  # callData
        ],
    ]

    # There should be no payloads yet
    assert payload_controller.getPayloadsCount() == 0

    # Create the payload
    tx = payload_controller.createPayload(execution_actions, {"from": alice})

    creation_timestamp = tx.timestamp

    # encode the payload id into bytes
    delay = 60 * 60 * 12
    proposal_vote_activation_timestamp = creation_timestamp + delay
    bytes_message = encode_abi(["uint40", "uint8", "uint40"], [0, 2, proposal_vote_activation_timestamp])

    # Advance time to make sure the timestamp is different
    chain.mine(timedelta=delay)

    # Receive the message
    tx = payload_controller.receiveCrossChainMessage(
        message_originator, 1, bytes_message, {"from": cross_chain_controller}
    )
    queued_timestamp = tx.timestamp

    # Check events
    assert tx.events["PayloadQueued"]["payloadId"] == 0
    assert tx.events["PayloadExecutionMessageReceived"]["originSender"] == message_originator
    assert tx.events["PayloadExecutionMessageReceived"]["originChainId"] == 1
    assert tx.events["PayloadExecutionMessageReceived"]["delivered"] is True
    assert tx.events["PayloadExecutionMessageReceived"]["message"].hex() == bytes_message.hex()

    # Check the payload itself
    payload = payload_controller.getPayloadById(0)

    assert payload["creator"] == alice  # creator
    assert payload["maximumAccessLevelRequired"] == 2  # maximumAccessLevelRequired
    assert payload["state"] == 2  # state (2 = Queued)
    assert payload["createdAt"] == creation_timestamp  # createdAt
    assert payload["queuedAt"] == queued_timestamp  # queuedAt
    assert payload["executedAt"] == 0  # executedAt
    assert payload["cancelledAt"] == 0  # cancelledAt
    assert payload["expirationTime"] == creation_timestamp + constants.EXPIRATION_DELAY # expirationTime

    # Try to receive the message again (should revert because the payload is already queued)
    with reverts("39"):  # PAYLOAD_NOT_IN_CREATED_STATE
        tx = payload_controller.receiveCrossChainMessage(
            message_originator, 1, bytes_message, {"from": cross_chain_controller}
        )


def test_receiveCrossChainMessage_expired(setup_protocol, owner, constants, alice):
    payload_controller = setup_protocol["payload_controller"]
    weth = setup_protocol["weth"]
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    message_originator = setup_protocol["message_originator"]

    # Deposit some ETH to get some WETH and then send it to alice
    execution_actions = [
        [
            weth,  # target
            False,  # withDelegateCall
            2,  # accessLevel
            10**18,  # value
            "deposit()", # signature
            b"",  # callData
        ],
        [
            weth,  # target
            False,  # withDelegateCall
            1,  # accessLevel
            0,  # value
            "transfer(address,uint256)", # signature
            weth.transfer.encode_input(alice.address, 10**18),  # callData
        ],
    ]

    # There should be no payloads yet
    assert payload_controller.getPayloadsCount() == 0

    # Create the payload
    tx = payload_controller.createPayload(execution_actions, {"from": alice})

    # encode the payload id into bytes
    delay = 60 * 60 * 12
    proposal_vote_activation_timestamp = tx.timestamp + delay
    bytes_message = encode_abi(["uint40", "uint8", "uint40"], [0, 2, proposal_vote_activation_timestamp])

    # Advance time to expire the payload
    chain.mine(timedelta=constants.EXPIRATION_DELAY + 12)

    # Receive the message (should revert because the payload is expired)
    with reverts("39"):  # PAYLOAD_NOT_IN_CREATED_STATE
        tx = payload_controller.receiveCrossChainMessage(
            message_originator, 1, bytes_message, {"from": cross_chain_controller}
        )

def test_receiveCrossChainMessage_payload_created_after_proposal(setup_protocol, owner, constants, alice):
    payload_controller = setup_protocol["payload_controller"]
    weth = setup_protocol["weth"]
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    message_originator = setup_protocol["message_originator"]

    # Deposit some ETH to get some WETH and then send it to alice
    execution_actions = [
        [
            weth,  # target
            False,  # withDelegateCall
            2,  # accessLevel
            10**18,  # value
            "deposit()", # signature
            b"",  # callData
        ],
        [
            weth,  # target
            False,  # withDelegateCall
            1,  # accessLevel
            0,  # value
            "transfer(address,uint256)", # signature
            weth.transfer.encode_input(alice.address, 10**18),  # callData
        ],
    ]

    # There should be no payloads yet
    assert payload_controller.getPayloadsCount() == 0

    # Create the payload
    tx = payload_controller.createPayload(execution_actions, {"from": alice})

    # encode the payload id into bytes
    delay = 60 * 60 * 12
    proposal_vote_activation_timestamp = tx.timestamp - 2 * delay
    bytes_message = encode_abi(["uint40", "uint8", "uint40"], [0, 2, proposal_vote_activation_timestamp])

    # Advance time to expire the payload
    chain.mine(timedelta=delay)

    # Receive the message (should revert because the payload is created after the proposal vote started)
    with reverts("50"):  # PAYLOAD_NOT_CREATED_BEFORE_PROPOSAL
        tx = payload_controller.receiveCrossChainMessage(
            message_originator, 1, bytes_message, {"from": cross_chain_controller}
        )


def test_cancelPayload(setup_protocol, owner, constants, alice, guardian):
    payload_controller = setup_protocol["payload_controller"]
    weth = setup_protocol["weth"]
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    message_originator = setup_protocol["message_originator"]

    fake_ipfs_hash = web3.keccak(text="fake_ipfs_hash").hex()

    # Deposit some ETH to get some WETH and then send it to alice
    execution_actions = [
        [
            weth,  # target
            False,  # withDelegateCall
            2,  # accessLevel
            10**18,  # value
            "deposit()", # signature
            b"",  # callData
        ],
        [
            weth,  # target
            False,  # withDelegateCall
            1,  # accessLevel
            0,  # value
            "transfer(address,uint256)", # signature
            weth.transfer.encode_input(alice.address, 10**18),  # callData
        ],
    ]

    # There should be no payloads yet
    assert payload_controller.getPayloadsCount() == 0

    # Create the payload
    tx = payload_controller.createPayload(execution_actions, {"from": alice})

    creation_timestamp = tx.timestamp

    # Get the payload id
    payload_id = tx.events[0]["payloadId"]

    # Advance time to make sure the timestamp is different
    chain.mine(timedelta=345)

    # Cancel the payload (should revert because the sender is not the guardian)
    with reverts("ONLY_BY_GUARDIAN"):
        tx = payload_controller.cancelPayload(payload_id, {"from": alice})
    
    # Cancel the payload
    tx = payload_controller.cancelPayload(payload_id, {"from": guardian})

    cancel_timestamp = tx.timestamp

    # Check events
    assert tx.events[0].address == payload_controller
    assert tx.events[0].name == "PayloadCancelled"
    assert tx.events[0]["payloadId"] == payload_id

    # Check the payload itself
    payload = payload_controller.getPayloadById(payload_id)

    assert payload["creator"] == alice  # creator
    assert payload["maximumAccessLevelRequired"] == 2  # maximumAccessLevelRequired
    assert payload["state"] == 4  # state (4 = Cancelled)
    assert payload["createdAt"] == creation_timestamp  # createdAt
    assert payload["queuedAt"] == 0  # queuedAt
    assert payload["executedAt"] == 0  # executedAt
    assert payload["cancelledAt"] == cancel_timestamp  # cancelledAt
    assert payload["expirationTime"] == creation_timestamp + constants.EXPIRATION_DELAY # expirationTime


    # Try to cancel the payload again (should revert because the payload is already cancelled)
    with reverts("38"):  # PAYLOAD_NOT_IN_THE_CORRECT_STATE
        tx = payload_controller.cancelPayload(payload_id, {"from": guardian})


def test_executePayload(setup_protocol, owner, constants, alice, guardian, ForceDonate):
    payload_controller = setup_protocol["payload_controller"]
    weth = setup_protocol["weth"]
    cross_chain_controller = setup_protocol["cross_chain_controller"]
    message_originator = setup_protocol["message_originator"]
    executor1 = setup_protocol["executor1"]


    # the payload should have some ETH to execute the actions
    alice.transfer(payload_controller, 10 ** 18)
    assert payload_controller.balance() == 10**18

    # Get alice's WETH balance
    alice_weth_balance_before = weth.balanceOf(alice.address)

    transfer_calldata = encode_abi(["address", "uint256"], [alice.address, 10**18])

    # Deposit some ETH to get some WETH and then send it to alice
    execution_actions = [
        [
            weth,  # target
            False,  # withDelegateCall
            1,  # accessLevel
            10**18,  # value
            "deposit()",  # signature
            b"",  # callData
        ],
        [
            weth,  # target
            False,  # withDelegateCall
            1,  # accessLevel
            0,  # value
            "transfer(address,uint256)", # signature
            transfer_calldata,  # callData
        ],
    ]

    # There should be no payloads yet
    assert payload_controller.getPayloadsCount() == 0

    # Create the payload
    tx = payload_controller.createPayload(execution_actions, {"from": alice})

    creation_timestamp = tx.timestamp

    # Get the payload id
    payload_id = tx.events[0]["payloadId"]

    # encode the payload id into bytes
    delay = 60 * 60 * 12
    proposal_vote_activation_timestamp = creation_timestamp + delay
    bytes_message = encode_abi(["uint40", "uint8", "uint40"], [0, 2, proposal_vote_activation_timestamp])

    # Advance time to make sure the timestamp is different
    chain.mine(timedelta=345)

    # Queue the payload
    tx = payload_controller.receiveCrossChainMessage(
        message_originator, 1, bytes_message, {"from": cross_chain_controller}
    )

    queue_timestamp = tx.timestamp
    
    # Advance time by slightly less than the expiration delay
    chain.mine(timedelta=86_400 - 20)

    # Execute the payload (should revert because insufficient time has passed)
    with reverts("37"): # TIMELOCK_NOT_FINISHED
        tx = payload_controller.executePayload(payload_id, {"from": alice})

    #Advance time past the grace period
    chain.mine(timedelta=constants.GRACE_PERIOD + 999)

    # Execute the payload (should revert because the timelock has expired, so the payload is in expired state)
    with reverts("36"): # PAYLOAD_NOT_IN_QUEUED_STATE 
        tx = payload_controller.executePayload(payload_id, {"from": alice})

    # Rewind time to the start of the grace period
    chain.mine(timedelta=-(constants.GRACE_PERIOD + 999 - 40))

    # Execute the payload
    tx = payload_controller.executePayload(payload_id, {"from": alice})
    print(tx.info())

    execution_timestamp = tx.timestamp

    # Check events

    # First, the WETH deposit
    assert tx.events[0].address == weth
    assert tx.events[0].name == "Deposit"
    assert tx.events[0]["dst"] == executor1
    assert tx.events[0]["wad"] == 10**18

    # Second, the executor event
    assert tx.events[1].address == executor1
    assert tx.events[1].name == "ExecutedAction"
    assert tx.events[1]["target"] == weth
    assert tx.events[1]["value"] == 10**18
    assert tx.events[1]["signature"] == "deposit()"
    assert tx.events[1]["data"] == "0x00"
    assert tx.events[1]["executionTime"] == execution_timestamp
    assert tx.events[1]["withDelegatecall"] == False
    assert tx.events[1]["resultData"] == "0x00"

    # Third, the WETH transfer
    assert tx.events[2].address == weth
    assert tx.events[2].name == "Transfer"
    assert tx.events[2]["src"] == executor1
    assert tx.events[2]["dst"] == alice
    assert tx.events[2]["wad"] == 10**18

    # Fourth, the executor event
    assert tx.events[3].address == executor1
    assert tx.events[3].name == "ExecutedAction"
    assert tx.events[3]["target"] == weth
    assert tx.events[3]["value"] == 0
    assert tx.events[3]["signature"] == "transfer(address,uint256)"
    assert tx.events[3]["data"] == "0x"+transfer_calldata.hex()
    assert tx.events[3]["executionTime"] == execution_timestamp
    assert tx.events[3]["withDelegatecall"] == False
    assert tx.events[3]["resultData"] == "0x0000000000000000000000000000000000000000000000000000000000000001"

    # Fifth, the payload controller event
    assert tx.events[4].address == payload_controller
    assert tx.events[4].name == "PayloadExecuted"
    assert tx.events[4]["payloadId"] == payload_id

    # Check the payload itself
    payload = payload_controller.getPayloadById(payload_id)

    assert payload["creator"] == alice  # creator
    assert payload["maximumAccessLevelRequired"] == 1  # maximumAccessLevelRequired
    assert payload["state"] == 3  # state (3 = Executed)
    assert payload["createdAt"] == creation_timestamp  # createdAt
    assert payload["queuedAt"] == queue_timestamp # queuedAt
    assert payload["executedAt"] == execution_timestamp # executedAt
    assert payload["cancelledAt"] == 0  # cancelledAt
    assert payload["expirationTime"] == creation_timestamp + constants.EXPIRATION_DELAY # expirationTime
    
    # Check that the WETH was transferred to alice
    assert weth.balanceOf(alice.address) == alice_weth_balance_before + 10**18

    # Try to execute the payload again (should revert because the payload is already executed)
    with reverts("36"):  # PAYLOAD_NOT_IN_QUEUED_STATE
        tx = payload_controller.executePayload(payload_id, {"from": alice})
    

