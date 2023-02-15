// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import {ERC721A, ERC721A__IERC721Receiver} from "@erc721A/contracts/ERC721A.sol";
import {IERC721A} from "@erc721A/contracts/IERC721A.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract FractionalizedNFT is ERC721Holder, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public wsnsr;

    address public soonanTsoorNFT;

    uint256 public constant FRACTION_SIZE = 1000;

    uint256 public totalFractions;

    mapping(uint256 => uint256) public availableFractions;

    event FractionBought(address indexed buyer, uint256 tokenId, uint256 amount);

    constructor(address _wsnsr, address _soonanTsoorNFT) {
        wsnsr = IERC20(_wsnsr);
        soonanTsoorNFT = _soonanTsoorNFT;

        // mint all ERC20 tokens
        totalFractions = 5000 * FRACTION_SIZE;
        wsnsr.mint(address(this), totalFractions);
    }

    function buyFraction(uint256 _tokenId, uint256 _amount) external nonReentrant {
        require(_amount > 0, "FractionalizedNFT: invalid amount");
        require(_tokenId >= 100 && _tokenId <= 5100, "FractionalizedNFT: invalid tokenId");
        require(_amount <= availableFractions[_tokenId], "FractionalizedNFT: insufficient available fractions");

        // transfer WSNSR tokens from buyer to contract
        wsnsr.safeTransferFrom(msg.sender, address(this), _amount);

        // transfer NFT fraction from contract to buyer
        availableFractions[_tokenId] -= _amount;
        IERC721A(soonanTsoorNFT).safeTransferFrom(address(this), msg.sender, _tokenId);

        emit FractionBought(msg.sender, _tokenId, _amount);
    }

    function fractionalize() external onlyOwner {
        require(IERC721A(soonanTsoorNFT).balanceOf(address(this)) == 5000, "FractionalizedNFT: insufficient SoonanTsoorNFT tokens");

        for (uint256 i = 101; i <= 5100; i++) {
            IERC721A(soonanTsoorNFT).safeTransferFrom(msg.sender, address(this), i);
            availableFractions[i] = FRACTION_SIZE;
        }
    }
}