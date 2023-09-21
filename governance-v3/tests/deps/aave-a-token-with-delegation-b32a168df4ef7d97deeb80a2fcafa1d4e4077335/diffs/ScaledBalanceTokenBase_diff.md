```diff
diff --git a/lib/aave-v3-core/contracts/protocol/tokenization/base/ScaledBalanceTokenBase.sol b/src/contracts/ScaledBalanceTokenBase.sol
index d0010e5..a5e2a0b 100644
--- a/lib/aave-v3-core/contracts/protocol/tokenization/base/ScaledBalanceTokenBase.sol
+++ b/src/contracts/ScaledBalanceTokenBase.sol
@@ -1,11 +1,11 @@
-// SPDX-License-Identifier: BUSL-1.1
-pragma solidity 0.8.10;
+// SPDX-License-Identifier: MIT
+pragma solidity ^0.8.10;
 
-import {SafeCast} from '../../../dependencies/openzeppelin/contracts/SafeCast.sol';
-import {Errors} from '../../libraries/helpers/Errors.sol';
-import {WadRayMath} from '../../libraries/math/WadRayMath.sol';
-import {IPool} from '../../../interfaces/IPool.sol';
-import {IScaledBalanceToken} from '../../../interfaces/IScaledBalanceToken.sol';
+import {SafeCast} from './SafeCast.sol';
+import {Errors} from 'aave-v3-core/contracts/protocol/libraries/helpers/Errors.sol';
+import {WadRayMath} from 'aave-v3-core/contracts/protocol/libraries/math/WadRayMath.sol';
+import {IPool} from 'aave-v3-core/contracts/interfaces/IPool.sol';
+import {IScaledBalanceToken} from 'aave-v3-core/contracts/interfaces/IScaledBalanceToken.sol';
 import {MintableIncentivizedERC20} from './MintableIncentivizedERC20.sol';
 
 /**
@@ -78,7 +78,7 @@ abstract contract ScaledBalanceTokenBase is MintableIncentivizedERC20, IScaledBa
 
     _userState[onBehalfOf].additionalData = index.toUint128();
 
-    _mint(onBehalfOf, amountScaled.toUint128());
+    _mint(onBehalfOf, amountScaled.toUint120());
 
     uint256 amountToMint = amount + balanceIncrease;
     emit Transfer(address(0), onBehalfOf, amountToMint);
@@ -106,7 +106,7 @@ abstract contract ScaledBalanceTokenBase is MintableIncentivizedERC20, IScaledBa
 
     _userState[user].additionalData = index.toUint128();
 
-    _burn(user, amountScaled.toUint128());
+    _burn(user, amountScaled.toUint120());
 
     if (balanceIncrease > amount) {
       uint256 amountToMint = balanceIncrease - amount;
@@ -139,7 +139,7 @@ abstract contract ScaledBalanceTokenBase is MintableIncentivizedERC20, IScaledBa
     _userState[sender].additionalData = index.toUint128();
     _userState[recipient].additionalData = index.toUint128();
 
-    super._transfer(sender, recipient, amount.rayDiv(index).toUint128());
+    super._transfer(sender, recipient, amount.rayDiv(index).toUint120());
 
     if (senderBalanceIncrease > 0) {
       emit Transfer(address(0), sender, senderBalanceIncrease);
```
