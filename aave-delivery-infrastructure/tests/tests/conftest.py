import json
import os
import types
from typing import Dict, Tuple

import brownie
import pytest
from brownie import (chain, web3)

# To setup before the function-level snapshot,
# put a module-level autouse fixture like the following in your test module.
#
# @pytest.fixture(scope="module", autouse=True)
# def initial_state(base_setup):
#     """This relies on base_setup, so ensure it's loaded
#     before any function-level isolation."""
#     # Put any other module-specific setup you'd like in here
#     pass


# NOTE: if wanting to adjust things slightly, you can also override some
# individual fixture (within some scope).

# TODO enable?
# Could enable it, but the brownie middleware could still do its own conversions,
# so can't really rely on it
# w3.enable_strict_bytes_type_checking()


# Type aliases
# includes ProjectContract and Contract instances
CONTRACT_INSTANCE = brownie.network.contract._DeployedContractBase
NAME_WITH_INSTANCE = Tuple[str, CONTRACT_INSTANCE]
NAME_TO_INSTANCE = Dict[str, CONTRACT_INSTANCE]


@pytest.fixture(scope="module", autouse=True)
def mod_isolation(module_isolation):
    """Snapshot ganache at start of module."""
    pass


@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    """Snapshot ganache before every test function call."""
    pass


@pytest.fixture(scope="session")
def constants():
    """Parameters used in the default setup/deployment, useful constants."""
    return types.SimpleNamespace(
        ZERO_ADDRESS=brownie.ZERO_ADDRESS,
        STABLE_SUPPLY=1_000_000 * 10**6,
        MAX_UINT256=2**256 - 1,
        EnvelopeState={
            "None": 0,
            "Confirmed": 1,
            "Delivered": 2,
        }
    )


@pytest.fixture(scope="session")
def MainnetChainIds():
    """Mainnet chain IDs."""
    return types.SimpleNamespace(
        ETHEREUM=1,
        POLYGON=137,
        AVALANCHE=43114,
        ARBITRUM=42161,
        OPTIMISM=10,
        FANTOM=250,
        HARMONY=1666600000,
        METIS=1088,
        BNB=56,
        BASE=8453,
    )


# Pytest Adjustments
####################

# Copied from
# https://docs.pytest.org/en/latest/example/simple.html?highlight=skip#control-skipping-of-tests-according-to-command-line-option


def pytest_addoption(parser):
    parser.addoption("--runslow", action="store_true", default=False, help="run slow tests")


def pytest_configure(config):
    config.addinivalue_line("markers", "slow: mark test as slow to run")


def pytest_collection_modifyitems(config, items):
    if config.getoption("--runslow"):
        # --runslow given in cli: do not skip slow tests
        return
    skip_slow = pytest.mark.skip(reason="need --runslow option to run")
    for item in items:
        if "slow" in item.keywords:
            item.add_marker(skip_slow)


## Account Fixtures
###################


@pytest.fixture(scope="module")
def owner(accounts):
    """Account used as the default owner."""
    return accounts[0]


@pytest.fixture(scope="module")
def proxy_admin(accounts):
    """
    Account used as the admin to proxies.
    Use this account to deploy proxies as it allows the default account (i.e. accounts[0])
    to call contracts without setting the `from` field.
    """
    return accounts[1]


@pytest.fixture(scope="module")
def alice(accounts):
    return accounts[2]


@pytest.fixture(scope="module")
def bob(accounts):
    return accounts[3]


@pytest.fixture(scope="module")
def carol(accounts):
    return accounts[4]


@pytest.fixture(scope="module")
def lost_and_found_addr(accounts):
    """Account used as Lost and Found Address for USDC V2."""
    return accounts[5]

@pytest.fixture(scope="module")
def guardian(accounts):
    """
    AAVE Guardian account.
    """
    return accounts[6]

@pytest.fixture(scope="module")
def bridge_adapter(accounts):
    """
    AAVE Bridge Adapter
    """
    return accounts[8]

## Deploy Compiled Contracts

# Deployer routine to build from a compiled contract
def build_deployer(file_name, deployer, *args):
    """
    Deploy from compiled contract which should be in JSON.
    The contract should be stored locally inside "compiled" folder.
    If folder name change is required, modify the folder_path variable.
    """

    dir_path = os.path.dirname(os.path.realpath(__file__))
    folder_path = dir_path + "/../compiled"
    json_path = folder_path + "/" + file_name

    with open(json_path) as f:
        data = json.load(f)

    abi = data["abi"]
    bytecode = data["bytecode"]

    web3.eth.default_account = deployer
    contract = web3.eth.contract(abi=abi, bytecode=bytecode)
    tx_hash = contract.constructor(*args).transact({"from": str(deployer)})
    tx_receipt = web3.eth.wait_for_transaction_receipt(tx_hash)
    contract_instance = brownie.network.contract.Contract.from_abi(
        "contract", tx_receipt.contractAddress, abi
    )
    return contract_instance


