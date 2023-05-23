// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC1363} from "@erc1363-payable-token/contracts/token/ERC1363/ERC1363.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract FractionToken is ERC20Burnable, ERC1363, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    event FractionTransfer(uint256 indexed tokenId, uint256 amount, address indexed from, address indexed to);

    mapping(address => mapping(uint256 => uint256)) private _fractionOwnership;

    uint256 private supplyCap;

    bool private _paused;
    bool private _enableDirectTransfer;
    uint256 private _pauseTime;

    constructor() ERC20("Fraction Token", "FSTS") {
        _pauseTime = block.timestamp;
        _enableDirectTransfer = true;
        _paused = true;
    }

    function transfer(address, uint256) public virtual override(ERC20, IERC20) returns (bool) {
        revert("Direct transfers are disabled. Please go to Soonan Tsoor's Marketplace.");
    }

    function transferFrom(address, address, uint256) public virtual override(ERC20, IERC20) returns (bool) {
        revert("Direct transfers are disabled. Please go to Soonan Tsoor's Marketplace.");
    }

    function transferByManager(uint256 tokenId, uint256 amount, address from, address to)
        external
        nonReentrant
        returns (bool)
    {
        require(!_paused, "FractionToken: contract is paused");
        require(block.timestamp >= _pauseTime, "FractionToken: time lock in effect");
        require(amount <= 1000, "FractionToken: transfer amount exceeds maximum limit");

        _transfer(from, to, amount);
        emit FractionTransfer(tokenId, amount, from, to);
        return true;
    }

    function enableDirectTransfer() external onlyOwner {
        _enableDirectTransfer = true;
    }

    function disableDirectTransfer() external onlyOwner {
        _enableDirectTransfer = false;
    }

    function mint(address _to, uint256 _amount) external onlyOwner {
        require(totalSupply() + _amount <= supplyCap, "FractionToken: supply cap exceeded");
        require(!_paused, "FractionToken: contract is paused");

        _mint(_to, _amount);
    }

    function pause() external onlyOwner {
        _paused = true;
        _pauseTime = block.timestamp;
    }

    function unpause() external onlyOwner {
        _paused = false;
        _pauseTime = 0;
    }

    function getFractionStatus() external view returns (bool) {
        return _paused;
    }

    function setMaxSupply(uint256 _maxSupply) external onlyOwner {
        supplyCap = _maxSupply;
    }
}
