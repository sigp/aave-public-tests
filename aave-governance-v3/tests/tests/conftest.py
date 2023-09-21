import json
import os
import types
from typing import Dict, Tuple
import time

import brownie
import pytest
from brownie import web3, chain
from brownie import Contract
from eth_abi import encode_single, encode_abi
from eth_abi.packed import encode_abi_packed, encode_single_packed

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
        ZERO_VALUE="0x0000000000000000000000000000000000000000000000000000000000000000",
        STABLE_SUPPLY=1_000_000 * 10**6,
        MAX_UINT256=2**256 - 1,
        COOLDOWN_PERIOD=60 * 60 * 24,  # 1 day
        EXECUTION_GAS_LIMIT=0,
        VOTING_MACHINE_CHAIN_ID=137,
        DATA_BLOCK_HASH="0x20619c36e5b5a0fde0e676468c96a0c9534e685f743969b84f6c2b1920887601",
        DATA_VOTER="0xAd9A211D227d2D9c1B5573f73CDa0284b758Ac0C",
        EXPIRATION_DELAY= 60 * 60 * 24 * 35, # 35 days
        GRACE_PERIOD =  60 * 60 * 24 * 7, # 7 days
        proposalState={
            "Null": 0,
            "Created": 1,
            "Active": 2,
            "Queued": 3,
            "Executed": 4,
            "Failed": 5,
            "Cancelled": 6,
            "Expired": 7,
        },
        AAVE="0x64033B2270fd9D6bbFc35736d2aC812942cE75fE",
        STK_AAVE="0xA4FDAbdE9eF3045F0dcF9221bab436B784B7e42D",
        A_AAVE="0x7d9EB767eEc260d1bCe8C518276a894aE5535F04",
        VOTING_MACHINE_SALT=web3.keccak(text="Voting Machine"),
        VOTING_PORTAL_SALT=web3.keccak(text="Voting Portal")
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
    """Account used as the default owner/guardian."""
    return accounts[0]


