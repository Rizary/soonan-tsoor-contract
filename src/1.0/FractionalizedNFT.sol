// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import {IERC721A} from "@erc721A/contracts/IERC721A.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {FractionToken} from "./FractionToken.sol";

contract FractionalizedNFT is ERC721Holder, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    FractionToken public wsnsr;
    
    // Mint Token
    IERC20 public immutable mintToken;

    address public soonanTsoorNFT;

    uint256 public constant FRACTION_SIZE = 1000;
    
    // whether or not mints should auto distribute
    bool public autoDistribute = true;
    
    // cost for minting fraction
    uint256 public cost = 85 * 10**6;

    uint256 public totalFractions;
    
    // Rewards Wallet
    address public rewardWallet = 0x7C8c679CE072544Aa7a73b85d5Ea9b3195Fa7Bd2;

    // Project Wallet
    address public projectWallet = 0x26a3E0CBf8240E303EcdF36a2ccaef74A32692db;

    struct FractOwnership {
        mapping(uint256 => uint256) fractOwned;
    }
    mapping(uint256 => uint256) private _availableFractions;
    mapping(address => FractOwnership) private _fractionOwnership;
    mapping(address => uint256[]) private _tokenIdShared;
    mapping(address => uint256) private _totalFractOwned;

    event FractionBought(address indexed buyer, uint256 tokenId, uint256 amount);

    constructor(address _wsnsr, address _soonanTsoorNFT, address usdc) {
        wsnsr = FractionToken(_wsnsr);
        soonanTsoorNFT = _soonanTsoorNFT;
        mintToken = IERC20(usdc);

        // mint all ERC20 tokens
        totalFractions = 5000 * FRACTION_SIZE;
    }

    function buyFraction(uint256 _tokenId, uint256 _amount) external nonReentrant {
        require(_amount > 0, "FractionalizedNFT: invalid amount");
        require(_tokenId >= 100 && _tokenId <= 5100, "FractionalizedNFT: invalid tokenId");
        require(_amount <= _availableFractions[_tokenId], "FractionalizedNFT: insufficient available fractions");

        _transferIn(cost * _amount);
        
        _transferOut(_amount);

        // transfer NFT fraction from contract to buyer
        _availableFractions[_tokenId] -= _amount;
        
        if (_fractionOwnership[msg.sender].fractOwned[_tokenId] < 1) {
            _tokenIdShared[msg.sender].push(_tokenId);
        }
        _fractionOwnership[msg.sender].fractOwned[_tokenId] += _amount;
        _totalFractOwned[msg.sender] += _amount;
        
        
        // divvy up funds
        if (autoDistribute) {
            _distribute();
        }
        
        emit FractionBought(msg.sender, _tokenId, _amount);
    }
    
    function sendFraction(address to, uint256 _tokenId, uint256 _amount) external onlyOwner {
        require(_amount > 0, "FractionalizedNFT: invalid amount");
        require(_tokenId >= 100 && _tokenId <= 5100, "FractionalizedNFT: invalid tokenId");
        require(_amount <= _availableFractions[_tokenId], "FractionalizedNFT: insufficient available fractions");

        _transferOutOwner(to, _amount);
        // transfer NFT fraction from contract to buyer
        _availableFractions[_tokenId] -= _amount;
        
        if (_fractionOwnership[to].fractOwned[_tokenId] < 1) {
            _tokenIdShared[to].push(_tokenId);
        }
        _fractionOwnership[to].fractOwned[_tokenId] += _amount;
        _totalFractOwned[to] += _amount;
        
        emit FractionBought(to, _tokenId, _amount);
    }

    function _transferIn(uint256 amount) internal {
        require(
            mintToken.allowance(msg.sender, address(this)) >= amount,
            "Insufficient Allowance"
        );
        require(
            mintToken.transferFrom(msg.sender, address(this), amount),
            "Failure Transfer From"
        );
    }

    function _transferOut(uint256 amount) internal {
        require(
            wsnsr.allowance(address(this), msg.sender) >= amount,
            "Insufficient Allowance"
        );
        require(
            wsnsr.transferFrom(address(this), msg.sender, amount),
            "Failure Transfer From"
        );
    }
    
    function _transferOutOwner(address to, uint256 amount) internal onlyOwner {
        require(
            wsnsr.transferFrom(address(this), to, amount),
            "Failure Transfer From"
        );
    }
    
    function setCost(uint256 newCost) external onlyOwner {
        cost = newCost;
    }
    
    function distribute() external onlyOwner {
        _distribute();
    }
    
    function _distribute() internal {
        // send half of the usdc to web 2.0 business wallet
        uint256 forWeb2 = mintToken.balanceOf(address(this)) / 2;
        if (forWeb2 > 0) {
            mintToken.transfer(rewardWallet, forWeb2);
        }

        // send the rest to web 3.0 business wallet
        uint256 forWeb3 = mintToken.balanceOf(address(this));
        if (forWeb3 > 0) {
            mintToken.transfer(projectWallet, forWeb3);
        }
    }
    
    function setAutoDistribute(bool auto_) external onlyOwner {
        autoDistribute = auto_;
    }

    function isRightFullOwner(address owner, uint256 tokenId)
        external
        view
        returns (bool)
    {
        return _fractionOwnership[owner].fractOwned[tokenId] == 1000;
    }
    
    function fractByTokenId(address owner, uint256 tokenId)
        external
        view
        returns (uint256)
    {
        return _fractionOwnership[owner].fractOwned[tokenId];
    }
    
    function totalFractByAddress(address owner)
        external
        view
        returns (uint256)
    {
        return _totalFractOwned[owner];
    }
    
    function tokenIdSharedByAddress(address owner)
        external
        view
        returns (uint256[] memory)
    {
        return _tokenIdShared[owner];
    }
    
    function availableFracByTokenId(uint256 tokenId)
        external
        view
        returns (uint256)
    {
        return _availableFractions[tokenId];
    }

    function fractionalize() external onlyOwner {
        require(IERC721A(soonanTsoorNFT).balanceOf(address(this)) == 5000, "FractionalizedNFT: insufficient SoonanTsoorNFT tokens");

        for (uint256 i = 101; i <= 5100; i++) {
            IERC721A(soonanTsoorNFT).safeTransferFrom(msg.sender, address(this), i);
            _availableFractions[i] = FRACTION_SIZE;
        }
    }
}