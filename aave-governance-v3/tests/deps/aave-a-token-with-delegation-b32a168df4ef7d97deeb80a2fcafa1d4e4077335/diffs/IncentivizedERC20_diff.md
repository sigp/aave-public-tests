```diff
diff --git a/lib/aave-v3-core/contracts/protocol/tokenization/base/IncentivizedERC20.sol b/src/contracts/IncentivizedERC20.sol
index 08a219e..af09e42 100644
--- a/lib/aave-v3-core/contracts/protocol/tokenization/base/IncentivizedERC20.sol
+++ b/src/contracts/IncentivizedERC20.sol
@@ -1,16 +1,17 @@
-// SPDX-License-Identifier: BUSL-1.1
-pragma solidity 0.8.10;
+// SPDX-License-Identifier: MIT
+pragma solidity ^0.8.10;
 
-import {Context} from '../../../dependencies/openzeppelin/contracts/Context.sol';
-import {IERC20} from '../../../dependencies/openzeppelin/contracts/IERC20.sol';
-import {IERC20Detailed} from '../../../dependencies/openzeppelin/contracts/IERC20Detailed.sol';
-import {SafeCast} from '../../../dependencies/openzeppelin/contracts/SafeCast.sol';
-import {WadRayMath} from '../../libraries/math/WadRayMath.sol';
-import {Errors} from '../../libraries/helpers/Errors.sol';
-import {IAaveIncentivesController} from '../../../interfaces/IAaveIncentivesController.sol';
-import {IPoolAddressesProvider} from '../../../interfaces/IPoolAddressesProvider.sol';
-import {IPool} from '../../../interfaces/IPool.sol';
-import {IACLManager} from '../../../interfaces/IACLManager.sol';
+import {Context} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/Context.sol';
+import {IERC20} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
+import {IERC20Detailed} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20Detailed.sol';
+import {SafeCast} from './SafeCast.sol';
+import {WadRayMath} from 'aave-v3-core/contracts/protocol/libraries/math/WadRayMath.sol';
+import {Errors} from 'aave-v3-core/contracts/protocol/libraries/helpers/Errors.sol';
+import {IAaveIncentivesController} from 'aave-v3-core/contracts/interfaces/IAaveIncentivesController.sol';
+import {IPoolAddressesProvider} from 'aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol';
+import {IPool} from 'aave-v3-core/contracts/interfaces/IPool.sol';
+import {IACLManager} from 'aave-v3-core/contracts/interfaces/IACLManager.sol';
+import {DelegationMode} from 'aave-token-v3/DelegationAwareBalance.sol';
 
 /**
  * @title IncentivizedERC20
@@ -43,9 +44,11 @@ abstract contract IncentivizedERC20 is Context, IERC20Detailed {
    * ATokens and VariableDebtTokens use this field store the index of the
    * user's last supply/withdrawal/borrow/repayment. StableDebtTokens use
    * this field to store the user's stable rate.
+   * delegationMode stores the current delegation of the user
    */
   struct UserState {
-    uint128 balance;
+    uint120 balance;
+    DelegationMode delegationMode;
     uint128 additionalData;
   }
   // Map of users address and their state data (userAddress => userStateData)
@@ -120,7 +123,7 @@ abstract contract IncentivizedERC20 is Context, IERC20Detailed {
 
   /// @inheritdoc IERC20
   function transfer(address recipient, uint256 amount) external virtual override returns (bool) {
-    uint128 castAmount = amount.toUint128();
+    uint120 castAmount = amount.toUint120();
     _transfer(_msgSender(), recipient, castAmount);
     return true;
   }
@@ -145,7 +148,7 @@ abstract contract IncentivizedERC20 is Context, IERC20Detailed {
     address recipient,
     uint256 amount
   ) external virtual override returns (bool) {
-    uint128 castAmount = amount.toUint128();
+    uint120 castAmount = amount.toUint120();
     _approve(sender, _msgSender(), _allowances[sender][_msgSender()] - castAmount);
     _transfer(sender, recipient, castAmount);
     return true;
@@ -182,10 +185,10 @@ abstract contract IncentivizedERC20 is Context, IERC20Detailed {
    * @param recipient The destination address
    * @param amount The amount getting transferred
    */
-  function _transfer(address sender, address recipient, uint128 amount) internal virtual {
-    uint128 oldSenderBalance = _userState[sender].balance;
+  function _transfer(address sender, address recipient, uint120 amount) internal virtual {
+    uint120 oldSenderBalance = _userState[sender].balance;
     _userState[sender].balance = oldSenderBalance - amount;
-    uint128 oldRecipientBalance = _userState[recipient].balance;
+    uint120 oldRecipientBalance = _userState[recipient].balance;
     _userState[recipient].balance = oldRecipientBalance + amount;
 
     IAaveIncentivesController incentivesControllerLocal = _incentivesController;
```
