// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/1.0/FractionalizedNFT.sol";
import "../src/1.0/SoonanTsoorStudio.sol";
import "../src/1.0/SoonanTsoorVilla.sol";
import "../src/1.0/StakingFractionNFT.sol";

contract FractionalizedNFTTest is Test {
    FractionToken fractionToken;
    SoonanTsoorStudio soonanTsoorStudio;
    FractionalizedNFT fractionalizedNFT;
    address usdc = address(0xE097d6B3100777DC31B34dC2c58fB524C2e76921); // Replace this with the USDC contract address
        uint256[] sharedId = [104];
    function setUp() public {
        fractionToken = new FractionToken();
        soonanTsoorStudio = new SoonanTsoorStudio(usdc);
        fractionalizedNFT = new FractionalizedNFT(address(fractionToken), payable(address(soonanTsoorStudio)), usdc);
    }

    function testBuyFraction() public {
        uint256[] memory tokenIds = new uint256[](4);
        tokenIds[0] = 103;
        tokenIds[1] = 104;
        tokenIds[2] = 105;
        tokenIds[3] = 106;
        uint256 tokenId = 104;

        uint256 amount = 10;
        address addr1 = address(0x1234);

        // Mint tokens for the test user
        vm.prank(address(this));
        soonanTsoorStudio.ownerMint(address(this), 6);

        // Approve the FractionalizedNFT contract to transfer the test user's tokens
        vm.prank(address(this));
        soonanTsoorStudio.setApprovalForAll(address(fractionalizedNFT), true);

        // Fractionalize the test user's token
        vm.prank(address(this));
        fractionalizedNFT.fractionalize(tokenIds);

        // Approve the FractionalizedNFT contract to spend the test user's USDC
        // Replace the following line with the actual USDC contract
        // vm.prank(addr1);
        // vm.deal(addr1, 10_000_000 ether);
        // IERC20(usdc).approve(address(fractionalizedNFT), amount);

        // Buy fraction
        vm.prank(address(this));
        fractionToken.unpause();
                vm.prank(address(this));
        fractionalizedNFT.sendFraction(addr1, tokenId, amount);

vm.prank(address(this));
        // Check if the fraction was bought correctly
                assertEq(fractionalizedNFT.availableFracByTokenId(tokenId), 990, "Incorrect fraction bought");
        assertEq(fractionalizedNFT.fractByTokenId(addr1, tokenId), amount, "Incorrect fraction bought");
        assertEq(fractionalizedNFT.tokenIdSharedByAddress(addr1), sharedId, "Incorrect token shared");
    }
}
