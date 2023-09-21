// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {ATokenWithDelegation} from '../src/contracts/ATokenWithDelegation.sol';
import {IGovernancePowerDelegationToken} from 'aave-token-v3/interfaces/IGovernancePowerDelegationToken.sol';
import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {BaseAdminUpgradeabilityProxy} from 'aave-v3-core/contracts/dependencies/openzeppelin/upgradeability/BaseAdminUpgradeabilityProxy.sol';
import {IERC20} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol';

contract ATokenWithDelegationIntegrationTest is Test {
  address constant USER_1 = address(123);
  address constant USER_2 = address(1234);
  address constant USER_3 = address(12345);
  address constant USER_4 = address(123456);

  uint256 constant INDEX = 1e27;
  uint256 constant AMOUNT = 100 ether;

  ATokenWithDelegation aToken = ATokenWithDelegation(AaveV3EthereumAssets.AAVE_A_TOKEN);

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 16931880);

    ATokenWithDelegation aTokenImpl = new ATokenWithDelegation(AaveV3Ethereum.POOL);

    hoax(address(AaveV3Ethereum.POOL_CONFIGURATOR));
    BaseAdminUpgradeabilityProxy(payable(address(AaveV3EthereumAssets.AAVE_A_TOKEN))).upgradeTo(
      address(aTokenImpl)
    );
  }

  function testMintDoesNotGiveDelegation() public {
    hoax(address(AaveV3Ethereum.POOL));
    aToken.mint(USER_1, USER_1, AMOUNT, INDEX);

    (uint256 votingPower, uint256 propositionPower) = aToken.getPowersCurrent(USER_1);

    assertEq(votingPower, AMOUNT);
    assertEq(propositionPower, AMOUNT);
  }

  function testTransferAlsoMovesDelegation() public {
    vm.startPrank(address(AaveV3Ethereum.POOL));
    aToken.mint(USER_1, USER_1, AMOUNT, INDEX);
    aToken.mint(USER_2, USER_2, AMOUNT, INDEX);
    aToken.mint(USER_3, USER_3, AMOUNT, INDEX);
    aToken.mint(USER_4, USER_4, AMOUNT, INDEX);
    vm.stopPrank();

    hoax(USER_1);
    aToken.delegate(USER_2);
    hoax(USER_3);
    aToken.delegate(USER_4);

    _validateDelegatees();
    _validateVotingPower();

    assertEq(IERC20(address(aToken)).balanceOf(USER_1), AMOUNT);
    assertEq(IERC20(address(aToken)).balanceOf(USER_2), AMOUNT);
    assertEq(IERC20(address(aToken)).balanceOf(USER_3), AMOUNT);
    assertEq(IERC20(address(aToken)).balanceOf(USER_4), AMOUNT);

    hoax(USER_1);
    IERC20(address(aToken)).transfer(USER_3, AMOUNT);

    _validateDelegateesAfter();
    _validateVotingPowerAfter();

    assertEq(IERC20(address(aToken)).balanceOf(USER_1), 0);
    assertEq(IERC20(address(aToken)).balanceOf(USER_2), AMOUNT);
    assertEq(IERC20(address(aToken)).balanceOf(USER_3), AMOUNT * 2);
    assertEq(IERC20(address(aToken)).balanceOf(USER_4), AMOUNT);
  }

  function _validateVotingPower() internal {
    (uint256 votingPower_user1, uint256 propositionPower_user1) = aToken.getPowersCurrent(USER_1);
    (uint256 votingPower_user2, uint256 propositionPower_user2) = aToken.getPowersCurrent(USER_2);
    (uint256 votingPower_user3, uint256 propositionPower_user3) = aToken.getPowersCurrent(USER_3);
    (uint256 votingPower_user4, uint256 propositionPower_user4) = aToken.getPowersCurrent(USER_4);

    assertEq(votingPower_user1, 0);
    assertEq(propositionPower_user1, 0);
    assertEq(votingPower_user2, AMOUNT * 2);
    assertEq(propositionPower_user2, AMOUNT * 2);
    assertEq(votingPower_user3, 0);
    assertEq(propositionPower_user3, 0);
    assertEq(votingPower_user4, AMOUNT * 2);
    assertEq(propositionPower_user4, AMOUNT * 2);
  }

  function _validateVotingPowerAfter() internal {
    (uint256 votingPower_user1_after, uint256 propositionPower_user1_after) = aToken
      .getPowersCurrent(USER_1);
    (uint256 votingPower_user2_after, uint256 propositionPower_user2_after) = aToken
      .getPowersCurrent(USER_2);
    (uint256 votingPower_user3_after, uint256 propositionPower_user3_after) = aToken
      .getPowersCurrent(USER_3);
    (uint256 votingPower_user4_after, uint256 propositionPower_user4_after) = aToken
      .getPowersCurrent(USER_4);

    assertEq(votingPower_user1_after, 0);
    assertEq(propositionPower_user1_after, 0);
    assertEq(votingPower_user2_after, AMOUNT);
    assertEq(propositionPower_user2_after, AMOUNT);
    assertEq(votingPower_user3_after, 0);
    assertEq(propositionPower_user3_after, 0);
    assertEq(votingPower_user4_after, AMOUNT * 3);
    assertEq(propositionPower_user4_after, AMOUNT * 3);
  }

  function _validateDelegatees() internal {
    address user1VotingDelegatee = aToken.getDelegateeByType(
      USER_1,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    );
    address user1PropositionDelegatee = aToken.getDelegateeByType(
      USER_1,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    );
    address user2VotingDelegatee = aToken.getDelegateeByType(
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    );
    address user2PropositionDelegatee = aToken.getDelegateeByType(
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    );
    address user3VotingDelegatee = aToken.getDelegateeByType(
      USER_3,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    );
    address user3PropositionDelegatee = aToken.getDelegateeByType(
      USER_3,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    );
    address user4VotingDelegatee = aToken.getDelegateeByType(
      USER_4,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    );
    address user4PropositionDelegatee = aToken.getDelegateeByType(
      USER_4,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    );

    assertEq(user1VotingDelegatee, USER_2);
    assertEq(user1PropositionDelegatee, USER_2);
    assertEq(user2VotingDelegatee, address(0));
    assertEq(user2PropositionDelegatee, address(0));
    assertEq(user3VotingDelegatee, USER_4);
    assertEq(user3PropositionDelegatee, USER_4);
    assertEq(user4VotingDelegatee, address(0));
    assertEq(user4PropositionDelegatee, address(0));
  }

  function _validateDelegateesAfter() internal {
    address user1VotingDelegatee_after = aToken.getDelegateeByType(
      USER_1,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    );
    address user1PropositionDelegatee_after = aToken.getDelegateeByType(
      USER_1,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    );
    address user2VotingDelegatee_after = aToken.getDelegateeByType(
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    );
    address user2PropositionDelegatee_after = aToken.getDelegateeByType(
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    );
    address user3VotingDelegatee_after = aToken.getDelegateeByType(
      USER_3,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    );
    address user3PropositionDelegatee_after = aToken.getDelegateeByType(
      USER_3,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    );
    address user4VotingDelegatee_after = aToken.getDelegateeByType(
      USER_4,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    );
    address user4PropositionDelegatee_after = aToken.getDelegateeByType(
      USER_4,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    );

    assertEq(user1VotingDelegatee_after, USER_2);
    assertEq(user1PropositionDelegatee_after, USER_2);
    assertEq(user2VotingDelegatee_after, address(0));
    assertEq(user2PropositionDelegatee_after, address(0));
    assertEq(user3VotingDelegatee_after, USER_4);
    assertEq(user3PropositionDelegatee_after, USER_4);
    assertEq(user4VotingDelegatee_after, address(0));
    assertEq(user4PropositionDelegatee_after, address(0));
  }
}
