pragma solidity ^0.8.8;
import {BaseAdapterMock} from './BaseAdapterMock.sol';

contract SigpDelegatecall {
    address public baseAdapter;
    constructor(address _baseAdapter) {
        baseAdapter = _baseAdapter;
    }

    function delegateRegisterReceivedMessage(bytes calldata _payload, uint256 originChainId) external {
     (bool success, bytes memory returnData) = baseAdapter.delegatecall(
          abi.encodeWithSelector(
            BaseAdapterMock.registerReceivedMessage.selector,
           _payload,
            originChainId
          )
    );
    if (!success) {
            assembly {
                revert(add(returnData, 32), returnData) // to get the revert string
            }
        }
    
    }
}