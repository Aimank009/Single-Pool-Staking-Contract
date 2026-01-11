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

    struct UserInfo{
        uint256 amount;
        uint256 rewardDebt;
    }

    mapping(address => UserInfo) public users;

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

    function updatePool() public{

        if(block.timestamp<=lastUpdateTime){
            return;
        }

        if(totalStaked == 0){
            lastUpdateTime=block.timestamp;
            return;
        }

        uint256 timeElapsed = block.timestamp - lastUpdateTime;

        uint256 reward = timeElapsed *rewardRate;

        accRewardPerShare+= (reward*PRECISION)/totalStaked;
        lastUpdateTime = block.timestamp;
    }

    function stake(uint256 _amount) external override nonReentrant{

        require(_amount >0 ,"Stake amount should be greater than zero");

        updatePool();
        UserInfo storage user = users[msg.sender];

        if(user.amount>0){
            uint256 pending = (user.amount * accRewardPerShare)/PRECISION - user.rewardDebt;

            if(pending>0){
                require(rewardToken.transfer(msg.sender,pending),"Pending Transfer failder");

                emit Claimed(msg.sender, pending);
            }
        }

        require(stakingToken.transferFrom(msg.sender,address(this),_amount)," Stake Transfer Failed");

        user.amount+=_amount;
        totalStaked+=_amount;

        user.rewardDebt=(user.amount*accRewardPerShare)/PRECISION;

        emit Staked(msg.sender, _amount);

    }

    function withdraw(uint256 _amount) public override nonReentrant{
        require(_amount>0,"Withdraw amount cannot be less than 0");

        updatePool();

        UserInfo storage user = users[msg.sender];

        require(user.amount>=_amount,"Not enough staked");

        uint256 pending = (user.amount*accRewardPerShare)/PRECISION - user.rewardDebt;

        if(pending>0){
            require(rewardToken.transfer(msg.sender,pending),"Pending Transfer Failed");

            emit Claimed(msg.sender, pending);
        }

        user.amount-=_amount;
        totalStaked-=_amount;

        user.rewardDebt = (user.amount*accRewardPerShare)/PRECISION;
        require(stakingToken.transfer(msg.sender,_amount),"Withdraw Transfer Failed");

        emit Withdrawn(msg.sender, _amount);

    }

    function claim() external override{
        UserInfo storage user = users[msg.sender];

        uint256 pending = (user.amount*accRewardPerShare)/PRECISION -user.rewardDebt;

        require(pending>0,"No Rewwards to claim");

        user.rewardDebt=(user.amount*accRewardPerShare)/PRECISION;

        require(rewardToken.transfer(msg.sender,pending),"Claim Failed");

        emit Claimed(msg.sender, pending);
    }

    function exit() external override nonReentrant{

        UserInfo storage user = users[msg.sender];

        require(user.amount>0,"Nothing to exit");

        withdraw(user.amount);
    }

}
