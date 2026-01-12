// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/SinglePoolStaking.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor(string memory n, string memory s) ERC20(n, s) {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract SinglePoolStakingTest is Test {
    SinglePoolStaking staking;
    MockToken stakeToken;
    MockToken rewardToken;

    address alice = address(1);
    address bob = address(2);
    address owner = address(this);

    function setUp() public {
        stakeToken = new MockToken("Stake", "STK");
        rewardToken = new MockToken("Reward", "RWD");

        staking = new SinglePoolStaking(
            address(stakeToken),
            address(rewardToken),
            1e18
        );

        stakeToken.mint(alice, 1000e18);
        stakeToken.mint(bob, 1000e18);
        rewardToken.mint(address(this), 100000e18);

        rewardToken.approve(address(staking), type(uint256).max);
        staking.fundRewards(100000e18);

        vm.startPrank(alice);
        stakeToken.approve(address(staking), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        stakeToken.approve(address(staking), type(uint256).max);
        vm.stopPrank();
    }

    function testStake() public {
        vm.prank(alice);
        staking.stake(100e18);
        assertEq(staking.balanceOf(alice), 100e18);
        assertEq(staking.totalStakedAmount(), 100e18);
    }

    function testWithdraw() public {
        vm.prank(alice);
        staking.stake(100e18);
        vm.prank(alice);
        staking.withdraw(50e18);
        assertEq(staking.balanceOf(alice), 50e18);
        assertEq(staking.totalStakedAmount(), 50e18);
    }

    function testClaim() public {
        vm.prank(alice);
        staking.stake(100e18);
        vm.warp(block.timestamp + 10);
        vm.prank(alice);
        staking.claim();
        assertGt(rewardToken.balanceOf(alice), 0);
    }

    function testExit() public {
        vm.prank(alice);
        staking.stake(100e18);
        vm.warp(block.timestamp + 10);
        vm.prank(alice);
        staking.exit();
        assertEq(staking.balanceOf(alice), 0);
    }

    function testEmergencyWithdraw() public {
        vm.prank(alice);
        staking.stake(100e18);
        vm.prank(alice);
        staking.emergencyWithdraw();
        assertEq(staking.balanceOf(alice), 0);
    }

    function testMultipleUsers() public {
        vm.prank(alice);
        staking.stake(100e18);
        vm.prank(bob);
        staking.stake(100e18);
        vm.warp(block.timestamp + 10);
        vm.prank(alice);
        staking.claim();
        vm.prank(bob);
        staking.claim();
        assertGt(rewardToken.balanceOf(alice), 0);
        assertGt(rewardToken.balanceOf(bob), 0);
    }

    function testPendingRewards() public {
        vm.prank(alice);
        staking.stake(100e18);
        vm.warp(block.timestamp + 10);
        uint256 pending = staking.pendingRewards(alice);
        assertGt(pending, 0);
    }

    function testPause() public {
        staking.pause();
        vm.prank(alice);
        vm.expectRevert();
        staking.stake(100e18);
    }

    function testUnpause() public {
        staking.pause();
        staking.unpause();
        vm.prank(alice);
        staking.stake(100e18);
        assertEq(staking.balanceOf(alice), 100e18);
    }

    function testOnlyOwnerPause() public {
        vm.prank(alice);
        vm.expectRevert();
        staking.pause();
    }

    function testRewardRateUpdate() public {
        staking.setRewardRate(2e18);
        assertEq(staking.rewardRate(), 2e18);
    }

    function testFundRewards() public {
        uint256 before = rewardToken.balanceOf(address(staking));
        rewardToken.mint(address(this), 100e18);
        rewardToken.approve(address(staking), 100e18);
        staking.fundRewards(100e18);
        uint256 afterBal = rewardToken.balanceOf(address(staking));
        assertEq(afterBal, before + 100e18);
    }

    function testRevertZeroStake() public {
        vm.prank(alice);
        vm.expectRevert();
        staking.stake(0);
    }

    function testRevertZeroWithdraw() public {
        vm.prank(alice);
        vm.expectRevert();
        staking.withdraw(0);
    }

    function testRevertNoRewardsClaim() public {
        vm.prank(alice);
        vm.expectRevert();
        staking.claim();
    }

    function testTotalStaked() public {
        vm.prank(alice);
        staking.stake(100e18);
        vm.prank(bob);
        staking.stake(50e18);
        assertEq(staking.totalStakedAmount(), 150e18);
    }
}
