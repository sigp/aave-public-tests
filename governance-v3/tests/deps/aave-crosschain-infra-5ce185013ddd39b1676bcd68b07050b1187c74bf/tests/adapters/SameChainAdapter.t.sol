// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {SameChainAdapter, IBaseReceiverPortal, IBaseAdapter} from '../../src/contracts/adapters/sameChain/SameChainAdapter.sol';

contract SameChainAdapterTest is Test {
  address public ORIGIN = address(123);
  address public DESTINATION = address(1234);

  SameChainAdapter public sameChainAdapter;

  function setUp() public {
    sameChainAdapter = new SameChainAdapter();
  }

  function testForwardPayload() public {
    uint40 payloadId = uint40(0);
    bytes memory encodedMessage = abi.encode(payloadId);
    bytes memory message = abi.encode(0, ORIGIN, DESTINATION, encodedMessage);

    vm.mockCall(
      DESTINATION,
      abi.encodeWithSelector(IBaseReceiverPortal.receiveCrossChainMessage.selector),
      abi.encode()
    );
    vm.expectCall(
      DESTINATION,
      abi.encodeWithSelector(
        IBaseReceiverPortal.receiveCrossChainMessage.selector,
        ORIGIN,
        _getChainID(),
        encodedMessage
      )
    );
    (bool success, ) = address(sameChainAdapter).delegatecall(
      abi.encodeWithSelector(IBaseAdapter.forwardMessage.selector, DESTINATION, 0, 137, message)
    );

    vm.clearMockedCalls();

    assertEq(success, true);
  }

  function _getChainID() internal view returns (uint256) {
    uint256 id;
    assembly {
      id := chainid()
    }
    return id;
  }
}
