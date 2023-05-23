// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IERC721A} from "@erc721A/contracts/IERC721A.sol";
import {ERC721A__IERC721Receiver} from "@erc721A/contracts/ERC721A.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC165Storage} from "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from "@chainlink/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {FractionToken} from "./FractionToken.sol";

contract FractionManager is Context, ERC165Storage, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    FractionToken public wsnsr;

    // Mint Token
    IERC20 public immutable mintToken;
    AggregatorV3Interface immutable _priceFeed;

    uint256 public _usdPrice;

    uint256 public constant FRACTION_SIZE = 1000;

    // whether or not mints should auto distribute
    bool public autoDistribute = false;

    // cost for minting fraction
    uint256 public cost;

    uint256 public totalFractions;
    uint256 public totalFractionSold;

    // Rewards Wallet
    address public rewardWallet = 0x7C8c679CE072544Aa7a73b85d5Ea9b3195Fa7Bd2;

    // Project Wallet
    address public projectWallet = 0x26a3E0CBf8240E303EcdF36a2ccaef74A32692db;

    // Dev Wallet
    address public devWallet = 0x5FE49cb77be19D1970dd9b0971086A8fFFAe66E4;

    mapping(uint256 => uint256) private _availableFractions;
    mapping(address => mapping(uint256 => uint256)) private _fractionOwnership;
    mapping(address => uint256[]) private _tokenIdShared;

    // Breakpoints for developer
    uint256 private constant _breakpoint0 = 2_000_000;
    uint256 private constant _breakpoint1 = 4_000_000;
    uint256 private constant _breakpoint2 = 5_000_000;

    event FractionBought(address indexed buyer, uint256 tokenId, uint256 amount);

    constructor(address _wsnsr, address usdc, address _feed) {
        wsnsr = FractionToken(_wsnsr);
        mintToken = IERC20(usdc);
        _tokenIdShared[devWallet].push(101);
        _tokenIdShared[devWallet].push(102);
        _tokenIdShared[devWallet].push(103);
        _priceFeed = AggregatorV3Interface(_feed);
        _usdPrice = 10 * 10 ** _priceFeed.decimals(); // 100 USD by default
        // mint all ERC20 tokens
        for (uint256 i = 1; i < 5001; i++) {
            _availableFractions[i] = FRACTION_SIZE;
            _fractionOwnership[address(this)][i] += FRACTION_SIZE;
        }
        totalFractions = 5000 * FRACTION_SIZE;
    }

    function buyFraction(uint256 _tokenId, uint256 _amount) external nonReentrant {
        require(_amount > 0, "FractionManager: invalid amount");
        require(_tokenId >= 3 && _tokenId < 5001, "FractionManager: invalid tokenId");
        require(_amount <= _availableFractions[_tokenId], "FractionManager: insufficient available fractions");
        uint256 price = getCurrentPrice();
        // transfer in cost
        _transferIn(price * _amount);

        _transferOut(_tokenId, _amount, address(this), msg.sender);

        // divide up funds
        if (autoDistribute) {
            _distribute();
        }
    }

    function redeemFraction(uint256 _tokenId, uint256 _amount) external nonReentrant {
        require(_amount > 0, "FractionManager: invalid amount");
        require(_tokenId >= 3 && _tokenId < 5001, "FractionManager: invalid tokenId");
        require(_amount <= _availableFractions[_tokenId], "FractionManager: insufficient available fractions");
        require(_fractionOwnership[address(this)][_tokenId] > 0, "Sender do not own any fraction of the token");

        _transferOut(_tokenId, _amount, address(this), msg.sender);
    }

    function sendFraction(address _to, uint256 _tokenId, uint256 _amount) external onlyOwner {
        require(_amount > 0, "FractionManager: invalid amount");
        require(_tokenId >= 3 && _tokenId < 5001, "FractionManager: invalid tokenId");
        require(_amount <= _availableFractions[_tokenId], "FractionManager: insufficient available fractions");
        _transferOut(_tokenId, _amount, address(this), _to);
    }

    function transferFraction(uint256 _tokenId, uint256 _amount, address _from, address _to)
        external
        nonReentrant
        returns (bool)
    {
        require(_fractionOwnership[_from][_tokenId] > 0, "Sender do not own any fraction of the token");
        require(wsnsr.transferByManager(_tokenId, _amount, _from, _to), "Fraction Transfer Failure");
        _fractionOwnership[_from][_tokenId] -= _amount;
        _fractionOwnership[_to][_tokenId] += _amount;

        return true;
    }

    function _transferIn(uint256 _amount) internal {
        require(
            mintToken.allowance(msg.sender, address(this)) >= _amount, "FractNFT: Insufficient TransferIn Allowance"
        );
        require(mintToken.transferFrom(msg.sender, address(this), _amount), "FractNFT: Failure Transfer From");
    }

    function _transferOut(uint256 _tokenId, uint256 _amount, address _from, address _to) private {
        if (_tokenId == 3) {
            require(500 < (_availableFractions[3]), "FractionManager: this is reserved for developer");
        }

        require(wsnsr.transferByManager(_tokenId, _amount, _from, _to), "FractNFT: Failure Transfer From");
        _availableFractions[_tokenId] -= _amount;

        if (_fractionOwnership[_to][_tokenId] < 1) {
            _tokenIdShared[_to].push(_tokenId);
        }
        _fractionOwnership[_from][_tokenId] -= _amount;
        _fractionOwnership[_to][_tokenId] += _amount;

        developerCheck(_amount);

        emit FractionBought(_to, _tokenId, _amount);
    }

    function developerCheck(uint256 _amount) private {
        totalFractionSold += _amount;
        if ((totalFractionSold >= _breakpoint0) && (_fractionOwnership[devWallet][3] < 500)) {
            require(wsnsr.transferByManager(3, 500, address(this), devWallet), "FractNFT: Failure Transfer From");
            totalFractionSold += 500;
            _fractionOwnership[devWallet][3] += 500;
        }

        if ((totalFractionSold >= _breakpoint1) && (_fractionOwnership[devWallet][2] < 1000)) {
            require(wsnsr.transferByManager(2, 1000, address(this), devWallet), "FractNFT: Failure Transfer From");
            totalFractionSold += 1000;
            _fractionOwnership[devWallet][2] += 1000;
        }

        if ((totalFractionSold >= _breakpoint2) && (_fractionOwnership[devWallet][1] < 1000)) {
            require(wsnsr.transferByManager(1, 1000, address(this), devWallet), "FractNFT: Failure Transfer From");
            totalFractionSold += 1000;
            _fractionOwnership[devWallet][1] += 1000;
        }
    }

    function setUSDPrice(uint256 _newPrice) external onlyOwner {
        _usdPrice = _newPrice * 10 ** _priceFeed.decimals();
    }

    function distribute() external onlyOwner {
        _distribute();
    }

    function withdrawToken() external payable onlyOwner {
        uint256 balance = mintToken.balanceOf(address(this));

        require(balance > 0, "Contract has no balance");
        _distribute();
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC165Storage) returns (bool) {
        return interfaceId == type(IERC721A).interfaceId || interfaceId == type(IERC20).interfaceId
            || super.supportsInterface(interfaceId);
    }

    function _distribute() internal {
        // send half of the usdc to web 2.0 business wallet
        uint256 forWeb2 = mintToken.balanceOf(address(this)) / 2;
        if (forWeb2 > 0) {
            require(mintToken.transfer(projectWallet, forWeb2), "Transfer to Web2 wallet failed");
        }

        // send the rest to web 3.0 business wallet
        uint256 forWeb3 = mintToken.balanceOf(address(this));
        if (forWeb3 > 0) {
            require(mintToken.transfer(projectWallet, forWeb3), "Transfer to Web3 wallet failed");
        }
    }

    function setAutoDistribute(bool auto_) external onlyOwner {
        autoDistribute = auto_;
    }

    function isRightFullOwner(address addr, uint256 tokenId) external view returns (bool) {
        return _fractionOwnership[addr][tokenId] == 1000;
    }

    function fractByTokenId(address addr, uint256 tokenId) external view returns (uint256) {
        return _fractionOwnership[addr][tokenId];
    }

    function tokenIdSharedByAddress(address addr) external view returns (uint256[] memory) {
        return _tokenIdShared[addr];
    }

    function availableFracByTokenId(uint256 tokenId) external view returns (uint256) {
        return _availableFractions[tokenId];
    }

    function getCurrentPrice() public view returns (uint256) {
        (, int256 price,, uint256 updatedAt,) = _priceFeed.latestRoundData();
        require(price > 0, "Feed price should be greater than 0");
        require(updatedAt > block.timestamp - 86_400, "Stale Price");
        uint256 usdcPrice = _usdPrice / uint256(price);
        return usdcPrice * 10 ** 6;
    }
}
