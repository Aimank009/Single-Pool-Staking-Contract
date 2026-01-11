// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IStaking{

    function stake(uint256 _amount) external;
    function withdraw(uint256 _amount) external;

    function claim() external;
    function exit() external;
    function emergencyWithdraw() external;

    function pendingRewards(address _user) external view returns (uint256);
    function balanceOf(address _user) external view returns (uint256);
    function totalStaked() external view returns (uint256);
}