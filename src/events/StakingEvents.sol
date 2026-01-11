// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

abstract contract StakingEvents{

    event Staked(address indexed _user,uint256 _amount);
    event Withdrawn(address indexed _user,uint256 _amount);
    event Claimed(address indexed _user,uint256 _amount);
    event EmergencyWithdraw(address indexed _user,uint256 _amount);
    event Exit(address indexed _user, uint256 _amount, uint256 _reward);

    event RewardRateUpdated(uint256 _oldRate, uint256 _newRate);
    event RewardsFunded(address indexed _funder,uint256 _amount);
    event Paused(address indexed _admin);
    event Unpaused(address indexed _admin);

}