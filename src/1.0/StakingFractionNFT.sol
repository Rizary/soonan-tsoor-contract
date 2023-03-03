// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {FractionToken} from "./FractionToken.sol";

contract StakingFractionNFT is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct Stake {
        uint256 amount;
        uint256 timestamp;
        uint256 claimedRewards;
    }

    FractionToken public wsnsr;

    uint256 public constant STAKE_DURATION = 365 days;

    uint256 public totalStaked;
    uint256 public totalClaimedRewards;
    uint256 public totalIncome;
    uint256 public totalIncomePercentage;

    mapping(address => Stake) public stakes;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);

    constructor(address _wsnsr) ERC20("Rewards Token", "WSNSR") {
        wsnsr = FractionToken(_wsnsr);
        totalStaked = 0;
        totalClaimedRewards = 0;
        totalIncome = 0;
        totalIncomePercentage = 0;
    }

    function stake(uint256 amount) external nonReentrant {
        require(amount >= 1000, "Staking: Minimum stake amount is 1000");
        require(wsnsr.balanceOf(msg.sender) >= amount, "Staking: Insufficient balance");
        require(wsnsr.allowance(msg.sender, address(this)) >= amount, "Staking: Insufficient allowance");

        if (stakes[msg.sender].amount == 0) {
            stakes[msg.sender].timestamp = block.timestamp;
        } else {
            uint256 reward = calculateRewards(msg.sender);
            if (reward > 0) {
                stakes[msg.sender].claimedRewards += reward;
                totalClaimedRewards += reward;
                super._mint(msg.sender, reward);
                emit Claimed(msg.sender, reward);
            }
        }

        wsnsr.transferFrom(msg.sender, address(this), amount);
        stakes[msg.sender].amount += amount;
        totalStaked += amount;
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external nonReentrant {
        require(amount > 0, "Staking: Amount must be greater than 0");
        require(stakes[msg.sender].amount >= amount, "Staking: Insufficient staked amount");

        uint256 reward = calculateRewards(msg.sender);
        if (reward > 0) {
            stakes[msg.sender].claimedRewards += reward;
            totalClaimedRewards += reward;
            super._mint(msg.sender, reward);
            emit Claimed(msg.sender, reward);
        }

        wsnsr.transfer(msg.sender, amount);
        stakes[msg.sender].amount -= amount;
        totalStaked -= amount;
        emit Unstaked(msg.sender, amount);
    }
    
    function calculateRewards(address account) public view returns (uint256) {
        Stake memory staker = stakes[account];
        if ( 
            staker.amount == 0  ||
            block.timestamp < staker.timestamp.add(STAKE_DURATION)
        ) {
            return 0;
        }

        uint256 timeDiff = block.timestamp.sub(staker.timestamp);
        uint256 rewardPercentage = timeDiff.mul(100).div(STAKE_DURATION);
        uint256 rewardAmount = staker.amount.mul(rewardPercentage).div(100);

        return rewardAmount;
    }

    function claimReward() external nonReentrant {
        Stake storage staker = stakes[msg.sender];
        require(staker.amount > 0, "You have no stake.");
        require(block.timestamp >= staker.timestamp.add(STAKE_DURATION), "It is not yet time to claim your reward.");

        uint256 rewardAmount = calculateRewards(msg.sender);
        require(rewardAmount > 0, "Your reward is 0.");

        super._mint(msg.sender, rewardAmount);
        staker.claimedRewards = staker.claimedRewards.add(rewardAmount);

        emit RewardClaimed(msg.sender, rewardAmount);
    }

    function setTotalIncome(uint256 amount) external onlyOwner {
        totalIncome = amount;
    }

    function totalEverClaimedRewards(address account) public view returns (uint256) {
        return stakes[account].claimedRewards;
    }


    function getTotalIncome(address account) public view returns (uint256) {
        Stake memory staker = stakes[account];
        uint256 timeDiff = block.timestamp.sub(staker.timestamp);
        uint256 stakerRewardPercentage = timeDiff.mul(100).div(STAKE_DURATION);

        if (stakerRewardPercentage > 100) {
            stakerRewardPercentage = 100;
        }

        uint256 stakerReward = staker.amount.mul(stakerRewardPercentage).div(100);
        uint256 claimedRewards = stakes[account].claimedRewards;

        return claimedRewards.add(stakerReward);
    }
}