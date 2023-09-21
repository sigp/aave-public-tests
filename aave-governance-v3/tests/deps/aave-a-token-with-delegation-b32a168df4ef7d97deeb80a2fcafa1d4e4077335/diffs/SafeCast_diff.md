```diff
diff --git a/lib/aave-v3-core/contracts/dependencies/openzeppelin/contracts/SafeCast.sol b/src/contracts/SafeCast.sol
index 6d70809..d9c9f08 100644
--- a/lib/aave-v3-core/contracts/dependencies/openzeppelin/contracts/SafeCast.sol
+++ b/src/contracts/SafeCast.sol
@@ -1,6 +1,6 @@
 // SPDX-License-Identifier: MIT
 // OpenZeppelin Contracts v4.4.1 (utils/math/SafeCast.sol)
-pragma solidity 0.8.10;
+pragma solidity ^0.8.10;
 
 /**
  * @dev Wrappers over Solidity's uintXX/intXX casting operators with added overflow
@@ -33,6 +33,21 @@ library SafeCast {
     return uint224(value);
   }
 
+  /**
+   * @dev Returns the downcasted uint120 from uint256, reverting on
+   * overflow (when the input is greater than largest uint120).
+   *
+   * Counterpart to Solidity's `uint120` operator.
+   *
+   * Requirements:
+   *
+   * - input must fit into 120 bits
+   */
+  function toUint120(uint256 value) internal pure returns (uint120) {
+    require(value <= type(uint120).max, "SafeCast: value doesn't fit in 120 bits");
+    return uint120(value);
+  }
+
   /**
    * @dev Returns the downcasted uint128 from uint256, reverting on
    * overflow (when the input is greater than largest uint128).
```
