```diff
diff --git a/lib/aave-v3-core/contracts/protocol/tokenization/AToken.sol b/src/contracts/AToken.sol
index 57f3b16..5959f33 100644
--- a/lib/aave-v3-core/contracts/protocol/tokenization/AToken.sol
+++ b/src/contracts/AToken.sol
@@ -1,19 +1,19 @@
-// SPDX-License-Identifier: BUSL-1.1
-pragma solidity 0.8.10;
+// SPDX-License-Identifier: MIT
+pragma solidity ^0.8.10;
 
-import {IERC20} from '../../dependencies/openzeppelin/contracts/IERC20.sol';
-import {GPv2SafeERC20} from '../../dependencies/gnosis/contracts/GPv2SafeERC20.sol';
-import {SafeCast} from '../../dependencies/openzeppelin/contracts/SafeCast.sol';
-import {VersionedInitializable} from '../libraries/aave-upgradeability/VersionedInitializable.sol';
-import {Errors} from '../libraries/helpers/Errors.sol';
-import {WadRayMath} from '../libraries/math/WadRayMath.sol';
-import {IPool} from '../../interfaces/IPool.sol';
-import {IAToken} from '../../interfaces/IAToken.sol';
-import {IAaveIncentivesController} from '../../interfaces/IAaveIncentivesController.sol';
-import {IInitializableAToken} from '../../interfaces/IInitializableAToken.sol';
-import {ScaledBalanceTokenBase} from './base/ScaledBalanceTokenBase.sol';
-import {IncentivizedERC20} from './base/IncentivizedERC20.sol';
-import {EIP712Base} from './base/EIP712Base.sol';
+import {IERC20} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
+import {GPv2SafeERC20} from 'aave-v3-core/contracts/dependencies/gnosis/contracts/GPv2SafeERC20.sol';
+import {SafeCast} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/SafeCast.sol';
+import {VersionedInitializable} from 'aave-v3-core/contracts/protocol/libraries/aave-upgradeability/VersionedInitializable.sol';
+import {Errors} from 'aave-v3-core/contracts/protocol/libraries/helpers/Errors.sol';
+import {WadRayMath} from 'aave-v3-core/contracts/protocol/libraries/math/WadRayMath.sol';
+import {IPool} from 'aave-v3-core/contracts/interfaces/IPool.sol';
+import {IAToken} from 'aave-v3-core/contracts/interfaces/IAToken.sol';
+import {IAaveIncentivesController} from 'aave-v3-core/contracts/interfaces/IAaveIncentivesController.sol';
+import {IInitializableAToken} from 'aave-v3-core/contracts/interfaces/IInitializableAToken.sol';
+import {ScaledBalanceTokenBase} from './ScaledBalanceTokenBase.sol';
+import {IncentivizedERC20} from './IncentivizedERC20.sol';
+import {EIP712Base} from 'aave-v3-core/contracts/protocol/tokenization/base/EIP712Base.sol';
 
 /**
  * @title Aave ERC20 AToken
@@ -223,7 +223,7 @@ contract AToken is VersionedInitializable, ScaledBalanceTokenBase, EIP712Base, I
    * @param to The destination address
    * @param amount The amount getting transferred
    */
-  function _transfer(address from, address to, uint128 amount) internal virtual override {
+  function _transfer(address from, address to, uint120 amount) internal virtual override {
     _transfer(from, to, amount, true);
   }
 
```
