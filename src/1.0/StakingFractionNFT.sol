// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract StakingFractionNFT is ERC20, Ownable, ReentrancyGuard {
  uint256 public constant MIN_STAKING_AMOUNT = 1000;
  uint256 public constant REWARDS_AMOUNT = 25000000;
  uint256 public constant LOCK_PERIOD = 12 * 30 days;

  mapping(address => uint256) public stakes;
  mapping(address => uint256) public rewards;
  
  constructor() ERC20("SoonanTsoorStaking", "RSNSR") {}

  function stake(uint256 _amount) public payable {
    require(msg.value >= MIN_STAKING_AMOUNT, "Staking amount must be at least 1000 WSNSR");
    require(rewards[msg.sender] == 0, "You already have staked and unlocked your rewards");

    stakes[msg.sender] = _amount;
    rewards[msg.sender] = block.timestamp + LOCK_PERIOD;
  }

  function claim() public payable {
    require(rewards[msg.sender] != 0 && rewards[msg.sender] <= block.timestamp, "You have not yet reached the lock period or already claimed the rewards");

    uint256 amount = REWARDS_AMOUNT * stakes[msg.sender] / MIN_STAKING_AMOUNT;
    payable(msg.sender).transfer(amount);

    stakes[msg.sender] = 0;
    rewards[msg.sender] = 0;
  }

  function totalSupply() public pure override returns (uint256) {
    return 0;
  }

  function balanceOf(address /*_owner*/) public pure override returns (uint256) {
    return 0;
  }

  function transfer(address /*_to*/, uint256 /*_value*/) public pure override returns (bool) {
    return false;
  }

  function approve(address /*_spender*/, uint256 /*_value*/) public pure override returns (bool) {
    return false;
  }

  function transferFrom(address /*_from*/, address /*_to*/, uint256 /*_value*/) public pure override returns (bool) {
    return false;
  }

  function allowance(address /*_owner*/, address /*_spender*/) public pure override returns (uint256) {
    return 0;
  }
}