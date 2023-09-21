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
    cross_chain_controller_emergency_mode = setup_protocol["cross_chain_controller_emergency_mode"]
    cross_chain_controller_emergency_mode_logic = setup_protocol["cross_chain_controller_emergency_mode_logic"]

    info = proxy_admin.getProxyImplementation(cross_chain_controller_emergency_mode)

    assert info == cross_chain_controller_emergency_mode_logic.address


def test_constructor(setup_protocol):
    """
    checking the variable set in the constructor in the CrossChainController proxy
    """
    cross_chain_controller_emergency_mode = setup_protocol["cross_chain_controller_emergency_mode"]
    cl_emergency_oracle = setup_protocol["cl_emergency_oracle"]
    assert cross_chain_controller_emergency_mode.getChainlinkEmergencyOracle() == cl_emergency_oracle


def test_initialize(
    setup_protocol, owner, guardian, MainnetChainIds, bridge_adapter, carol
):
    """
    Testing the initialization
    """
    cross_chain_controller_emergency_mode = setup_protocol["cross_chain_controller_emergency_mode"]
    current_chain_bridge_adapter = setup_protocol["current_chain_bridge_adapter"]
    destination_chain_bridge_adapter = setup_protocol["destination_chain_bridge_adapter"]
    cl_emergency_oracle = setup_protocol["cl_emergency_oracle"]
    # Validation
    assert cross_chain_controller_emergency_mode.guardian() == guardian
    assert cross_chain_controller_emergency_mode.owner() == owner
    assert cross_chain_controller_emergency_mode.getChainlinkEmergencyOracle() == cl_emergency_oracle
    adapters = cross_chain_controller_emergency_mode.getReceiverBridgeAdaptersByChain(chain.id)
    assert adapters[0] == bridge_adapter
    bridge_config = cross_chain_controller_emergency_mode.getForwarderBridgeAdaptersByChain(MainnetChainIds.POLYGON)[0]
    assert bridge_config[0] == destination_chain_bridge_adapter  # destinationBridgeAdapter
    assert bridge_config[1] == current_chain_bridge_adapter  # currentChainBridgeAdapter
    assert cross_chain_controller_emergency_mode.isSenderApproved(carol) is True


###########################################
##### Tests for EmergencyConsumer  #######
###########################################

def test_update_cl_emergency_oracle(setup_protocol, owner, alice):
    """
    Testing `updateCLEmergencyOracle()`
    """

    cross_chain_controller_emergency_mode = setup_protocol["cross_chain_controller_emergency_mode"]
    chainlink_emergency_oracle = alice # just for testing
    tx = cross_chain_controller_emergency_mode.updateCLEmergencyOracle(chainlink_emergency_oracle, {"from": owner} )

    # Validation
    assert tx.events["CLEmergencyOracleUpdated"]["chainlinkEmergencyOracle"] == chainlink_emergency_oracle
    assert cross_chain_controller_emergency_mode.getChainlinkEmergencyOracle() == chainlink_emergency_oracle


def test_update_cl_emergency_oracle_not_owner(setup_protocol, alice):
    """
    Testing `updateCLEmergencyOracle()`, caller not the owner
    """

    cross_chain_controller_emergency_mode = setup_protocol["cross_chain_controller_emergency_mode"]
    chainlink_emergency_oracle = alice # just for testing

    with reverts("Ownable: caller is not the owner"):
        cross_chain_controller_emergency_mode.updateCLEmergencyOracle(chainlink_emergency_oracle, {"from": alice} )


def test_update_cl_emergency_oracle_zero_address(setup_protocol, owner, constants):
    """
    Testing `updateCLEmergencyOracle()` when the oracle = address(0)
    """

    cross_chain_controller_emergency_mode = setup_protocol["cross_chain_controller_emergency_mode"]
    chainlink_emergency_oracle = constants.ZERO_ADDRESS
    with reverts("28"): #INVALID_EMERGENCY_ORACLE
        cross_chain_controller_emergency_mode.updateCLEmergencyOracle(chainlink_emergency_oracle, {"from": owner} )



