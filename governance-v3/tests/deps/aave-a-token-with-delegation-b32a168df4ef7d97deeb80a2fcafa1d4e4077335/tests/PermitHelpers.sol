// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IGovernancePowerDelegationToken} from 'aave-token-v3/interfaces/IGovernancePowerDelegationToken.sol';

library PermitHelpers {
  struct Permit {
    address owner;
    address spender;
    uint256 value;
    uint256 nonce;
    uint256 deadline;
  }

  struct DelegateByType {
    address delegator;
    address delegatee;
    IGovernancePowerDelegationToken.GovernancePowerType delegationType;
    uint256 nonce;
    uint256 deadline;
  }

  struct Delegate {
    address delegator;
    address delegatee;
    uint256 nonce;
    uint256 deadline;
  }

  // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
  function getPermitTypedDataHash(
    Permit memory _permit,
    bytes32 domainSeparator,
    bytes32 permitTypeHash
  ) public pure returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          '\x19\x01',
          domainSeparator,
          keccak256(
            abi.encode(
              permitTypeHash,
              _permit.owner,
              _permit.spender,
              _permit.value,
              _permit.nonce,
              _permit.deadline
            )
          )
        )
      );
  }

  // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
  function getMetaDelegateByTypedDataHash(
    DelegateByType memory _delegateByType,
    bytes32 domainSeparator,
    bytes32 delegateByTypeHash
  ) public pure returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          '\x19\x01',
          domainSeparator,
          keccak256(
            abi.encode(
              delegateByTypeHash,
              _delegateByType.delegator,
              _delegateByType.delegatee,
              _delegateByType.delegationType,
              _delegateByType.nonce,
              _delegateByType.deadline
            )
          )
        )
      );
  }

  // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
  function getMetaDelegateDataHash(
    Delegate memory _delegate,
    bytes32 domainSeparator,
    bytes32 delegateTypeHash
  ) public pure returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          '\x19\x01',
          domainSeparator,
          keccak256(
            abi.encode(
              delegateTypeHash,
              _delegate.delegator,
              _delegate.delegatee,
              _delegate.nonce,
              _delegate.deadline
            )
          )
        )
      );
  }
}