@pytest.fixture(scope="module")
def deploy_weth(owner):
    """
    Deploy Wrapped Ether (WETH) using WETH9 contract.
    """

    folder_name = "weth"
    # deploy WETH
    weth_file = folder_name + "/" + "WETH9.json"
    # constructor arguments
    args = []
    # deployment
    weth = build_deployer(weth_file, owner, *args)

    return weth


@pytest.fixture(scope="module")
def deploy_usdt(owner, constants):
    """
    Deploy Tether (USDT) stablecoin.
    Initial supply is transferred to owner.
    """

    folder_name = "tether"
    # TetherToken
    file_name = folder_name + "/" + "TetherToken.json"
    # constructor arguments
    name = "Tether USD"
    symbol = "USDT"
    initial_supply = constants.STABLE_SUPPLY
    decimals = 6
    args = [initial_supply, name, symbol, decimals]
    # deployment
    usdt = build_deployer(file_name, owner, *args)

    return usdt


@pytest.fixture(scope="module")
def deploy_usdc(owner, proxy_admin, lost_and_found_addr, constants):
    """
    Deploy USD Coin stablecoin.
    """

    folder_name = "usdc"

    # FiatTokenV1
    file_name = folder_name + "/" + "FiatTokenV1.json"
    # constructor arguments
    args = []
    # deployment
    fiat_token_v1 = build_deployer(file_name, proxy_admin, *args)

    # FiatTokenV1_1
    # Not really used
    # file_name = folder_name + "/" + "FiatTokenV1_1.json"
    # # constructor arguments
    # args = []
    # # deployment
    # fiat_token_v1_1 = build_deployer(file_name, proxy_admin, *args)

    # FiatTokenV2
    file_name = folder_name + "/" + "FiatTokenV2.json"
    # constructor arguments
    args = []
    # deployment
    fiat_token_v2 = build_deployer(file_name, proxy_admin, *args)

    # FiatTokenV2_1
    file_name = folder_name + "/" + "FiatTokenV2_1.json"
    # constructor arguments
    args = []
    # deployment
    fiat_token_v2_1 = build_deployer(file_name, proxy_admin, *args)

    # FiatTokenProxy
    file_name = folder_name + "/" + "FiatTokenProxy.json"
    # constructor arguments
    args = [fiat_token_v1.address]
    # deployment
    proxy = build_deployer(file_name, proxy_admin, *args)

    # implementation V1
    token_name = "USD Coin"
    token_symbol = "USDC"
    token_currency = "USD"
    token_decimals = 6
    new_master_minter = owner
    new_pauser = owner
    new_black_lister = owner
    new_owner = owner
    params = [
        token_name,
        token_symbol,
        token_currency,
        token_decimals,
        new_master_minter,
        new_pauser,
        new_black_lister,
        new_owner,
    ]
    data = fiat_token_v1.initialize.encode_input(*params)

    # upgradeToAndCall to FiatTokenV1
    proxy.upgradeToAndCall(fiat_token_v1.address, data, {"from": proxy_admin})

    # implementation V2
    new_name = "USD Coin"
    params = [new_name]
    data = fiat_token_v2.initializeV2.encode_input(*params)

    # upgradeToAndCall to FiatTokenV2
    proxy.upgradeToAndCall(fiat_token_v2.address, data, {"from": proxy_admin})

    # implementation V2_1
    lost_and_found = lost_and_found_addr
    params = [lost_and_found]
    data = fiat_token_v2_1.initializeV2_1.encode_input(*params)

    # upgradeToAndCall to FiatTokenV2_1
    proxy.upgradeToAndCall(fiat_token_v2_1.address, data, {"from": proxy_admin})

    proxy_as_implementation = brownie.network.contract.Contract.from_abi(
        "proxy contract", proxy.address, fiat_token_v2_1.abi
    )

    # configure owner as minter
    usdc = proxy_as_implementation
    usdc.configureMinter(owner, constants.STABLE_SUPPLY, {"from": owner})

    return usdc


