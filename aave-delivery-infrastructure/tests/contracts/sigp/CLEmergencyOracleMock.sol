// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;


contract CLEmergencyOracleMock{
    int256 public answer;

    function setAnswer(int256 _answer) external {
        answer = _answer;

    }
    function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 ,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    ){
        return(0, answer, 0 , 0, 0 );
    } 

}