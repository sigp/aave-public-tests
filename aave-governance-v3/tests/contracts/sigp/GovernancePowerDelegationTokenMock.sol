pragma solidity ^0.8.0;



// SigP mock to GovernancePowerDelegationToken

contract GovernancePowerDelegationTokenMock  {

    uint256 public votingPower;
    uint256 public propositionPower;

    enum GovernancePowerType {
    VOTING,
    PROPOSITION
    }

    constructor(uint256 _votingPower, uint256 _propositionPower) {
        votingPower = _votingPower;
        propositionPower = _propositionPower;
    }
    function getPowerCurrent(address, GovernancePowerType powerType) external view returns(uint256) {
        if (powerType == GovernancePowerType.PROPOSITION) {return propositionPower;}
        if (powerType == GovernancePowerType.VOTING) {return votingPower;}
    }
} 