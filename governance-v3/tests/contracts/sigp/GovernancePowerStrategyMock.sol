pragma solidity ^0.8.0;
/*
import {IGovernancePowerDelegationToken} from 'aave-token-v3/interfaces/IGovernancePowerDelegationToken.sol';
import {BaseGovernancePowerStrategy} from '../contracts/BaseGovernancePowerStrategy.sol';
// SigP mock to test BaseGovernancePowerStrategy

contract GovernancePowerStrategyMock is BaseGovernancePowerStrategy {

    address public tokenA;
    address public tokenB;

    constructor (address _tokenA, address _tokenB) {
        tokenA = _tokenA;
        tokenB = _tokenB;
    }

    function getVotingAssetList()
    public
    view
    override
    returns (address[] memory)
  {
    address[] memory votingAssets = new address[](2);

    votingAssets[0] = tokenA;
    votingAssets[1] = tokenB;


    return votingAssets;
  }

  function getVotingAssetConfig(
    address asset
  ) public view override returns (VotingAssetConfig memory) {
    VotingAssetConfig memory votingAssetConfig;

    if (asset == tokenA || asset == tokenB) {
      votingAssetConfig.weight = WEIGHT_PRECISION;
    }

    return votingAssetConfig;
  }


}
*/