// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SlotUtils} from '../contracts/libraries/SlotUtils.sol';

contract UseSlotUtils {

  function getAccountSlotHash(
    address account,
    uint256 balanceMappingPosition
  ) external pure returns (bytes32) {
    return SlotUtils.getAccountSlotHash(account, balanceMappingPosition);
  }
  
}
