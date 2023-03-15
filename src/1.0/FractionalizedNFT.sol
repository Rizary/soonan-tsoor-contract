// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import {IERC721A} from "@erc721A/contracts/IERC721A.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {FractionToken} from "./FractionToken.sol";
import {SoonanTsoorStudio} from "./SoonanTsoorStudio.sol";

contract FractionalizedNFT is ERC721Holder, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    FractionToken public wsnsr;
    
    SoonanTsoorStudio public soonanTsoorStudio;
    
    // Mint Token
    IERC20 public immutable mintToken;

    uint256 public constant FRACTION_SIZE = 1000;
    
    // whether or not mints should auto distribute
    bool public autoDistribute = false;
    
    // cost for minting fraction
    uint256 public cost = 85 * 10**6;

    uint256 public totalFractions;
    uint256 public totalFractionSold;
    
    // Rewards Wallet
    address public rewardWallet = 0x7C8c679CE072544Aa7a73b85d5Ea9b3195Fa7Bd2;

    // Project Wallet
    address public projectWallet = 0x26a3E0CBf8240E303EcdF36a2ccaef74A32692db;
    
    // Dev Wallet
    address public devWallet = 0x5FE49cb77be19D1970dd9b0971086A8fFFAe66E4;

    struct FractOwnership {
        mapping(uint256 => uint256) fractOwned;
    }
    mapping(uint256 => uint256) private _availableFractions;
    mapping(address => FractOwnership) private _fractionOwnership;
    mapping(address => uint256[]) private _tokenIdShared;
    mapping(address => uint256) private _totalFractOwned;
    
    // Breakpoints for developer
    uint256 private constant breakpoint0 = 2_000_000;
    uint256 private constant breakpoint1 = 4_000_000;
    uint256 private constant breakpoint2 = 5_000_000;
    
    event FractionBought(address indexed buyer, uint256 tokenId, uint256 amount);

    constructor(address _wsnsr, address payable _soonanTsoorStudio, address usdc) {
        wsnsr = FractionToken(_wsnsr);
        soonanTsoorStudio = SoonanTsoorStudio(_soonanTsoorStudio);
        mintToken = IERC20(usdc);
        _tokenIdShared[devWallet].push(101);
        _tokenIdShared[devWallet].push(102);
        _tokenIdShared[devWallet].push(103);

        // mint all ERC20 tokens
        totalFractions = 5000 * FRACTION_SIZE;
    }

    function buyFraction(uint256 _tokenId, uint256 _amount) external nonReentrant {
        require(_amount > 0, "FractionalizedNFT: invalid amount");
        require(_tokenId >= 103 && _tokenId <= 5100, "FractionalizedNFT: invalid tokenId");
        require(_amount <= _availableFractions[_tokenId], "FractionalizedNFT: insufficient available fractions");

        _transferIn(cost * _amount);
        
        _transferOut(_amount);

        // transfer NFT fraction from contract to buyer
        _availableFractions[_tokenId] -= _amount;
        
        if (_tokenId == 103) {
            require(500 < (_availableFractions[103]), "FractionalizedNFT: this is reserved for developer");
        }
        
        if (_fractionOwnership[msg.sender].fractOwned[_tokenId] < 1) {
            _tokenIdShared[msg.sender].push(_tokenId);
        }
        _fractionOwnership[msg.sender].fractOwned[_tokenId] += _amount;
        _totalFractOwned[msg.sender] += _amount;
        
        totalFractionSold += _amount;
        if (totalFractionSold >= breakpoint2) {
            totalFractionSold += 500;
            _fractionOwnership[devWallet].fractOwned[103] += 500;
            _totalFractOwned[devWallet] += 500;
        } else if ((totalFractionSold >= breakpoint1) && (_fractionOwnership[devWallet].fractOwned[102] < 1000)) {
            totalFractionSold += 1000;
            _fractionOwnership[devWallet].fractOwned[102] += 1000;
            _totalFractOwned[devWallet] += 1000;
        } else if ((totalFractionSold >= breakpoint1) && (_fractionOwnership[devWallet].fractOwned[101] < 1000)) {
            totalFractionSold += 1000;
            _fractionOwnership[devWallet].fractOwned[101] += 1000;
            _totalFractOwned[devWallet] += 1000;
        }
        
        // divide up funds
        if (autoDistribute) {
            _distribute();
        }
        
        emit FractionBought(msg.sender, _tokenId, _amount);
    }
    
    function redeemFraction(uint256 _tokenId, uint256 _amount) external nonReentrant {
        require(_amount > 0, "FractionalizedNFT: invalid amount");
        require(_tokenId >= 103 && _tokenId <= 5100, "FractionalizedNFT: invalid tokenId");
        require(_amount <= _availableFractions[_tokenId], "FractionalizedNFT: insufficient available fractions");
        
        _transferOut(_amount);

        // transfer NFT fraction from contract to buyer
        _availableFractions[_tokenId] -= _amount;
        
        if (_tokenId == 103) {
            require(500 < (_availableFractions[103]), "FractionalizedNFT: this is reserved for developer");
        }
        
        if (_fractionOwnership[msg.sender].fractOwned[_tokenId] < 1) {
            _tokenIdShared[msg.sender].push(_tokenId);
        }
        _fractionOwnership[msg.sender].fractOwned[_tokenId] += _amount;
        _totalFractOwned[msg.sender] += _amount;
        
        totalFractionSold += _amount;
        if (totalFractionSold >= breakpoint2) {
            totalFractionSold += 500;
            _fractionOwnership[devWallet].fractOwned[103] += 500;
            _totalFractOwned[devWallet] += 500;
        } else if ((totalFractionSold >= breakpoint1) && (_fractionOwnership[devWallet].fractOwned[102] < 1000)) {
            totalFractionSold += 1000;
            _fractionOwnership[devWallet].fractOwned[102] += 1000;
            _totalFractOwned[devWallet] += 1000;
        } else if ((totalFractionSold >= breakpoint1) && (_fractionOwnership[devWallet].fractOwned[101] < 1000)) {
            totalFractionSold += 1000;
            _fractionOwnership[devWallet].fractOwned[101] += 1000;
            _totalFractOwned[devWallet] += 1000;
        }
        
        // divvy up funds
        if (autoDistribute) {
            _distribute();
        }
        
        emit FractionBought(msg.sender, _tokenId, _amount);
    }
    
    function sendFraction(address to, uint256 _tokenId, uint256 _amount) external onlyOwner {
        require(_amount < 0, "FractionalizedNFT: invalid amount");
        require(_tokenId >= 103 && _tokenId <= 5100, "FractionalizedNFT: invalid tokenId");
        require(_amount <= _availableFractions[_tokenId], "FractionalizedNFT: insufficient available fractions");
        
        if (_tokenId == 103) {
            require(500 < (_availableFractions[103]), "FractionalizedNFT: this is reserved for developer");
        }

        _transferOutOwner(to, _amount);
        // transfer NFT fraction from contract to buyer
        _availableFractions[_tokenId] -= _amount;
        
        if (_fractionOwnership[to].fractOwned[_tokenId] < 1) {
            _tokenIdShared[to].push(_tokenId);
        }
        _fractionOwnership[to].fractOwned[_tokenId] += _amount;
        _totalFractOwned[to] += _amount;
        
        totalFractionSold += _amount;
        if (totalFractionSold >= breakpoint2) {
            totalFractionSold += 500;
            _fractionOwnership[devWallet].fractOwned[103] += 500;
            _totalFractOwned[devWallet] += 500;
        } else if ((totalFractionSold >= breakpoint1) && (_fractionOwnership[devWallet].fractOwned[102] < 1000)) {
            totalFractionSold += 1000;
            _fractionOwnership[devWallet].fractOwned[102] += 1000;
            _totalFractOwned[devWallet] += 1000;
        } else if ((totalFractionSold >= breakpoint1) && (_fractionOwnership[devWallet].fractOwned[101] < 1000)) {
            totalFractionSold += 1000;
            _fractionOwnership[devWallet].fractOwned[101] += 1000;
            _totalFractOwned[devWallet] += 1000;
        }
        
        emit FractionBought(to, _tokenId, _amount);
    }

    function _transferIn(uint256 amount) internal {
        require(
            mintToken.allowance(msg.sender, address(this)) >= amount,
            "FractNFT: Insufficient TransferIn Allowance"
        );
        require(
            mintToken.transferFrom(msg.sender, address(this), amount),
            "FractNFT: Failure Transfer From"
        );
    }

    function _transferOut(uint256 amount) internal {
        require(
            wsnsr.allowance(address(this), msg.sender) >= amount,
            "FractNFT: Insufficient TransferOut Allowance"
        );
        require(
            wsnsr.transferFrom(address(this), msg.sender, amount),
            "FractNFT: Failure Transfer From"
        );
    }
    
    function _transferOutOwner(address to, uint256 amount) internal onlyOwner {
        require(
            wsnsr.transferFrom(address(this), to, amount),
            "Failure Transfer From"
        );
    }
    
    function setCost(uint256 newCost) external onlyOwner {
        cost = newCost * 10**6;
    }
    
    function withdraw() external onlyOwner {
        (bool s, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(s);
    }

    function distribute() external onlyOwner {
        _distribute();
    }

    function withdrawToken(address token_) external onlyOwner {
        require(token_ != address(0), "Zero Address");
        IERC20(token_).transfer(
            msg.sender,
            IERC20(token_).balanceOf(address(this))
        );
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

    function fractionalize(uint256[] memory _tokenIds) external onlyOwner {
        require(soonanTsoorStudio.balanceOf(address(this)) <= 5100, "FractionalizedNFT: All NFT has been fractionalized");
        for (uint i = 0; i < _tokenIds.length; i++) {
            soonanTsoorStudio.transferFrom(msg.sender, address(this), _tokenIds[i]);
            _availableFractions[_tokenIds[i]] = FRACTION_SIZE;
        }
    }
}