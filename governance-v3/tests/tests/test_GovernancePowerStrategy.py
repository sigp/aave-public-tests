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


def test_constants_variable(setup_protocol, constants):
    """
    checking the values of the constants variables
    """
    #Setup
    governance_power_strategy = setup_protocol["governance_power_strategy"]

    assert governance_power_strategy.AAVE() == constants.AAVE
    assert governance_power_strategy.STK_AAVE() == constants.STK_AAVE
    assert governance_power_strategy.A_AAVE() == constants.A_AAVE


def test_get_voting_asset_list(setup_protocol, constants):
    """
    Testing `getVotingAssetList()`
    """
    # Setup
    governance_power_strategy = setup_protocol["governance_power_strategy"]
    # call `getVotingAssetList()`
    voting_assets = governance_power_strategy.getVotingAssetList()

    assert voting_assets[0] == constants.AAVE
    assert voting_assets[1] == constants.STK_AAVE
    assert voting_assets[2] == constants.A_AAVE



def test_get_voting_asset_config(setup_protocol, constants):
    """
    Testing `getVotingAssetConfig()`
    """
    # Setup
    governance_power_strategy = setup_protocol["governance_power_strategy"]
    # call `getVotingAssetConfig()`
    voting_asset_config = governance_power_strategy.getVotingAssetConfig(constants.AAVE)
    assert voting_asset_config["storageSlots"][0] == 0
    # call `getVotingAssetConfig()`
    voting_asset_config = governance_power_strategy.getVotingAssetConfig(constants.A_AAVE)
    assert voting_asset_config["storageSlots"][0] == 52
    assert voting_asset_config["storageSlots"][1] == 64
    # call `getVotingAssetConfig()`
    voting_asset_config = governance_power_strategy.getVotingAssetConfig(constants.STK_AAVE)
    assert voting_asset_config["storageSlots"][0] == 0
