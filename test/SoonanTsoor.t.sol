// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {FractionManager} from "../src/1.0/FractionManager.sol";
import {FractionToken} from "../src/1.0/FractionToken.sol";
import {SoonanTsoorStudio} from "../src/1.0/SoonanTsoorStudio.sol";
import {SoonanTsoorVilla} from "../src/1.0/SoonanTsoorVilla.sol";
import {StakingManager} from "../src/1.0/StakingManager.sol";
import {StakingToken} from "../src/1.0/StakingToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/v0.8/interfaces/AggregatorV3Interface.sol";

contract SoonanTsoorTest is Test {
  FractionManager fractionManager;
  FractionToken fractionToken;
  SoonanTsoorStudio studioNFT;
  SoonanTsoorVilla villaNFT;
  StakingManager stakingManager;
  StakingToken stakingToken;
  AggregatorV3Interface _priceFeed;
  IERC20 _usdcToken;
  
  address[] private addresses =
    [address(0x123), address(0x234), address(0x456), address(0x567), address(0x678)];
  address addr6 = address(0x789);
  address usdc = address(0xE097d6B3100777DC31B34dC2c58fB524C2e76921);
  address feed = address(0x572dDec9087154dC5dfBB1546Bb62713147e0Ab0);

  function setUp() public {
    fractionToken = new FractionToken();
    fractionManager = new FractionManager(address(fractionToken), usdc, feed);
    studioNFT = new SoonanTsoorStudio(usdc, feed, address(fractionManager));
    villaNFT = new SoonanTsoorVilla(usdc, feed);
    stakingToken = new StakingToken();
    stakingManager = new StakingManager(
            address(villaNFT),
            address(studioNFT),
            address(stakingToken),
            54_666_666_666_666_666_667,
            13_666_666_666_666_667,
            31_536_000
        );

    vm.roll(1);
  }

  function testCheckBalanceStudio() internal {
    assertEq(studioNFT.balanceOf(address(this)), 5000, "studio not equal to 5000");
  }

//   /// @notice check whether tokenId already deposited
//   function isTokenIdDeposited(address account, uint256 tokenId) internal view returns (bool) {
//     uint256[] memory depositedTokenIds = stakingManager.depositsOf(account);

//     for (uint256 i = 0; i < depositedTokenIds.length; i++) {
//       if (depositedTokenIds[i] == tokenId) {
//         return true;
//       }
//     }

//     return false;
//   }

//   function testDeposit() public {
//     uint256[] memory tokenIds = new uint256[](3);
//     tokenIds[0] = 1;
//     tokenIds[1] = 2;
//     tokenIds[2] = 3;
//     vm.prank(address(this));
//     stakingManager.unpause();

//     vm.startPrank(addr1, addr1);
//     vm.deal(addr1, tokenPrice);
//     mintAndApprove(1, 5);
//     stakingManager.deposit(tokenIds);

//     for (uint256 i = 0; i < tokenIds.length; i++) {
//       assertTrue(isTokenIdDeposited(addr1, tokenIds[i]), "Token should be deposited");
//     }
//     vm.stopPrank();
//   }

//   function testCalculateReward() public {
//     uint256[] memory tokenIds = new uint256[](3);
//     tokenIds[0] = 1;
//     tokenIds[1] = 2;
//     tokenIds[2] = 3;
//     vm.prank(address(this));
//     stakingManager.unpause();

//     vm.startPrank(addr1, addr1);
//     vm.deal(addr1, tokenPrice);
//     mintAndApprove(1, 5);
//     stakingManager.deposit(tokenIds);

//     vm.roll(block.number + 100);

//     uint256 expectedReward = 100 * 1_666_666_666_666_666;
//     uint256 reward = stakingManager.calculateReward(addr1, tokenIds[0]);
//     vm.stopPrank();
//     assertEq(reward, expectedReward, "Calculated reward should match the expected reward");
//   }

//   function testClaimRewards() public {
//     uint256[] memory tokenIds = new uint256[](3);
//     tokenIds[0] = 1;
//     tokenIds[1] = 2;
//     tokenIds[2] = 3;
//     vm.prank(address(this));
//     stakingManager.unpause();

//     vm.startPrank(addr1, addr1);
//     vm.deal(addr1, tokenPrice);
//     mintAndApprove(1, 5);
//     stakingManager.deposit(tokenIds);
//     assertEq(3, presaleNFT.balanceOf(address(stakingManager)), "Balance not greater than zero");

//     vm.roll(block.number + 100);

//     uint256 initialBalance = stakingToken.balanceOf(addr1);
//     stakingManager.claimRewards(tokenIds);
//     uint256 finalBalance = stakingToken.balanceOf(addr1);

//     uint256 expectedReward = 100 * 1_666_666_666_666_666 * 3;
//     uint256 claimedReward = finalBalance - initialBalance;
//     vm.stopPrank();
//     assertEq(claimedReward, expectedReward, "Claimed reward should match the expected reward");
//   }

//   function testWithdraw() public {
//     uint256[] memory tokenIds = new uint256[](3);
//     tokenIds[0] = 1;
//     tokenIds[1] = 2;
//     tokenIds[2] = 3;
//     vm.prank(address(this));
//     stakingManager.unpause();

//     vm.startPrank(addr1, addr1);
//     vm.deal(addr1, tokenPrice);
//     mintAndApprove(1, 5);
//     stakingManager.deposit(tokenIds);

//     vm.roll(block.number + 100);

//     stakingManager.withdraw(tokenIds);
//     for (uint256 i = 0; i < tokenIds.length; i++) {
//       assertEq(presaleNFT.ownerOf(tokenIds[i]), addr1);
//       assertFalse(isTokenIdDeposited(addr1, tokenIds[i]));
//     }
//     vm.stopPrank();
//   }
}
