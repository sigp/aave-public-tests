```diff
diff --git a/lib/aave-v3-core/contracts/protocol/tokenization/base/MintableIncentivizedERC20.sol b/src/contracts/MintableIncentivizedERC20.sol
index 6d2120e..404e15a 100644
--- a/lib/aave-v3-core/contracts/protocol/tokenization/base/MintableIncentivizedERC20.sol
+++ b/src/contracts/MintableIncentivizedERC20.sol
@@ -1,8 +1,8 @@
-// SPDX-License-Identifier: BUSL-1.1
-pragma solidity 0.8.10;
+// SPDX-License-Identifier: MIT
+pragma solidity ^0.8.10;
 
-import {IAaveIncentivesController} from '../../../interfaces/IAaveIncentivesController.sol';
-import {IPool} from '../../../interfaces/IPool.sol';
+import {IAaveIncentivesController} from 'aave-v3-core/contracts/interfaces/IAaveIncentivesController.sol';
+import {IPool} from 'aave-v3-core/contracts/interfaces/IPool.sol';
 import {IncentivizedERC20} from './IncentivizedERC20.sol';
 
 /**
@@ -32,11 +32,11 @@ abstract contract MintableIncentivizedERC20 is IncentivizedERC20 {
    * @param account The address receiving tokens
    * @param amount The amount of tokens to mint
    */
-  function _mint(address account, uint128 amount) internal virtual {
+  function _mint(address account, uint120 amount) internal virtual {
     uint256 oldTotalSupply = _totalSupply;
     _totalSupply = oldTotalSupply + amount;
 
-    uint128 oldAccountBalance = _userState[account].balance;
+    uint120 oldAccountBalance = _userState[account].balance;
     _userState[account].balance = oldAccountBalance + amount;
 
     IAaveIncentivesController incentivesControllerLocal = _incentivesController;
@@ -50,11 +50,11 @@ abstract contract MintableIncentivizedERC20 is IncentivizedERC20 {
    * @param account The account whose tokens are burnt
    * @param amount The amount of tokens to burn
    */
-  function _burn(address account, uint128 amount) internal virtual {
+  function _burn(address account, uint120 amount) internal virtual {
     uint256 oldTotalSupply = _totalSupply;
     _totalSupply = oldTotalSupply - amount;
 
-    uint128 oldAccountBalance = _userState[account].balance;
+    uint120 oldAccountBalance = _userState[account].balance;
     _userState[account].balance = oldAccountBalance - amount;
 
     IAaveIncentivesController incentivesControllerLocal = _incentivesController;
```