############################################################
#### Tests for CrossChainControllerWithEmergencyMode  ######
############################################################

def test_solve_emergency(setup_protocol, guardian, alice, carol, MainnetChainIds, bridge_adapter, Empty):
    """
    Testing `solveEmergency()`
    """

    cross_chain_controller_emergency_mode = setup_protocol["cross_chain_controller_emergency_mode"]
    cl_emergency_oracle = setup_protocol["cl_emergency_oracle"]
    current_chain_bridge_adapter = setup_protocol["current_chain_bridge_adapter"]

    # newConformations
    required_confirmation = 2
    chain_id = MainnetChainIds.POLYGON
    new_confirmation_1 = [chain_id, required_confirmation]

    required_confirmation = 1
    chain_id = MainnetChainIds.AVALANCHE
    new_confirmation_2 = [chain_id, required_confirmation]

    new_confirmations = [new_confirmation_1, new_confirmation_2]

    # ValidityTimestampInput
    chain_id = MainnetChainIds.POLYGON
    validity_timestamp = 1689000000
    validity_timestamp_input = [[chain_id, validity_timestamp]]

    # receiverBridgeAdaptersToDisallow

    receiver_adapter_to_disallow = [[bridge_adapter.address, [chain.id]]]

    # receiverBridgeAdaptersToAllow
    receiver_adapter_to_allow_1 = [alice.address, [MainnetChainIds.POLYGON, MainnetChainIds.AVALANCHE]]

    receiver_adapter_to_allow_2 = [carol.address, [MainnetChainIds.POLYGON]]

    receiver_adapter_to_allow = [receiver_adapter_to_allow_1, receiver_adapter_to_allow_2]

    #sendersToRemove
    senders_to_remove = []

    #senderToApprove
    senders_to_approve = [alice.address]

    #forwarderBridgeAdaptersToDisable
    bridge_adapter_to_disable = [[current_chain_bridge_adapter.address, [MainnetChainIds.POLYGON]]]

    #forwarderBridgeAdaptersToEnable
    current_chain_bridge_adapter = Empty.deploy({"from": carol})
    destination_chain_bridge_adapter = Empty.deploy({"from": carol})

    bridge_adapter_to_enable = [[current_chain_bridge_adapter, destination_chain_bridge_adapter, MainnetChainIds.AVALANCHE]]

    # set answer a value != 0 so that the modifier `onlyInEmergency` do not revert
    answer = 1
    cl_emergency_oracle.setAnswer(answer, {"from": alice})


    # call solveEmergency()
    tx = cross_chain_controller_emergency_mode.solveEmergency(
        new_confirmations,
        validity_timestamp_input,
        receiver_adapter_to_allow,
        receiver_adapter_to_disallow,
        senders_to_approve,
        senders_to_remove,
        bridge_adapter_to_enable,
        bridge_adapter_to_disable,
        {"from": guardian}
    )

    assert "ReceiverBridgeAdaptersUpdated" in tx.events
    assert "NewInvalidation" in tx.events
    assert "ConfirmationsUpdated" in tx.events
    assert "SenderUpdated" in tx.events
    assert tx.events["EmergencySolved"]["emergencyCount"] == answer
    assert cross_chain_controller_emergency_mode.getEmergencyCount() == answer


