// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {ATokenWithDelegation} from '../src/contracts/ATokenWithDelegation.sol';
import {IGovernancePowerDelegationToken} from 'aave-token-v3/interfaces/IGovernancePowerDelegationToken.sol';

import {DelegationMode} from 'aave-token-v3/DelegationAwareBalance.sol';
import {DelegationBaseTest} from './DelegationBaseTest.sol';
import {PermitHelpers} from './PermitHelpers.sol';

contract ATokenWithDelegationTest is DelegationBaseTest {
  address constant USER_1 = address(123);
  address constant USER_2 = address(1234);
  address constant USER_3 = address(12345);
  address constant USER_4 = address(123456);

  uint256 constant PRIVATE_KEY = 0xB26ECB;
  address delegator;

  function setUp() public {
    delegator = vm.addr(PRIVATE_KEY);
  }

  // ----------------------------------------------------------------------------------------------
  //                       INTERNAL METHODS
  // ----------------------------------------------------------------------------------------------

  // TEST _governancePowerTransferByType
  function test_governancePowerTransferByTypeVoting()
    public
    mintAmount(USER_2)
    validateUserTokenBalance(USER_2)
  {
    uint72 delegationVotingPowerBefore = _getDelegationBalanceByType(
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    );

    uint256 impactOnDelegationBefore = 0 ether;
    uint256 impactOnDelegationAfter = 10 ether;

    _governancePowerTransferByType(
      impactOnDelegationBefore,
      impactOnDelegationAfter,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    );

    uint72 delegationVotingPowerAfter = _getDelegationBalanceByType(
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    );

    assertEq(
      delegationVotingPowerAfter,
      delegationVotingPowerBefore -
        uint72(impactOnDelegationBefore / POWER_SCALE_FACTOR) +
        uint72(impactOnDelegationAfter / POWER_SCALE_FACTOR)
    );
  }

  function test_governancePowerTransferByTypeProposition()
    public
    mintAmount(USER_2)
    validateUserTokenBalance(USER_2)
  {
    uint72 delegationPropositionPowerBefore = _getDelegationBalanceByType(
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    );

    uint256 impactOnDelegationBefore = 0 ether;
    uint256 impactOnDelegationAfter = 10 ether;

    _governancePowerTransferByType(
      impactOnDelegationBefore,
      impactOnDelegationAfter,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    );

    uint72 delegationPropositionPowerAfter = _getDelegationBalanceByType(
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    );

    assertEq(
      delegationPropositionPowerAfter,
      delegationPropositionPowerBefore -
        uint72(impactOnDelegationBefore / POWER_SCALE_FACTOR) +
        uint72(impactOnDelegationAfter / POWER_SCALE_FACTOR)
    );
  }

  function test_governancePowerTransferByTypeWhenDelegationReceiverIsAddress0()
    public
    validateNoChangesInDelegationBalanceByType(
      address(0),
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    )
  {
    uint256 impactOnDelegationBefore = 1 ether;
    uint256 impactOnDelegationAfter = 12 ether;
    _governancePowerTransferByType(
      impactOnDelegationBefore,
      impactOnDelegationAfter,
      address(0),
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    );
  }

  function test_governancePowerTransferByTypeWhenSameImpact()
    public
    mintAmount(USER_2)
    validateNoChangesInDelegationBalanceByType(
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    )
    validateUserTokenBalance(USER_2)
  {
    uint256 impactOnDelegationBefore = 12 ether;
    uint256 impactOnDelegationAfter = 12 ether;
    _governancePowerTransferByType(
      impactOnDelegationBefore,
      impactOnDelegationAfter,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    );
  }

  // TEST _delegationChangeOnTransfer
  function test_delegationChangeOnTransfer()
    public
    mintAmount(USER_1)
    mintAmount(USER_2)
    prepareDelegationToReceiver(USER_1, USER_3)
    prepareDelegationToReceiver(USER_2, USER_4)
    validateUserTokenBalance(USER_1)
    validateUserTokenBalance(USER_2)
    validateNoChangesInDelegationState(USER_1)
    validateNoChangesInDelegationState(USER_2)
    validateDelegationPower(
      USER_1,
      USER_4,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    )
    validateDelegationPower(
      USER_1,
      USER_4,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    )
  {
    _delegationChangeOnTransfer(USER_1, USER_2, _getBalance(USER_1), _getBalance(USER_2), AMOUNT);
  }

  function test_delegationChangeOnTransferWhenFromEqTo()
    public
    mintAmount(USER_1)
    validateUserTokenBalance(USER_1)
    validateUserTokenBalance(USER_2)
    validateNoChangesInDelegation(USER_1)
    validateNoChangesInDelegation(USER_2)
  {
    _delegationChangeOnTransfer(USER_1, USER_1, _getBalance(USER_1), _getBalance(USER_1), AMOUNT);
  }

  function test_delegationChangeOnTransferWhenFromEq0()
    public
    mintAmount(address(0))
    mintAmount(USER_1)
    validateUserTokenBalance(USER_1)
    prepareDelegationToReceiver(USER_1, USER_3)
    validateDelegationPower(
      address(0),
      USER_3,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    )
    validateDelegationPower(
      address(0),
      USER_3,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    )
  {
    _delegationChangeOnTransfer(
      address(0),
      USER_1,
      _getBalance(address(0)),
      _getBalance(USER_1),
      AMOUNT
    );
  }

  function test_delegationChangeOnTransferWhenToEq0()
    public
    mintAmount(USER_1)
    validateUserTokenBalance(USER_1)
    validateUserTokenBalance(USER_2)
    prepareDelegationToReceiver(USER_1, USER_2)
    validateDelegationRemoved(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    )
    validateDelegationRemoved(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    )
  {
    _delegationChangeOnTransfer(
      USER_1,
      address(0),
      _getBalance(USER_1),
      _getBalance(address(0)),
      AMOUNT
    );
  }

  // test that delegation does not chain
  function test_delegationChangeOnTransferWhenFromNotDelegating()
    public
    mintAmount(USER_1)
    mintAmount(USER_2)
    validateUserTokenBalance(USER_1)
    validateUserTokenBalance(USER_2)
    prepareDelegationToReceiver(USER_2, USER_3)
    validateDelegationPower(
      USER_1,
      USER_3,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    )
    validateDelegationPower(
      USER_1,
      USER_3,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    )
  {
    _delegationChangeOnTransfer(USER_1, USER_2, _getBalance(USER_1), _getBalance(USER_2), AMOUNT);
  }

  function test_delegationChangeOnTransferWhenToNotDelegating()
    public
    mintAmount(USER_1)
    mintAmount(USER_2)
    validateUserTokenBalance(USER_1)
    validateUserTokenBalance(USER_2)
    validateNoChangesInDelegation(USER_2)
    prepareDelegationToReceiver(USER_1, USER_3)
    validateDelegationRemoved(
      USER_1,
      USER_3,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    )
    validateDelegationRemoved(
      USER_1,
      USER_3,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    )
  {
    _delegationChangeOnTransfer(USER_1, USER_2, _getBalance(USER_1), _getBalance(USER_2), AMOUNT);
  }

  // TEST _getDelegatedPowerByType
  function test_getDelegatedPowerByType()
    public
    mintAmount(USER_1)
    prepareDelegationToReceiver(USER_1, USER_2)
  {
    uint256 delegatedVotingPower = _getDelegatedPowerByType(
      _getUserDelegationState(USER_2),
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    );
    uint256 delegatedPropositionPower = _getDelegatedPowerByType(
      _getUserDelegationState(USER_2),
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    );

    assertEq(delegatedVotingPower, uint256(_userState[USER_1].balance));
    assertEq(delegatedPropositionPower, uint256(_userState[USER_1].balance));
  }

  // TEST _getDelegateeByType
  function test_getDelegateeByType()
    public
    mintAmount(USER_1)
    prepareDelegationToReceiver(USER_1, USER_2)
  {
    address votingDelegatee = _getDelegateeByType(
      USER_1,
      _getUserDelegationState(USER_1),
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    );
    address propositionDelegatee = _getDelegateeByType(
      USER_1,
      _getUserDelegationState(USER_1),
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    );

    assertEq(votingDelegatee, USER_2);
    assertEq(propositionDelegatee, USER_2);
  }

  // TEST _updateDelegateeByType
  function test_updateDelegateeByTypeVoting()
    public
    validateDelegationReceiver(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    )
    validateDelegationReceiver(
      USER_1,
      address(0),
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    )
  {
    _updateDelegateeByType(
      USER_1,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING,
      USER_2
    );
  }

  function test_updateDelegateeByTypeProposition()
    public
    validateDelegationReceiver(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    )
    validateDelegationReceiver(
      USER_1,
      address(0),
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    )
  {
    _updateDelegateeByType(
      USER_1,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION,
      USER_2
    );
  }

  // TEST _updateDelegationModeByType
  function test_updateDelegationFlagByTypeVotingFromNoDelegation()
    public
    validateNoChangesInDelegation(USER_1)
  {
    DelegationState memory delegationState = _updateDelegationModeByType(
      _getUserDelegationState(USER_1),
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING,
      true
    );

    assertEq(uint8(delegationState.delegationMode), uint8(DelegationMode.VOTING_DELEGATED));
  }

  function test_updateDelegationFlagByTypePropositionFromNoDelegation()
    public
    validateNoChangesInDelegation(USER_1)
  {
    DelegationState memory delegationState = _updateDelegationModeByType(
      _getUserDelegationState(USER_1),
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION,
      true
    );

    assertEq(uint8(delegationState.delegationMode), uint8(DelegationMode.PROPOSITION_DELEGATED));
  }

  function test_updateDelegationFlagByTypeVotingFromPropositionDelegation()
    public
    prepareDelegationByTypeToReceiver(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    )
    validateNoChangesInDelegation(USER_1)
  {
    DelegationState memory delegationState = _updateDelegationModeByType(
      _getUserDelegationState(USER_1),
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING,
      true
    );

    assertEq(uint8(delegationState.delegationMode), uint8(DelegationMode.FULL_POWER_DELEGATED));
  }

  function test_updateDelegationFlagByTypePropositionFromVotingDelegation()
    public
    prepareDelegationByTypeToReceiver(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    )
    validateNoChangesInDelegation(USER_1)
  {
    DelegationState memory delegationState = _updateDelegationModeByType(
      _getUserDelegationState(USER_1),
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION,
      true
    );

    assertEq(uint8(delegationState.delegationMode), uint8(DelegationMode.FULL_POWER_DELEGATED));
  }

  function test_updateDelegationFlagByTypeRemoveVotingFromVoting()
    public
    prepareDelegationByTypeToReceiver(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    )
    validateNoChangesInDelegation(USER_1)
  {
    DelegationState memory delegationState = _updateDelegationModeByType(
      _getUserDelegationState(USER_1),
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING,
      false
    );

    assertEq(uint8(delegationState.delegationMode), uint8(DelegationMode.NO_DELEGATION));
  }

  function test_updateDelegationFlagByTypeRemovePropositionFromProposition()
    public
    prepareDelegationByTypeToReceiver(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    )
    validateNoChangesInDelegation(USER_1)
  {
    DelegationState memory delegationState = _updateDelegationModeByType(
      _getUserDelegationState(USER_1),
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION,
      false
    );

    assertEq(uint8(delegationState.delegationMode), uint8(DelegationMode.NO_DELEGATION));
  }

  function test_updateDelegationFlagByTypeRemoveVotingFromFullDelegation()
    public
    prepareDelegationToReceiver(USER_1, USER_2)
    validateNoChangesInDelegation(USER_1)
  {
    DelegationState memory delegationState = _updateDelegationModeByType(
      _getUserDelegationState(USER_1),
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING,
      false
    );

    assertEq(uint8(delegationState.delegationMode), uint8(DelegationMode.PROPOSITION_DELEGATED));
  }

  function test_updateDelegationFlagByTypeRemovePropositionFromFullDelegation()
    public
    prepareDelegationToReceiver(USER_1, USER_2)
    validateNoChangesInDelegation(USER_1)
  {
    DelegationState memory delegationState = _updateDelegationModeByType(
      _getUserDelegationState(USER_1),
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION,
      false
    );

    assertEq(uint8(delegationState.delegationMode), uint8(DelegationMode.VOTING_DELEGATED));
  }

  // TEST _delegateByType
  function test_delegateByTypeVoting()
    public
    mintAmount(USER_1)
    validateDelegationPower(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    )
    validateDelegationState(USER_1, USER_2, DelegationType.VOTING)
    validateDelegationReceiver(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    )
    validateUserTokenBalance(USER_1)
    validateUserTokenBalance(USER_2)
  {
    vm.expectEmit(true, true, false, true);
    emit DelegateChanged(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    );
    _delegateByType(USER_1, USER_2, IGovernancePowerDelegationToken.GovernancePowerType.VOTING);
  }

  function test_delegateByTypeProposition()
    public
    mintAmount(USER_1)
    validateDelegationPower(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    )
    validateDelegationState(USER_1, USER_2, DelegationType.PROPOSITION)
    validateDelegationReceiver(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    )
    validateUserTokenBalance(USER_1)
    validateUserTokenBalance(USER_2)
  {
    vm.expectEmit(true, true, false, true);
    emit DelegateChanged(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    );
    _delegateByType(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    );
  }

  function test_delegateByTypeToCurrentDelegatee()
    public
    mintAmount(USER_1)
    prepareDelegationToReceiver(USER_1, USER_2)
    validateNoChangesInDelegation(USER_1)
    validateNoChangesInDelegation(USER_2)
    validateUserTokenBalance(USER_1)
    validateUserTokenBalance(USER_2)
  {
    _delegateByType(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    );
  }

  function test_delegateByTypeToSelf()
    public
    mintAmount(USER_1)
    prepareDelegationByTypeToReceiver(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    )
    validateDelegationRemoved(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    )
    validateUserTokenBalance(USER_1)
    validateUserTokenBalance(USER_2)
  {
    vm.expectEmit(true, true, false, true);
    emit DelegateChanged(
      USER_1,
      address(0),
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    );
    _delegateByType(
      USER_1,
      USER_1,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    );
  }

  // ----------------------------------------------------------------------------------------------
  //                       EXTERNAL METHODS
  // ----------------------------------------------------------------------------------------------
  // TEST delegateByType
  function testDelegateByTypeVoting()
    public
    mintAmount(USER_1)
    validateDelegationPower(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    )
    validateDelegationState(USER_1, USER_2, DelegationType.VOTING)
    validateDelegationReceiver(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    )
    validateUserTokenBalance(USER_1)
    validateUserTokenBalance(USER_2)
  {
    hoax(USER_1);
    vm.expectEmit(true, true, false, true);
    emit DelegateChanged(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    );
    this.delegateByType(USER_2, IGovernancePowerDelegationToken.GovernancePowerType.VOTING);
  }

  function testDelegateByTypeProposition()
    public
    mintAmount(USER_1)
    validateDelegationPower(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    )
    validateDelegationState(USER_1, USER_2, DelegationType.PROPOSITION)
    validateDelegationReceiver(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    )
    validateUserTokenBalance(USER_1)
    validateUserTokenBalance(USER_2)
  {
    hoax(USER_1);
    vm.expectEmit(true, true, false, true);
    emit DelegateChanged(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    );
    this.delegateByType(USER_2, IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION);
  }

  function testDelegateByTypeToCurrentDelegatee()
    public
    mintAmount(USER_1)
    prepareDelegationToReceiver(USER_1, USER_2)
    validateNoChangesInDelegation(USER_1)
    validateNoChangesInDelegation(USER_2)
    validateUserTokenBalance(USER_1)
    validateUserTokenBalance(USER_2)
  {
    hoax(USER_1);
    this.delegateByType(USER_2, IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION);
  }

  function testDelegateByTypeToSelf()
    public
    mintAmount(USER_1)
    prepareDelegationByTypeToReceiver(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    )
    validateDelegationRemoved(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    )
    validateUserTokenBalance(USER_1)
    validateUserTokenBalance(USER_2)
  {
    hoax(USER_1);
    vm.expectEmit(true, true, false, true);
    emit DelegateChanged(
      USER_1,
      address(0),
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    );
    this.delegateByType(USER_1, IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION);
  }

  // TEST delegate
  function testDelegate()
    public
    mintAmount(USER_1)
    validateDelegationPower(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    )
    validateDelegationPower(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    )
    validateDelegationState(USER_1, USER_2, DelegationType.FULL_POWER)
    validateDelegationReceiver(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    )
    validateDelegationReceiver(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    )
    validateUserTokenBalance(USER_1)
    validateUserTokenBalance(USER_2)
  {
    hoax(USER_1);
    vm.expectEmit(true, true, false, true);
    emit DelegateChanged(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    );
    vm.expectEmit(true, true, false, true);
    emit DelegateChanged(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    );
    this.delegate(USER_2);
  }

  function testDelegateToCurrentDelegatee()
    public
    mintAmount(USER_1)
    prepareDelegationToReceiver(USER_1, USER_2)
    validateNoChangesInDelegation(USER_1)
    validateNoChangesInDelegation(USER_2)
    validateUserTokenBalance(USER_1)
    validateUserTokenBalance(USER_2)
  {
    hoax(USER_1);
    this.delegate(USER_2);
  }

  function testDelegateToSelf()
    public
    mintAmount(USER_1)
    prepareDelegationToReceiver(USER_1, USER_2)
    validateDelegationRemoved(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    )
    validateDelegationRemoved(
      USER_1,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    )
    validateUserTokenBalance(USER_1)
    validateUserTokenBalance(USER_2)
  {
    hoax(USER_1);
    vm.expectEmit(true, true, false, true);
    emit DelegateChanged(
      USER_1,
      address(0),
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    );
    emit DelegateChanged(
      USER_1,
      address(0),
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    );

    this.delegate(USER_1);
  }

  // TEST getDelegateeByType
  function testGetDelegateeByType()
    public
    mintAmount(USER_1)
    prepareDelegationToReceiver(USER_1, USER_2)
  {
    address votingDelegatee = this.getDelegateeByType(
      USER_1,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    );
    address propositionDelegatee = this.getDelegateeByType(
      USER_1,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    );

    assertEq(votingDelegatee, USER_2);
    assertEq(propositionDelegatee, USER_2);
  }

  // TEST getDelegates
  function testGetDelegates()
    public
    mintAmount(USER_1)
    prepareDelegationToReceiver(USER_1, USER_2)
  {
    (address votingDelegatee, address propositionDelegatee) = this.getDelegates(USER_1);

    assertEq(votingDelegatee, USER_2);
    assertEq(propositionDelegatee, USER_2);
  }

  // TEST getPowerCurrent
  function testGetPowerCurrent()
    public
    mintAmount(USER_1)
    prepareDelegationToReceiver(USER_1, USER_2)
  {
    uint256 votingPower = this.getPowerCurrent(
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    );

    uint256 propositionPower = this.getPowerCurrent(
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    );

    assertEq(
      votingPower,
      uint256(_delegatedState[USER_2].delegatedVotingBalance * POWER_SCALE_FACTOR)
    );

    assertEq(
      propositionPower,
      uint256(_delegatedState[USER_2].delegatedPropositionBalance * POWER_SCALE_FACTOR)
    );
  }

  // TEST getPowersCurrent
  function testGetPowersCurrent()
    public
    mintAmount(USER_1)
    prepareDelegationToReceiver(USER_1, USER_2)
  {
    (uint256 votingPower, uint256 propositionPower) = this.getPowersCurrent(USER_2);

    assertEq(
      votingPower,
      uint256(_delegatedState[USER_2].delegatedVotingBalance * POWER_SCALE_FACTOR)
    );

    assertEq(
      propositionPower,
      uint256(_delegatedState[USER_2].delegatedPropositionBalance * POWER_SCALE_FACTOR)
    );
  }

  // ----------------------------------------------------------------------------------------------
  //                       META METHODS
  // ----------------------------------------------------------------------------------------------

  // TEST permit
  function testPermit() public {
    uint256 privateKey = 0xB26ECB;
    address owner = vm.addr(privateKey);
    address spender = address(5);
    uint256 amountToPermit = 1000 ether;
    uint256 nonceBefore = nonces(owner);

    PermitHelpers.Permit memory permitParams = PermitHelpers.Permit({
      owner: owner,
      spender: spender,
      value: amountToPermit,
      nonce: nonces(owner),
      deadline: type(uint256).max
    });

    bytes32 digest = PermitHelpers.getPermitTypedDataHash(
      permitParams,
      DOMAIN_SEPARATOR(),
      PERMIT_TYPEHASH
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

    this.permit(
      permitParams.owner,
      permitParams.spender,
      permitParams.value,
      permitParams.deadline,
      v,
      r,
      s
    );

    uint256 nonceAfter = nonces(owner);
    uint256 allowance = this.allowance(owner, spender);
    assertEq(allowance, amountToPermit);
    assertEq(nonceBefore + 1, nonceAfter);
  }

  // TEST metaDelegateByType
  function testMetaDelegateByType()
    public
    mintAmount(delegator)
    validateDelegationPower(
      delegator,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    )
    validateDelegationState(delegator, USER_2, DelegationType.VOTING)
    validateDelegationReceiver(
      delegator,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    )
    validateUserTokenBalance(delegator)
    validateUserTokenBalance(USER_2)
  {
    PermitHelpers.DelegateByType memory delegateByTypeParams = PermitHelpers.DelegateByType({
      delegator: delegator,
      delegatee: USER_2,
      delegationType: IGovernancePowerDelegationToken.GovernancePowerType.VOTING,
      nonce: nonces(delegator),
      deadline: type(uint256).max
    });

    bytes32 digest = PermitHelpers.getMetaDelegateByTypedDataHash(
      delegateByTypeParams,
      DOMAIN_SEPARATOR(),
      DELEGATE_BY_TYPE_TYPEHASH
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY, digest);

    this.metaDelegateByType(
      delegateByTypeParams.delegator,
      delegateByTypeParams.delegatee,
      delegateByTypeParams.delegationType,
      delegateByTypeParams.deadline,
      v,
      r,
      s
    );
  }

  // TEST metaDelegate
  function testMetaDelegate()
    public
    mintAmount(delegator)
    validateDelegationPower(
      delegator,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    )
    validateDelegationPower(
      delegator,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    )
    validateDelegationState(delegator, USER_2, DelegationType.FULL_POWER)
    validateDelegationReceiver(
      delegator,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.VOTING
    )
    validateDelegationReceiver(
      delegator,
      USER_2,
      IGovernancePowerDelegationToken.GovernancePowerType.PROPOSITION
    )
    validateUserTokenBalance(delegator)
    validateUserTokenBalance(USER_2)
  {
    PermitHelpers.Delegate memory delegateByTypeParams = PermitHelpers.Delegate({
      delegator: delegator,
      delegatee: USER_2,
      nonce: nonces(delegator),
      deadline: type(uint256).max
    });

    bytes32 digest = PermitHelpers.getMetaDelegateDataHash(
      delegateByTypeParams,
      DOMAIN_SEPARATOR(),
      DELEGATE_TYPEHASH
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY, digest);

    this.metaDelegate(
      delegateByTypeParams.delegator,
      delegateByTypeParams.delegatee,
      delegateByTypeParams.deadline,
      v,
      r,
      s
    );
  }
}
