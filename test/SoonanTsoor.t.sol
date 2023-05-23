// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

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

    uint256 public totalFractions;
    uint256 public totalFractionSold;
    mapping(address => mapping(uint256 => uint256)) private _fractionOwnership;

    address[] private addresses = [address(0x123), address(0x234), address(0x456), address(0x567), address(0x678)];
    uint256[] private tokenIds = [4, 5];
    address addr6 = address(0x789);
    address usdc = address(0xE097d6B3100777DC31B34dC2c58fB524C2e76921);
    address feed = address(0x572dDec9087154dC5dfBB1546Bb62713147e0Ab0);
    address devWallet = address(0x5FE49cb77be19D1970dd9b0971086A8fFFAe66E4);
    address ONCHAIN = address(0x91011);
    address OFFCHAIN = address(0x101112);

    function setUp() public {
        fractionToken = new FractionToken();
        fractionManager = new FractionManager(address(fractionToken), usdc, feed);
        fractionToken.setMaxSupply(fractionManager.totalFractions());
        fractionToken.unpause();
        fractionToken.mint(address(fractionManager), fractionManager.totalFractions());
        fractionToken.pause();
        studioNFT = new SoonanTsoorStudio(usdc, feed, address(fractionManager));
        villaNFT = new SoonanTsoorVilla(usdc, feed);
        _usdcToken = IERC20(usdc);
        stakingToken = new StakingToken();
        stakingManager = new StakingManager(
            address(villaNFT),
            address(studioNFT),
            address(stakingToken),
            10_425_133_181_126_332,
            2_600_202_942_669,
            31_536_000
        );
        villaNFT.enablePublicMinting();
        deal(usdc, addresses[2], 0);
        deal(usdc, ONCHAIN, 0);
        deal(usdc, OFFCHAIN, 0);
        vm.roll(1);
    }

    function test_CheckBalances() public {
        assertEq(studioNFT.balanceOf(address(fractionManager)), 5000, "studio not equal to 5000");
        assertEq(
            fractionToken.balanceOf(address(fractionManager)),
            fractionManager.totalFractions(),
            "fraction not equal to 500000000000000"
        );
    }

    //
    //  TEST VILLANFT
    //
    function test_PublicMint() public {
        uint256 currPrice = villaNFT.getCurrentPrice();
        uint256 mintAmount = 2;
        uint256 allowance = currPrice * mintAmount;
        vm.startPrank(addresses[2], addresses[2]);
        deal(usdc, addresses[2], allowance);
        _usdcToken.approve(address(villaNFT), allowance);

        villaNFT.publicMint(mintAmount);
        vm.stopPrank();

        assertEq(2, villaNFT.balanceOf(addresses[2]));
    }

    function test_PublicMint_When_Bot() public {
        uint256 price = villaNFT.getCurrentPrice();

        vm.prank(addresses[0], addresses[1]);
        deal(usdc, addresses[2], price * 2);
        _usdcToken.approve(address(villaNFT), price * 2);
        try villaNFT.publicMint(3) {
            fail("public mint should failed");
        } catch Error(string memory reason) {
            assertEq(reason, "public: bot is not allowed");
        }
    }

    function test_PublicMint_When_WrongPrice() public {
        uint256 currPrice = villaNFT.getCurrentPrice();
        uint256 allowance = currPrice * 1;
        vm.startPrank(addresses[2], addresses[2]);
        deal(usdc, addresses[2], allowance);
        _usdcToken.approve(address(villaNFT), allowance);

        try villaNFT.publicMint(3) {
            fail("public mint should failed");
        } catch Error(string memory reason) {
            assertEq(reason, "transferIn: insufficient allowance");
        }
        vm.stopPrank();
    }

    function test_Presale_Mint() public {
        villaNFT.setAux(address(0x123), 5);
        villaNFT.setAux(address(0x234), 4);
        villaNFT.setAux(address(0x456), 3);
        villaNFT.setAux(address(0x567), 2);
        villaNFT.setAux(address(0x678), 5);

        uint256 currPrice = villaNFT.getCurrentPrice();
        uint256 presaleAmount = 2;
        uint256 allowance = currPrice * presaleAmount;

        villaNFT.disablePublicMinting();

        vm.startPrank(addresses[2], addresses[2]);
        deal(usdc, addresses[2], allowance);
        _usdcToken.approve(address(villaNFT), allowance);

        villaNFT.presale(presaleAmount);

        assertEq(villaNFT.balanceOf(addresses[2]), 2);
        assertEq(villaNFT.getAux(addresses[2]), 1);

        deal(addresses[2], currPrice);

        try villaNFT.presale{value: currPrice}(2) {
            fail("presale mint should failed");
        } catch Error(string memory reason) {
            assertEq(reason, "presale: cannot minted more than allowed");
        }
        vm.stopPrank();
    }

    function test_PresaleMint_When_Bot() public {
        villaNFT.setAux(address(0x123), 5);
        villaNFT.setAux(address(0x234), 4);
        villaNFT.setAux(address(0x456), 3);
        villaNFT.setAux(address(0x567), 2);
        villaNFT.setAux(address(0x678), 5);

        uint256 currPrice = villaNFT.getCurrentPrice();
        uint256 presaleAmount = 3;
        uint256 allowance = currPrice * presaleAmount;

        villaNFT.disablePublicMinting();

        vm.startPrank(addresses[2], addresses[1]);
        deal(addresses[2], allowance);

        try villaNFT.presale{value: allowance}(2) {
            fail("presale mint should failed");
        } catch Error(string memory reason) {
            assertEq(reason, "presale: bot is not allowed");
        }
        vm.stopPrank();
    }

    function test_PresaleMint_When_WrongPrice() public {
        villaNFT.setAux(address(0x123), 5);
        villaNFT.setAux(address(0x234), 4);
        villaNFT.setAux(address(0x456), 3);
        villaNFT.setAux(address(0x567), 2);
        villaNFT.setAux(address(0x678), 5);

        uint256 currPrice = villaNFT.getCurrentPrice();
        uint256 allowance = currPrice * 1;

        villaNFT.disablePublicMinting();

        vm.startPrank(addresses[2], addresses[2]);
        deal(usdc, addresses[2], allowance);
        _usdcToken.approve(address(villaNFT), allowance);

        try villaNFT.presale(2) {
            fail("presale mint should failed");
        } catch Error(string memory reason) {
            assertEq(reason, "transferIn: insufficient allowance");
        }
        vm.stopPrank();
    }

    function test_Distribution() public {
        uint256 currPrice = villaNFT.getCurrentPrice();
        uint256 mintAmount = 2;
        uint256 allowance = currPrice * mintAmount;
        villaNFT.setTeamWalletW2(ONCHAIN);
        villaNFT.setTeamWalletW3(OFFCHAIN);
        deal(usdc, addresses[2], 0);
        deal(usdc, ONCHAIN, 0);
        deal(usdc, OFFCHAIN, 0);

        vm.startPrank(addresses[2], addresses[2]);
        deal(usdc, addresses[2], allowance);
        _usdcToken.approve(address(villaNFT), allowance);

        assertGt(currPrice, 0);
        assertEq(_usdcToken.balanceOf(addresses[2]), allowance, "Total allowance is incorrect");

        villaNFT.publicMint(mintAmount);

        assertEq(_usdcToken.balanceOf(OFFCHAIN) + _usdcToken.balanceOf(ONCHAIN), allowance, "total balance incorrect");
        vm.stopPrank();
    }

    function testOwnerMint() public {
        uint256 mintAmount = 2;

        villaNFT.ownerMint(addr6, mintAmount);

        assertEq(2, villaNFT.balanceOf(addr6));
    }

    function test_OwnerMint_When_NotOwner() public {
        uint256 mintAmount = 2;
        vm.prank(addr6, addr6);

        try villaNFT.ownerMint(addr6, mintAmount) {
            fail("presale mint should failed");
        } catch Error(string memory reason) {
            assertEq(reason, "Ownable: caller is not the owner");
        }
    }

    function testURI() public {
        uint256 mintAmount = 2;
        villaNFT.ownerMint(addr6, mintAmount);
        villaNFT.setBaseURI("https://soonantsoor.com/");
        villaNFT.setURIExtention(".json1");

        assertEq("https://soonantsoor.com/1.json1", villaNFT.tokenURI(1));

        villaNFT.setURIExtention(".json");

        assertEq("https://soonantsoor.com/2.json", villaNFT.tokenURI(2));
    }

    //
    //  TEST FRACTION MANAGER
    //
    function test_fractionActivity() public {
        uint256 currPrice = fractionManager.getCurrentPrice();
        uint256 mintAmount = 500;
        uint256 allowance = currPrice * 1_000_000;
        fractionToken.unpause();
        vm.startPrank(addresses[2], addresses[2]);
        deal(usdc, addresses[2], allowance);
        _usdcToken.approve(address(fractionManager), allowance);
        assertEq(fractionManager.availableFracByTokenId(5), 1000, "tokenID 4 not equal to 1000");
        fractionManager.buyFraction(4, mintAmount);

        assertEq(500, fractionToken.balanceOf(addresses[2]));
        assertFalse(fractionManager.isRightFullOwner(addresses[2], 4));
        fractionManager.buyFraction(4, mintAmount);
        assertTrue(fractionManager.isRightFullOwner(addresses[2], 4));
        assertEq(fractionManager.fractByTokenId(addresses[2], 4), 1000);
        fractionManager.buyFraction(5, mintAmount);
        assertEq(fractionManager.availableFracByTokenId(5), 500, "tokenID 5 not equal to 500");
        assertEq(fractionManager.availableFracByTokenId(4), 0, "tokenId 4 not equal to 0");
        assertEq(fractionManager.tokenIdSharedByAddress(addresses[2]), tokenIds);
        fractionManager.redeemFraction(6, mintAmount);
        assertEq(fractionManager.fractByTokenId(addresses[2], 6), 500, "tokenId 6 not equal to 500");
        fractionManager.transferFraction(4, 500, addresses[2], addresses[3]);
        assertEq(fractionManager.fractByTokenId(addresses[3], 4), 500, "sending fraction failed");

        vm.stopPrank();
    }

    function test_developerCheck() public {
        deal(address(fractionToken), devWallet, 0);
        fractionToken.unpause();
        assertEq(5_000_000, fractionToken.balanceOf(address(fractionManager)));
        developerCheck(2_000_000);
        assertEq(500, fractionToken.balanceOf(devWallet));
        developerCheck(2_000_000);
        assertEq(1500, fractionToken.balanceOf(devWallet));
        developerCheck(998_500);
        assertEq(2500, fractionToken.balanceOf(devWallet));
    }

    function developerCheck(uint256 _amount) private {
        uint256 breakpoint0 = 2_000_000;
        uint256 breakpoint1 = 4_000_000;
        uint256 breakpoint2 = 5_000_000;
        totalFractionSold += _amount;
        if ((totalFractionSold >= breakpoint0) && (_fractionOwnership[devWallet][3] < 500)) {
            require(
                fractionToken.transferByManager(3, 500, address(fractionManager), devWallet),
                "FractNFT: Failure Transfer From"
            );
            totalFractionSold += 500;
            _fractionOwnership[devWallet][3] += 500;
        }

        if ((totalFractionSold >= breakpoint1) && (_fractionOwnership[devWallet][2] < 1000)) {
            require(
                fractionToken.transferByManager(2, 1000, address(fractionManager), devWallet),
                "FractNFT: Failure Transfer From"
            );
            totalFractionSold += 1000;
            _fractionOwnership[devWallet][2] += 1000;
        }

        if ((totalFractionSold >= breakpoint2) && (_fractionOwnership[devWallet][1] < 1000)) {
            require(
                fractionToken.transferByManager(1, 1000, address(fractionManager), devWallet),
                "FractNFT: Failure Transfer From"
            );
            totalFractionSold += 1000;
            _fractionOwnership[devWallet][1] += 1000;
        }
    }

    function test_StakingVilla() public {
        uint256 currPrice = villaNFT.getCurrentPrice();
        uint256 mintAmount = 3;
        uint256 allowance = currPrice * mintAmount;
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;
        stakingManager.unpause();
        vm.startPrank(addresses[4], addresses[4]);
        deal(usdc, addresses[4], allowance);
        _usdcToken.approve(address(villaNFT), allowance);

        villaNFT.publicMint(mintAmount);
        assertEq(villaNFT.tokensOfOwner(addresses[4]), tokenIds);
        for (uint256 i; i < tokenIds.length; i++) {
            villaNFT.approve(address(stakingManager), tokenIds[i]);
        }

        stakingManager.depositVillas(villaNFT.tokensOfOwner(addresses[4]));
        assertEq(stakingManager.depositsOfVilla(addresses[4]), villaNFT.tokensOfOwner(address(stakingManager)));

        vm.warp(block.timestamp + 125 days);
        uint256 expectedReward = 125 days * 10_425_133_181_126_332;
        uint256[] memory rewards = stakingManager.calculateVillaRewards(addresses[4], tokenIds);
        assertEq(rewards[0], expectedReward, "Calculated reward should match the expected reward");

        uint256 initialBalance = stakingToken.balanceOf(addresses[4]);
        stakingManager.claimVillaRewards(tokenIds);
        uint256 finalBalance = stakingToken.balanceOf(addresses[4]);

        uint256 expectedClaimReward = 125 days * 10_425_133_181_126_332 * 3;
        uint256 claimedReward = finalBalance - initialBalance;

        assertEq(claimedReward, expectedClaimReward, "Claimed reward should match the expected reward");
        stakingManager.withdrawVillas(tokenIds);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            assertEq(villaNFT.ownerOf(tokenIds[i]), addresses[4]);
            assertFalse(stakingManager.depositsOfVilla(addresses[4]).length > 0);
        }
        vm.stopPrank();
    }

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
