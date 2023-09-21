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

def test_set_emergency(setup_protocol, owner, MainnetChainIds):
    """
    Testing `setEmergency()`
    """

    emergency_registry = setup_protocol["emergency_registry"]

    emergency_chains = [chain.id, MainnetChainIds.POLYGON]
    tx = emergency_registry.setEmergency(emergency_chains, {"from": owner})

    # Validation

    for i,emergency_chain in enumerate(emergency_chains):
        assert tx.events["NetworkEmergencyStateUpdated"][i]["chainId"] == emergency_chain
        assert tx.events["NetworkEmergencyStateUpdated"][i]["emergencyNumber"] == 1

    assert emergency_registry.getNetworkEmergencyCount(chain.id) == 1
    assert emergency_registry.getNetworkEmergencyCount(MainnetChainIds.POLYGON) == 1


def test_set_emergency_same_chain(setup_protocol, owner, MainnetChainIds):
    """
    Testing `setEmergency()` for the same chain
    """

    emergency_registry = setup_protocol["emergency_registry"]

    emergency_chains = [chain.id, MainnetChainIds.POLYGON, chain.id]


    with reverts("15"): #ONLY_ONE_EMERGENCY_UPDATE_PER_CHAIN
        emergency_registry.setEmergency(emergency_chains, {"from": owner})


def test_set_emergency_wrong_caller(setup_protocol, alice, MainnetChainIds):
    """
    Testing `setEmergency()` when the caller not the owner
    """

    emergency_registry = setup_protocol["emergency_registry"]

    emergency_chains = [chain.id, MainnetChainIds.POLYGON]


    with reverts("Ownable: caller is not the owner"):
        emergency_registry.setEmergency(emergency_chains, {"from": alice})