@pytest.fixture(scope="module")
def setup_protocol(
    owner,
    guardian,
    carol,
    alice,
    bridge_adapter,
    MainnetChainIds,
    TransparentProxyFactory,
    CLEmergencyOracleMock,
    ProxyAdmin,
    CrossChainController,
    CrossChainControllerWithEmergencyMode,
    EmergencyRegistry,
    SameChainAdapter,
    BaseAdapterMock,
    Empty,
):
    """
    Deploying contracts and setting up the protocol
    """
    # Using the factory pattern
    proxy_factory = TransparentProxyFactory.deploy({"from": owner})
    # Get our admin contract
    tx = proxy_factory.createProxyAdmin(owner, {"from": owner})
    proxy_admin_factory = ProxyAdmin.at(tx.events["ProxyAdminCreated"]["proxyAdmin"])
    #Deploy CLEmergencyOracleMock
    cl_emergency_oracle = CLEmergencyOracleMock.deploy({"from": owner})
    # Deploy CrossChainController
    cross_chain_controller_logic = CrossChainController.deploy({"from": owner})
    # Deploy CrossChainControllerWithEmergencyMode
    cross_chain_controller_emergency_mode_logic = CrossChainControllerWithEmergencyMode.deploy(cl_emergency_oracle, {"from": owner})


    current_chain_bridge_adapter = Empty.deploy({"from": owner})
    destination_chain_bridge_adapter = Empty.deploy({"from": owner})
    # encode a call to the initialize function for CrossChainController
    data = cross_chain_controller_logic.initialize.encode_input(
        owner,
        guardian,
        # ConfirmationInput
        [
            [chain.id,
            1,] #requiredConfirmations
        ],
        # ReceiverBridgeAdapterConfigInput
        [[
            bridge_adapter,
            [chain.id],
        ]],
        # ForwarderBridgeAdapterConfigInput
        [[
            current_chain_bridge_adapter, # currentChainBridgeAdapter
            destination_chain_bridge_adapter, # destinationBridgeAdapter
            MainnetChainIds.POLYGON, # destinationChainId
        ]],

        [carol], # sendersToApprove
    )

    tx = proxy_factory.create(cross_chain_controller_logic, proxy_admin_factory, data, {"from": owner})
    cross_chain_controller_proxy = CrossChainController.at(tx.events["ProxyCreated"]["proxy"])


     # encode a call to the initialize function for CrossChainControllerWithEmergencyMode
    data = cross_chain_controller_emergency_mode_logic.initialize.encode_input(
        owner,
        guardian,
        cl_emergency_oracle,
        # ConfirmationInput
        [
            [chain.id,
            1,] #requiredConfirmations
        ],
        # ReceiverBridgeAdapterConfigInput
        [[
            bridge_adapter,
            [chain.id],
        ]],
        # ForwarderBridgeAdapterConfigInput
        [[
            current_chain_bridge_adapter, # currentChainBridgeAdapter
            destination_chain_bridge_adapter, # destinationBridgeAdapter
            MainnetChainIds.POLYGON, # destinationChainId
        ]],

        [carol], # sendersToApprove
    )

    tx = proxy_factory.create(cross_chain_controller_emergency_mode_logic, proxy_admin_factory, data, {"from": owner})
    cross_chain_controller_emergency_mode_proxy = CrossChainControllerWithEmergencyMode.at(tx.events["ProxyCreated"]["proxy"])

    # Deploy `EmergencyRegistry`
    emergency_registry = EmergencyRegistry.deploy({"from": owner})

    # Deploy `SameChainAdapter`
    same_chain_adapter = SameChainAdapter.deploy({"from": owner})

    # Deploy `BaseAdapterMock`
    origin_configs = [[alice.address, chain.id], [carol.address, MainnetChainIds.POLYGON]]
    base_adapter = BaseAdapterMock.deploy(cross_chain_controller_proxy, origin_configs, {"from": owner})


    contracts = {
       "proxy_admin": proxy_admin_factory,
       "cross_chain_controller_logic": cross_chain_controller_logic,
       "cross_chain_controller": cross_chain_controller_proxy,
       "cross_chain_controller_emergency_mode_logic": cross_chain_controller_emergency_mode_logic,
       "cross_chain_controller_emergency_mode": cross_chain_controller_emergency_mode_proxy,
       "current_chain_bridge_adapter": current_chain_bridge_adapter,
       "destination_chain_bridge_adapter": destination_chain_bridge_adapter,
       "cl_emergency_oracle": cl_emergency_oracle,
       "emergency_registry": emergency_registry,
       "same_chain_adapter": same_chain_adapter,
       "base_adapter": base_adapter,
    }
    return contracts