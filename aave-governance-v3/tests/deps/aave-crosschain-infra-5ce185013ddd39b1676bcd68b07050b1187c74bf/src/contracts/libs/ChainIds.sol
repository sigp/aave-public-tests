// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library MainnetChainIds {
  uint256 constant ETHEREUM = 1;
  uint256 constant POLYGON = 137;
  uint256 constant AVALANCHE = 43114;
  uint256 constant ARBITRUM = 42161;
  uint256 constant OPTIMISM = 10;
  uint256 constant FANTOM = 250;
  uint256 constant HARMONY = 1666600000;
}

library TestnetChainIds {
  uint256 constant ETHEREUM_GOERLI = 5;
  uint256 constant POLYGON_MUMBAI = 80001;
  uint256 constant AVALANCHE_FUJI = 43113;
  uint256 constant ARBITRUM_GOERLI = 421613;
  uint256 constant OPTIMISM_GOERLI = 420;
  uint256 constant FANTOM_TESTNET = 4002;
  uint256 constant HARMONY_TESTNET = 1666700000;
  uint256 constant ETHEREUM_SEPOLIA = 11155111;
}
