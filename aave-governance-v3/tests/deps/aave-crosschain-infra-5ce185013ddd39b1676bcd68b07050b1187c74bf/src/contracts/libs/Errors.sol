// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Errors library
 * @author BGD Labs
 * @notice Defines the error messages emitted by the different contracts of the Aave Governance V3
 */
library Errors {
  string public constant ETH_TRANSFER_FAILED = '1'; // failed to transfer eth to destination
  string public constant CALLER_IS_NOT_APPROVED_SENDER = '2'; // caller must be an approved message sender
  string public constant MESSAGE_REQUIRED_TO_HAVE_BEEN_PREVIOUSLY_FORWARDED = '3'; // message can only be retried if it has been previously forwarded
  string public constant NO_MESSAGE_FORWARDED_SUCCESSFULLY = '4'; // message was not able to be forwarded
  string public constant CURRENT_OR_DESTINATION_CHAIN_ADAPTER_NOT_SET = '5'; // can not enable bridge adapter if the current or destination chain adapter is 0 address
  string public constant CALLER_NOT_APPROVED_BRIDGE = '6'; // caller must be an approved bridge
  string public constant TIMESTAMP_ALREADY_PASSED = '7'; // timestamp is older than current timestamp (in the past)
  string public constant CALLER_NOT_CCIP_ROUTER = '8'; // caller must be bridge provider contract
  string public constant CCIP_ROUTER_CANT_BE_ADDRESS_0 = '9'; // CCIP bridge adapters needs a CCIP Router
  string public constant RECEIVER_NOT_SET = '10'; // receiver address on destination chain can not be 0
  string public constant DESTINATION_CHAIN_ID_NOT_SUPPORTED = '11'; // destination chain id must be supported by bridge provider
  string public constant NOT_ENOUGH_VALUE_TO_PAY_BRIDGE_FEES = '12'; // cross chain controller does not have enough funds to forward the message
  string public constant INCORRECT_ORIGIN_CHAIN_ID = '13'; // message origination chain id is not from a supported chain
  string public constant REMOTE_NOT_TRUSTED = '14'; // remote address has not been registered as a trusted origin
  string public constant CALLER_NOT_HL_MAILBOX = '15'; // caller must be the HyperLane Mailbox contract
}
