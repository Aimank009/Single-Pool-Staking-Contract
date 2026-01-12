// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IStaking.sol";
import "./events/StakingEvents.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract SinglePoolStaking is
    IStaking,
    StakingEvents,
    Ownable,
    ReentrancyGuard,
    Pausable
{
    IERC20 public stakingToken;
    IERC20 public rewardToken;

    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public accRewardPerShare;
    uint256 public totalStaked;

    uint256 public constant PRECISION = 1e18;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    mapping(address => UserInfo) public users;

    constructor(
        address _stakingToken,
        address _rewardToken,
        uint256 _rewardRate
    ) Ownable(msg.sender) {
        require(_stakingToken != address(0), "Invalid staking token");
        require(_rewardToken != address(0), "Invalid reward token");
        require(_rewardRate > 0, "Invalid reward rate");

        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        rewardRate = _rewardRate;

        lastUpdateTime = block.timestamp;
    }

    function updatePool() public {
        if (block.timestamp <= lastUpdateTime) return;

        if (totalStaked == 0) {
            lastUpdateTime = block.timestamp;
            return;
        }

        uint256 timeElapsed = block.timestamp - lastUpdateTime;
        uint256 reward = timeElapsed * rewardRate;

        accRewardPerShare += (reward * PRECISION) / totalStaked;
        lastUpdateTime = block.timestamp;
    }

    function stake(
        uint256 _amount
    ) external override nonReentrant whenNotPaused {
        require(_amount > 0, "Invalid amount");

        updatePool();

        UserInfo storage user = users[msg.sender];

        if (user.amount > 0) {
            _claim(msg.sender);
        }

        require(
            stakingToken.transferFrom(msg.sender, address(this), _amount),
            "Stake transfer failed"
        );

        user.amount += _amount;
        totalStaked += _amount;

        user.rewardDebt = (user.amount * accRewardPerShare) / PRECISION;

        emit Staked(msg.sender, _amount);
    }

    function withdraw(
        uint256 _amount
    ) public override nonReentrant whenNotPaused {
        _withdraw(msg.sender, _amount);
    }

    function _withdraw(address _user, uint256 _amount) internal {
        require(_amount > 0, "Invalid amount");

        updatePool();

        UserInfo storage user = users[_user];
        require(user.amount >= _amount, "Not enough staked");

        _claim(_user);

        user.amount -= _amount;
        totalStaked -= _amount;

        user.rewardDebt = (user.amount * accRewardPerShare) / PRECISION;

        require(stakingToken.transfer(_user, _amount), "Withdraw failed");

        emit Withdrawn(_user, _amount);
    }

    function claim() external override nonReentrant {
        updatePool();

        UserInfo storage user = users[msg.sender];
        uint256 pending = (user.amount * accRewardPerShare) /
            PRECISION -
            user.rewardDebt;

        require(pending > 0, "No rewards");

        user.rewardDebt = (user.amount * accRewardPerShare) / PRECISION;

        require(
            rewardToken.transfer(msg.sender, pending),
            "Reward transfer failed"
        );

        emit Claimed(msg.sender, pending);
    }

    function _claim(address _user) internal {
        UserInfo storage user = users[_user];

        uint256 pending = (user.amount * accRewardPerShare) /
            PRECISION -
            user.rewardDebt;

        if (pending == 0) return;

        require(
            rewardToken.balanceOf(address(this)) >= pending,
            "Insufficient rewards"
        );

        user.rewardDebt = (user.amount * accRewardPerShare) / PRECISION;

        require(rewardToken.transfer(_user, pending), "Reward transfer failed");

        emit Claimed(_user, pending);
    }

    function exit() external override nonReentrant whenNotPaused {
        UserInfo storage user = users[msg.sender];
        require(user.amount > 0, "Nothing to exit");

        uint256 amount = user.amount;

        updatePool();

        uint256 pending = (user.amount * accRewardPerShare) /
            PRECISION -
            user.rewardDebt;

        user.amount = 0;
        user.rewardDebt = 0;
        totalStaked -= amount;

        if (pending > 0) {
            require(
                rewardToken.balanceOf(address(this)) >= pending,
                "Insufficient rewards"
            );
            rewardToken.transfer(msg.sender, pending);
        }

        stakingToken.transfer(msg.sender, amount);

        emit Exit(msg.sender, amount, pending);
    }

    function emergencyWithdraw() external override nonReentrant {
        UserInfo storage user = users[msg.sender];
        uint256 amount = user.amount;

        require(amount > 0, "Nothing to withdraw");

        user.amount = 0;
        user.rewardDebt = 0;
        totalStaked -= amount;

        stakingToken.transfer(msg.sender, amount);

        emit EmergencyWithdraw(msg.sender, amount);
    }

    function pendingRewards(
        address _user
    ) public view override returns (uint256) {
        UserInfo storage user = users[_user];
        uint256 tempAcc = accRewardPerShare;

        if (block.timestamp > lastUpdateTime && totalStaked > 0) {
            uint256 timeElapsed = block.timestamp - lastUpdateTime;
            uint256 reward = timeElapsed * rewardRate;
            tempAcc += (reward * PRECISION) / totalStaked;
        }

        return (user.amount * tempAcc) / PRECISION - user.rewardDebt;
    }

    function balanceOf(address _user) external view override returns (uint256) {
        return users[_user].amount;
    }

    function totalStakedAmount() external view override returns (uint256) {
        return totalStaked;
    }

    function fundRewards(uint256 amount) external onlyOwner {
        require(amount > 0, "Invalid amount");

        require(
            rewardToken.transferFrom(msg.sender, address(this), amount),
            "Funding failed"
        );

        emit RewardsFunded(msg.sender, amount);
    }

    function setRewardRate(uint256 _newRate) external onlyOwner {
        require(_newRate > 0, "Invalid rate");

        uint256 old = rewardRate;
        rewardRate = _newRate;

        emit RewardRateUpdated(old, _newRate);
    }

    function pause() external onlyOwner {
        _pause();
        emit PoolPaused(msg.sender);
    }

    function unpause() external onlyOwner {
        _unpause();
        emit PoolUnpaused(msg.sender);
    }
}
