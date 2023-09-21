// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {BaseAdapter} from '../crosschain-infra/adapters/BaseAdapter.sol';

/**
 * @title BaseAdapterMock
 * @author Sigp
 * @notice A mock contract to test the abtract contract BaseAdapter
 */
contract BaseAdapterMock is BaseAdapter {
    constructor(address crossChainController, TrustedRemotesConfig[] memory originConfigs)  
    BaseAdapter (crossChainController, originConfigs){}

  function nativeToInfraChainId(uint256 nativeChainId) public view override returns (uint256) {
    return 0;
  }


  function infraToNativeChainId(uint256 infraChainId) public view override returns (uint256) {
    return 0;
  }

  function setupPayments() external override{}

  function registerReceivedMessage(bytes calldata _payload, uint256 originChainId) external {
    _registerReceivedMessage(_payload, originChainId);
  }

   function forwardMessage(
    address,
    uint256,
    uint256,
    bytes calldata
  ) external returns (address, uint256) {
    return (address(0), 0);
  }

}