def test_solve_emergency_not_in_emergency(setup_protocol, guardian, alice, carol, MainnetChainIds, bridge_adapter, Empty):
    """
    Testing `solveEmergency()`, when the answer from CL Emergency Oracle is 0
    """

    cross_chain_controller_emergency_mode = setup_protocol["cross_chain_controller_emergency_mode"]
    current_chain_bridge_adapter = setup_protocol["current_chain_bridge_adapter"]

    # newConformations
    required_confirmation = 2
    chain_id = MainnetChainIds.POLYGON
    new_confirmation_1 = [chain_id, required_confirmation]

    required_confirmation = 1
    chain_id = MainnetChainIds.AVALANCHE
    new_confirmation_2 = [chain_id, required_confirmation]

    new_confirmations = [new_confirmation_1, new_confirmation_2]

    # ValidityTimestampInput
    chain_id = MainnetChainIds.POLYGON
    validity_timestamp = 1689000000
    validity_timestamp_input = [[chain_id, validity_timestamp]]

    # receiverBridgeAdaptersToDisallow

    receiver_adapter_to_disallow = [[bridge_adapter.address, [chain.id]]]

    # receiverBridgeAdaptersToAllow
    receiver_adapter_to_allow_1 = [alice.address, [MainnetChainIds.POLYGON, MainnetChainIds.AVALANCHE]]

    receiver_adapter_to_allow_2 = [carol.address, [MainnetChainIds.POLYGON]]

    receiver_adapter_to_allow = [receiver_adapter_to_allow_1, receiver_adapter_to_allow_2]

    #sendersToRemove
    senders_to_remove = []

    #senderToApprove
    senders_to_approve = [alice.address]

    #forwarderBridgeAdaptersToDisable
    bridge_adapter_to_disable = [[current_chain_bridge_adapter.address, [MainnetChainIds.POLYGON]]]

    #forwarderBridgeAdaptersToEnable
    current_chain_bridge_adapter = Empty.deploy({"from": carol})
    destination_chain_bridge_adapter = Empty.deploy({"from": carol})

    bridge_adapter_to_enable = [[current_chain_bridge_adapter, destination_chain_bridge_adapter, MainnetChainIds.AVALANCHE]]


    with reverts("29"): #NOT_IN_EMERGENCY

        # call solveEmergency()
        tx = cross_chain_controller_emergency_mode.solveEmergency(
            new_confirmations,
            validity_timestamp_input,
            receiver_adapter_to_allow,
            receiver_adapter_to_disallow,
            senders_to_approve,
            senders_to_remove,
            bridge_adapter_to_enable,
            bridge_adapter_to_disable,
            {"from": guardian}
        )


def test_emergency_token_transfer(setup_protocol, owner, deploy_usdt, alice):
    """
    Testing emergencyTokenTransfer()
    """

    cross_chain_controller = setup_protocol["cross_chain_controller"]
    usdt = deploy_usdt

    amount_1 = 1000 * 10**6
    usdt.transfer(cross_chain_controller, amount_1, {"from": owner})

    amount_2 = 800 * 10**6
    tx =  cross_chain_controller.emergencyTokenTransfer(usdt, alice, amount_2, {"from": owner} )

    # Validation
    assert usdt.balanceOf(cross_chain_controller) == amount_1 - amount_2
    assert usdt.balanceOf(alice) == amount_2
    assert tx.events["ERC20Rescued"]["caller"] == owner
    assert tx.events["ERC20Rescued"]["token"] == usdt.address
    assert tx.events["ERC20Rescued"]["to"] == alice



def test_emergency_ether_transfer(setup_protocol, owner, deploy_usdt, alice):
    """
    Testing emergencyEtherTransfer()
    """

    cross_chain_controller = setup_protocol["cross_chain_controller"]
    usdt = deploy_usdt

    amount_1 = 5 * 10**18
    owner.transfer(cross_chain_controller, amount_1)

    amount_2 = 3 * 10**18
    tx =  cross_chain_controller.emergencyEtherTransfer(alice, amount_2, {"from": owner} )

    # Validation
    assert cross_chain_controller.balance() == amount_1 - amount_2
    assert tx.events["NativeTokensRescued"]["caller"] == owner
    assert tx.events["NativeTokensRescued"]["to"] == alice
    assert tx.events["NativeTokensRescued"]["amount"] == amount_2





