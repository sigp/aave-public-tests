// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {IStakedTokenV2} from '../interfaces/IStakedTokenV2.sol';

import {DistributionTypes} from '../lib/DistributionTypes.sol';
import {SafeERC20} from '../lib/SafeERC20.sol';

import {VersionedInitializable} from '../utils/VersionedInitializable.sol';
import {AaveDistributionManager} from './AaveDistributionManager.sol';
import {GovernancePowerWithSnapshot} from '../lib/GovernancePowerWithSnapshot.sol';
import {BaseMintableAaveToken} from './BaseMintableAaveToken.sol';

/**
 * @title StakedTokenV2
 * @notice Contract to stake Aave token, tokenize the position and get rewards, inheriting from a distribution manager contract
 * @author BGD Labs
 */
abstract contract StakedTokenV2 is
  IStakedTokenV2,
  BaseMintableAaveToken,
  GovernancePowerWithSnapshot,
  VersionedInitializable,
  AaveDistributionManager
{
  using SafeERC20 for IERC20;

  IERC20 public immutable STAKED_TOKEN;
  IERC20 public immutable REWARD_TOKEN;

  /// @notice Seconds available to redeem once the cooldown period is fulfilled
  uint256 public immutable UNSTAKE_WINDOW;

  /// @notice Address to pull from the rewards, needs to have approved this contract
  address public immutable REWARDS_VAULT;

  mapping(address => uint256) public stakerRewardsToClaim;
  mapping(address => CooldownSnapshot) public stakersCooldowns;

  /// @dev End of Storage layout from StakedToken v1

  /// @dev To see the voting mappings, go to GovernancePowerWithSnapshot.sol
  mapping(address => address) internal _votingDelegates;

  mapping(address => mapping(uint256 => Snapshot))
    internal _propositionPowerSnapshots;
  mapping(address => uint256) internal _propositionPowerSnapshotsCounts;
  mapping(address => address) internal _propositionPowerDelegates;

  bytes32 public DOMAIN_SEPARATOR;
  bytes public constant EIP712_REVISION = bytes('1');
  bytes32 internal constant EIP712_DOMAIN =
    keccak256(
      'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'
    );
  bytes32 public constant PERMIT_TYPEHASH =
    keccak256(
      'Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)'
    );

  /// @dev owner => next valid nonce to submit with permit()
  mapping(address => uint256) public _nonces;

  constructor(
    IERC20 stakedToken,
    IERC20 rewardToken,
    uint256 unstakeWindow,
    address rewardsVault,
    address emissionManager,
    uint128 distributionDuration
  ) AaveDistributionManager(emissionManager, distributionDuration) {
    STAKED_TOKEN = stakedToken;
    REWARD_TOKEN = rewardToken;
    UNSTAKE_WINDOW = unstakeWindow;
    REWARDS_VAULT = rewardsVault;
  }

  /// @inheritdoc IStakedTokenV2
  function stake(address onBehalfOf, uint256 amount) external virtual override;

  /// @inheritdoc IStakedTokenV2
  function redeem(address to, uint256 amount) external virtual override;

  /// @inheritdoc IStakedTokenV2
  function cooldown() external virtual override;

  /// @inheritdoc IStakedTokenV2
  function claimRewards(address to, uint256 amount) external virtual override;

  /// @inheritdoc IStakedTokenV2
  function getTotalRewardsBalance(
    address staker
  ) external view returns (uint256) {
    DistributionTypes.UserStakeInput[]
      memory userStakeInputs = new DistributionTypes.UserStakeInput[](1);
    userStakeInputs[0] = DistributionTypes.UserStakeInput({
      underlyingAsset: address(this),
      stakedByUser: balanceOf(staker),
      totalStaked: totalSupply()
    });
    return
      stakerRewardsToClaim[staker] +
      _getUnclaimedRewards(staker, userStakeInputs);
  }

  /// @inheritdoc IStakedTokenV2
  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    require(owner != address(0), 'INVALID_OWNER');
    //solium-disable-next-line
    require(block.timestamp <= deadline, 'INVALID_EXPIRATION');
    uint256 currentValidNonce = _nonces[owner];
    bytes32 digest = keccak256(
      abi.encodePacked(
        '\x19\x01',
        DOMAIN_SEPARATOR,
        keccak256(
          abi.encode(
            PERMIT_TYPEHASH,
            owner,
            spender,
            value,
            currentValidNonce,
            deadline
          )
        )
      )
    );

    require(owner == ecrecover(digest, v, r, s), 'INVALID_SIGNATURE');
    unchecked {
      _nonces[owner] = currentValidNonce + 1;
    }
    _approve(owner, spender, value);
  }

  /**
   * @dev Updates the user state related with his accrued rewards
   * @param user Address of the user
   * @param userBalance The current balance of the user
   * @param updateStorage Boolean flag used to update or not the stakerRewardsToClaim of the user
   * @return The unclaimed rewards that were added to the total accrued
   */
  function _updateCurrentUnclaimedRewards(
    address user,
    uint256 userBalance,
    bool updateStorage
  ) internal returns (uint256) {
    uint256 accruedRewards = _updateUserAssetInternal(
      user,
      address(this),
      userBalance,
      totalSupply()
    );
    uint256 unclaimedRewards = stakerRewardsToClaim[user] + accruedRewards;

    if (accruedRewards != 0) {
      if (updateStorage) {
        stakerRewardsToClaim[user] = unclaimedRewards;
      }
      emit RewardsAccrued(user, accruedRewards);
    }

    return unclaimedRewards;
  }
}