@pytest.fixture(scope="module")
def proxy_admin_eoa(accounts):
    """
    Account used as the admin to proxies.
    Use this account to deploy proxies as it allows the default account (i.e. accounts[0])
    to call contracts without setting the `from` field.
    NOTE: We also have a proxy admin contract that is used to upgrade the proxies.
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
def dartagnan(accounts):
    # Add the account so we have the private key
    accounts.add()
    return accounts[-1]


@pytest.fixture(scope="module")
def lost_and_found_addr(accounts):
    """Account used as Lost and Found Address for USDC V2."""
    return accounts[5]


@pytest.fixture(scope="session")
def wethdonor(accounts):
    return accounts[6]


@pytest.fixture(scope="session")
def guardian(accounts):
    """
    AAVE Guardian account.
    """
    return accounts[7]


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
def deploy_usdc(owner, proxy_admin_eoa, lost_and_found_addr, constants):
    """
    Deploy USD Coin stablecoin.
    """

    folder_name = "usdc"

    # FiatTokenV1
    file_name = folder_name + "/" + "FiatTokenV1.json"
    # constructor arguments
    args = []
    # deployment
    fiat_token_v1 = build_deployer(file_name, proxy_admin_eoa, *args)

    # FiatTokenV1_1
    # Not really used
    # file_name = folder_name + "/" + "FiatTokenV1_1.json"
    # # constructor arguments
    # args = []
    # # deployment
    # fiat_token_v1_1 = build_deployer(file_name, proxy_admin_eoa, *args)

    # FiatTokenV2
    file_name = folder_name + "/" + "FiatTokenV2.json"
    # constructor arguments
    args = []
    # deployment
    fiat_token_v2 = build_deployer(file_name, proxy_admin_eoa, *args)

    # FiatTokenV2_1
    file_name = folder_name + "/" + "FiatTokenV2_1.json"
    # constructor arguments
    args = []
    # deployment
    fiat_token_v2_1 = build_deployer(file_name, proxy_admin_eoa, *args)

    # FiatTokenProxy
    file_name = folder_name + "/" + "FiatTokenProxy.json"
    # constructor arguments
    args = [fiat_token_v1.address]
    # deployment
    proxy = build_deployer(file_name, proxy_admin_eoa, *args)

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
    proxy.upgradeToAndCall(fiat_token_v1.address, data, {"from": proxy_admin_eoa})

    # implementation V2
    new_name = "USD Coin"
    params = [new_name]
    data = fiat_token_v2.initializeV2.encode_input(*params)

    # upgradeToAndCall to FiatTokenV2
    proxy.upgradeToAndCall(fiat_token_v2.address, data, {"from": proxy_admin_eoa})

    # implementation V2_1
    lost_and_found = lost_and_found_addr
    params = [lost_and_found]
    data = fiat_token_v2_1.initializeV2_1.encode_input(*params)

    # upgradeToAndCall to FiatTokenV2_1
    proxy.upgradeToAndCall(fiat_token_v2_1.address, data, {"from": proxy_admin_eoa})

    proxy_as_implementation = brownie.network.contract.Contract.from_abi(
        "proxy contract", proxy.address, fiat_token_v2_1.abi
    )

    # configure owner as minter
    usdc = proxy_as_implementation
    usdc.configureMinter(owner, constants.STABLE_SUPPLY, {"from": owner})

    return usdc


@pytest.fixture(scope="module")
def contracts(
    owner,
    constants,
    wethdonor,
    deploy_weth,
    deploy_usdt,
    deploy_usdc,
    Empty,
    MockCrossChainController,
):
    """
    Deploy some basic contracts.
    """

    # Tokens
    usdt = deploy_usdt
    usdc = deploy_usdc
    usdc.mint(owner, constants.STABLE_SUPPLY, {"from": owner})
    weth = deploy_weth
    weth.deposit({"from": wethdonor, "value": wethdonor.balance()})

    # Some of the AAVE addresses used in deployment and as transaction sources
    message_originator = Empty.deploy({"from": owner})
    cross_chain_controller = MockCrossChainController.deploy({"from": owner})
    power_strategy = Empty.deploy({"from": owner})

    contracts = {
        "usdc": usdc,
        "usdt": usdt,
        "weth": weth,
        "message_originator": message_originator,
        "cross_chain_controller": cross_chain_controller,
        "power_strategy": power_strategy,
    }

    return contracts


@pytest.fixture(scope="module")
def voting_tokens(ERC20Mock, owner):
    """
    Deploy some standard ERC20 tokens as voting tokens
    """

    token_a = ERC20Mock.deploy("TokenA", "TokenA", {"from": owner})
    token_b = ERC20Mock.deploy("TokenB", "TokenB", {"from": owner})
    token_c = ERC20Mock.deploy("TokenC", "TokenC", {"from": owner})

    voting_tokens = {"TokenA": token_a, "TokenB": token_b, "TokenC": token_c}

    return voting_tokens


@pytest.fixture(scope="session")
def voting_config_level1():
    access_level = 1  #  LEVEL_1
    voting_duration = 60 * 60 * 24 * 7  # 7 days
    cooldown_before_voting_start = 60 * 60 * 24  # 1 days
    yes_threshold = 320_000 * 10**18  # yesThreshold (320000 ether)
    yes_no_differential = 100_000 * 10**18  # yesNoDifferential (100000 ether)
    min_proposition_power = 50_000 * 10**18

    voting_config = [
        access_level,
        cooldown_before_voting_start,
        voting_duration,
        yes_threshold,
        yes_no_differential,
        min_proposition_power,
    ]

    voting_config_level_1 = {
        "access_level": access_level,
        "voting_duration": voting_duration,
        "cooldown_before_voting_start": cooldown_before_voting_start,
        "yes_threshold": yes_threshold,
        "yes_no_differential": yes_no_differential,
        "min_proposition_power": min_proposition_power,
        "voting_config": voting_config,
    }

    return voting_config_level_1

@pytest.fixture(scope="session")
def voting_config_level2():
    access_level = 2  #  LEVEL_2
    voting_duration = 60 * 60 * 24 * 10  # 10 days
    cooldown_before_voting_start = 60 * 60 * 24  # 2 days
    yes_threshold = 350_000 * 10**18  # yesThreshold (350000 ether)
    yes_no_differential = 120_000 * 10**18  # yesNoDifferential (1200000 ether)
    min_proposition_power = 80_000 * 10**18

    voting_config = [
        access_level,
        cooldown_before_voting_start,
        voting_duration,
        yes_threshold,
        yes_no_differential,
        min_proposition_power,
    ]

    voting_config_level_2 = {
        "access_level": access_level,
        "voting_duration": voting_duration,
        "cooldown_before_voting_start": cooldown_before_voting_start,
        "yes_threshold": yes_threshold,
        "yes_no_differential": yes_no_differential,
        "min_proposition_power": min_proposition_power,
        "voting_config": voting_config,
    }

    return voting_config_level_2

@pytest.fixture(scope="session")
def proofs():
    f = open('data/proofs.json')
    data = json.load(f)
    return data


@pytest.fixture(scope="module")
def setup_protocol(
    owner,
    guardian,
    contracts,
    constants,
    voting_config_level1,
    voting_config_level2,
    TransparentProxyFactory,
    TransparentUpgradeableProxy,
    Executor,
    ProxyAdmin,
    PayloadsController,
    Governance,
    MockPowerStrategy,
    VotingPortal,
    DataWarehouse,
    SlotUtils,
    VotingStrategy,
    VotingMachine,
    GovernancePowerStrategy,
    #GovernancePowerStrategyMock,
    GovernancePowerDelegationTokenMock,
    Create2Deployer,
    Create3Factory,
):
    """
    Deploying contracts and setting up the protocol
    """
    cross_chain_controller = contracts["cross_chain_controller"]

    
    create3_factory = Create3Factory.deploy({"from": owner})

    # Deploy 2 executors
    executor1 = Executor.deploy({"from": owner})
    executor2 = Executor.deploy({"from": owner})

    # Using the factory pattern
    proxy_factory = TransparentProxyFactory.deploy({"from": owner})
    # Get our admin contract
    tx = proxy_factory.createProxyAdmin(owner, {"from": owner})
    proxy_admin = ProxyAdmin.at(tx.events["ProxyAdminCreated"]["proxyAdmin"])

    # Deploy the payload controller
    # This logic contract has a constructor, but all its values are immutable,
    # so will be compiled into bytecode, so will work with the proxy pattern
    message_originator = contracts["message_originator"]
    cross_chain_controller = contracts["cross_chain_controller"]
    payload_controller_logic = PayloadsController.deploy(
        cross_chain_controller, message_originator, 1, {"from": owner}
    )

    # encode a call to the initialize function
    data = payload_controller_logic.initialize.encode_input(
        owner,  # owner
        guardian,  # guardian
        # array of code/aave-governance-v3/src/contracts/payloads/interfaces/IPayloadsControllerCore.sol UpdateExecutorInput struct:
        [
            [
                1,  # 0 do not use
                # 1 short executor before, listing assets, changes of assets params, updates of the protocol etc
                # 2 long executor before, payloads controller updates
                [
                    executor1,  # executor
                    86_400,  # delay time in seconds between queuing and execution
                ],
            ],
            [
                2,  # 0 do not use
                # 1 short executor before, listing assets, changes of assets params, updates of the protocol etc
                # 2 long executor before, payloads controller updates
                [
                    executor2,  # executor
                    864_000,  # delay time in seconds between queuing and execution
                ],
            ],
        ],
    )

    tx = proxy_factory.create(payload_controller_logic, proxy_admin, data, {"from": owner})
    payload_controller_proxy = PayloadsController.at(tx.events["ProxyCreated"]["proxy"])

    # Transfer ownership of the executors to the payload controller
    executor1.transferOwnership(payload_controller_proxy, {"from": owner})
    executor2.transferOwnership(payload_controller_proxy, {"from": owner})
    # Deploy the Governance contract

    # Governance logic

    governance_logic = Governance.deploy(
        cross_chain_controller,
        constants.COOLDOWN_PERIOD,
        {"from": owner},
    )
    # votingConfig
    voting_config_1 = voting_config_level1["voting_config"]
    voting_config_2 = voting_config_level2["voting_config"]

    # Deploy MockPowerStrategy
    power_strategy_mock = MockPowerStrategy.deploy({"from": owner})

    # predicted address of VotingPortal
    voting_portal_address = create3_factory.predictAddress(owner, constants.VOTING_PORTAL_SALT.hex())
    # predicted address of VotingMachine
    voting_machine_address = create3_factory.predictAddress(owner, constants.VOTING_MACHINE_SALT.hex())

    # VotingMachine
    slot_utils = SlotUtils.deploy({"from": owner})
    data_warehouse = DataWarehouse.deploy({"from": owner})
    voting_strategy = VotingStrategy.deploy(data_warehouse, {"from": owner})
    
    # Deploy VotingMachine Using create3
    code = VotingMachine.bytecode
    # init code in bytes
    b_code = bytes.fromhex(code) 

    consturctor_argument_encoded = encode_abi(["address", "uint256", "uint256", "address", "address"], 
                                              [cross_chain_controller.address, 
                                               constants.EXECUTION_GAS_LIMIT, 
                                               chain.id, 
                                               voting_strategy.address, 
                                               voting_portal_address])
 

    init_code = encode_abi_packed(
        ["bytes", "bytes"],
        [b_code, consturctor_argument_encoded],
    )

    tx = create3_factory.create(constants.VOTING_MACHINE_SALT, init_code , {"from": owner})
    voting_machine = VotingMachine.at(voting_machine_address)
    assert voting_machine.CROSS_CHAIN_CONTROLLER() == cross_chain_controller

    # initialize Governance
    # encode a call to the initialize function
    data = governance_logic.initialize.encode_input(
        owner, guardian, power_strategy_mock, [voting_config_1, voting_config_2], [voting_portal_address], 0
    )
    tx = proxy_factory.create(governance_logic, proxy_admin, data, {"from": owner})
    governance_proxy_address = tx.events["ProxyCreated"]["proxy"]
    governance_proxy = Governance.at(governance_proxy_address)

    # Deploy VotingPortal Using create3
    code = VotingPortal.bytecode
    # init code in bytes
    b_code = bytes.fromhex(code) 

    consturctor_argument_encoded = encode_abi(["address", "address", "address", "uint256", "uint128", "uint128", "address"], 
                                              [cross_chain_controller.address, 
                                               governance_proxy_address, 
                                               voting_machine_address, 
                                               constants.VOTING_MACHINE_CHAIN_ID, 
                                               0, #startVotingGasLimit
                                               0, #voteViaPortalGasLimit
                                               owner.address])
 

    init_code = encode_abi_packed(
        ["bytes", "bytes"],
        [b_code, consturctor_argument_encoded],
    )

    tx = create3_factory.create(constants.VOTING_PORTAL_SALT, init_code , {"from": owner})
    

    voting_portal = VotingPortal.at(voting_portal_address)

    assert voting_portal.CROSS_CHAIN_CONTROLLER() == cross_chain_controller

    # Here is the information on the storage roots
    
    f = open('data/proofs.json')
    data = json.load(f)
    storage_data_json = [
        [
            voting_strategy.AAVE(),
            data["AAVE"]["blockHeaderRLP"],
            data["AAVE"]["accountStateProofRLP"],
        ],
        [
            voting_strategy.STK_AAVE(),
            data["STK_AAVE"]["blockHeaderRLP"],
            data["STK_AAVE"]["accountStateProofRLP"],
        ],
        [
            voting_strategy.A_AAVE(),
            data["A_AAVE"]["blockHeaderRLP"],
            data["A_AAVE"]["accountStateProofRLP"]
        ],
    ]
    
    # Add each storage root to the data warehouse
   
    data_warehouse.processStorageRoot(
        data["AAVE"]["token"],
        data["blockHash"],
        data["AAVE"]["blockHeaderRLP"],
        data["AAVE"]["accountStateProofRLP"],
        {"from": owner},
    )

    data_warehouse.processStorageRoot(
        data["STK_AAVE"]["token"],
        data["blockHash"],
        data["STK_AAVE"]["blockHeaderRLP"],
        data["STK_AAVE"]["accountStateProofRLP"],
        {"from": owner},
    )

    data_warehouse.processStorageRoot(
        data["A_AAVE"]["token"],
        data["blockHash"],
        data["A_AAVE"]["blockHeaderRLP"],
        data["A_AAVE"]["accountStateProofRLP"],
        {"from": owner},
    )

    # Add the storage slot data for the STK_AAVE token
    tx = data_warehouse.processStorageSlot(
        data["STK_AAVE"]["token"],
        data["blockHash"],
        data["STK_AAVE"]["stkAaveExchangeRateSlot"],
        data["STK_AAVE"]["stkAaveExchangeRateStorageProofRlp"],
        {"from": owner},
    )
    
    # Deploy `GovernancePowerStrategy`
    governance_power_strategy = GovernancePowerStrategy.deploy({"from": owner})

    # Deploy `GovernancePowerDelegationTokenMock`
    delegation_token_a = GovernancePowerDelegationTokenMock.deploy(1337, 1234, {"from": owner})
    delegation_token_b = GovernancePowerDelegationTokenMock.deploy(5555, 2222, {"from": owner})

    # Deploy `GovernancePowerStrategyMock`
    #governance_power_strategy_mock = GovernancePowerStrategyMock.deploy(
    #    delegation_token_a.address, delegation_token_b.address, {"from": owner}
    #)

    contracts.update(
        {
            "slot_utils": slot_utils,
            "data_warehouse": data_warehouse,
            "voting_strategy": voting_strategy,
            "executor1": executor1,
            "executor2": executor2,
            "proxy_admin": proxy_admin,
            "payload_controller": payload_controller_proxy,
            "payload_controller_logic": payload_controller_logic,
            "governance": governance_proxy,
            "governance_logic": governance_logic,
            "power_strategy_mock": power_strategy_mock,
            "voting_portal": voting_portal,
            "voting_machine": voting_machine,
            "governance_power_strategy": governance_power_strategy,
            #"governance_power_strategy_mock": governance_power_strategy_mock,
            "delegation_token_a": delegation_token_a,
            "delegation_token_b": delegation_token_b,
        }
    )

    return contracts

