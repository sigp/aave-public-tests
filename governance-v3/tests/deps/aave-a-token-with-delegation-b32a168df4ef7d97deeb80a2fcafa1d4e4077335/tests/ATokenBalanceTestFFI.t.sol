// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/Vm.sol';
import 'forge-std/StdJson.sol';
import {ATokenWithDelegation} from '../src/contracts/ATokenWithDelegation.sol';
import {IGovernancePowerDelegationToken} from 'aave-token-v3/interfaces/IGovernancePowerDelegationToken.sol';
import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {BaseAdminUpgradeabilityProxy} from 'aave-v3-core/contracts/dependencies/openzeppelin/upgradeability/BaseAdminUpgradeabilityProxy.sol';
import {IERC20} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {DelegationMode} from 'aave-token-v3/DelegationAwareBalance.sol';

contract ATokenBalancesTest is Test {
  using stdJson for string;

  address constant USER_1 = address(123);
  address constant USER_2 = address(1234);
  address constant USER_3 = address(12345);
  address constant USER_4 = address(123456);

  uint256 constant INDEX = 1e27;
  uint256 constant AMOUNT = 100 ether;

  ATokenWithDelegation aToken = ATokenWithDelegation(AaveV3EthereumAssets.AAVE_A_TOKEN);

  address[] users;
  mapping(address => uint256) balancesBefore;
  mapping(address => uint256) balancesAfter;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 16931880);

    _getUsers();
  }

  function testBalances() public {
    ATokenWithDelegation aTokenImpl = new ATokenWithDelegation(AaveV3Ethereum.POOL);

    _getBalances(true);

    hoax(address(AaveV3Ethereum.POOL_CONFIGURATOR));
    BaseAdminUpgradeabilityProxy(payable(address(AaveV3EthereumAssets.AAVE_A_TOKEN))).upgradeTo(
      address(aTokenImpl)
    );

    _getBalances(false);

    _validateBalances();
  }

  function _validateBalances() internal {
    for (uint256 i; i < users.length; i++) {
      address user = users[i];
      assertEq(balancesBefore[user], balancesAfter[user]);
    }
  }

  function _getBalances(bool before) internal {
    for (uint256 i; i < users.length; i++) {
      address user = users[i];
      if (before) {
        balancesBefore[user] = IERC20(AaveV3EthereumAssets.AAVE_A_TOKEN).balanceOf(user);
      } else {
        balancesAfter[user] = IERC20(AaveV3EthereumAssets.AAVE_A_TOKEN).balanceOf(user);
      }
    }
  }

  function _getUsers() internal {
    string memory path = './tests/utils/aTokenHolders.json';

    string memory json = vm.readFile(string(abi.encodePacked(path)));
    users = abi.decode(json.parseRaw('.holders'), (address[]));
  }
}
