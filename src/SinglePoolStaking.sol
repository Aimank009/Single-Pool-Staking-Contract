// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IStaking.sol";
import "./events/StakingEvents.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract SinglePoolStaking is IStaking,StakingEvents,Ownable,ReentrancyGuard{
    
    IERC20 public stakingToken;
    IERC20 public rewardToken;

    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public accRewardPerShare;
    uint256 public totalStaked;

    uint256 public constant PRECISION = 1e18;

    struct USerInfo{
        uint256 amount;
        uint256 rewardDebt;
    }

    mapping(address => USerInfo) public users;

    constructor(
        address _stakingToken,
        address _rewardToken,
        uint256 _rewardRate
    ) Ownable(msg.sender){

        require(_stakingToken!=address(0),"Staking Token Addres cannot be null");
        require(_rewardToken!=address(0),"Reward Token Addres cannot be null");
        require(_rewardRate>0,"Reward Rate should be greater than 0");

        stakingToken=IERC20(_stakingToken);
        rewardToken=IERC20(_rewardToken);
        rewardRate=_rewardRate;

        lastUpdateTime=block.timestamp;

    }

}
