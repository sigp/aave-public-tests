pragma solidity ^0.8.0;


// SigP mock for powerStrategy used in GovernanceCore.sol
contract MockPowerStrategy {
    uint256 public fullPropositionPower;

    function AAVE() public pure virtual returns (address) {
    return 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;
  }

  function STK_AAVE() public pure virtual returns (address) {
    return 0x4da27a545c0c5B758a6BA100e3a049001de870f5;
  }

  function A_AAVE() public pure virtual returns (address) {
    return 0xA700b4eB416Be35b2911fd5Dee80678ff64fF6C9;
  }
    function getFullPropositionPower(address) external view returns(uint256) {
        return fullPropositionPower;
    }

    function setFullPropositionPower( uint256 newfullPropositionPower) external {
        fullPropositionPower = newfullPropositionPower;
    }

    function getVotingAssetList() public pure returns (address[] memory) {
    address[] memory votingAssets = new address[](3);

    votingAssets[0] = AAVE();
    votingAssets[1] = STK_AAVE();
    votingAssets[2] = A_AAVE();

    return votingAssets;
    }
    function isTokenSlotAccepted(address, uint128) external pure returns(bool){
      return true;
  }
}