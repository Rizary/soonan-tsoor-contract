// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract FractionToken is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    uint256 public constant SUPPLY_CAP = 5000000 * 10**18;

    bool private _paused = true;
    bool private _enableDirectTransfer;
    uint256 private _pauseTime;

    constructor() ERC20("Fraction Token", "FSTS") {
        _pauseTime = block.timestamp;
        _enableDirectTransfer = true;
        _mint(address(this), SUPPLY_CAP);
    }

    function transfer(address recipient, uint256 amount) public virtual override nonReentrant onlyOwner returns (bool) {
        require(!_paused, "FractionToken: contract is paused");
        require(block.timestamp >= _pauseTime, "FractionToken: time lock in effect");
        require(amount <= 1000 * 10**18, "FractionToken: transfer amount exceeds maximum limit");
        
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override nonReentrant returns (bool) {
        require(!_paused, "FractionToken: contract is paused");
        require(block.timestamp >= _pauseTime, "FractionToken: time lock in effect");
        require(amount <= 1000 * 10**18, "FractionToken: transfer amount exceeds maximum limit");

        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), allowance(sender, _msgSender()) - amount);
        return true;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 /*amount*/
    ) internal override virtual {
        if (_enableDirectTransfer == true) {
            require(from == address(this) || from == address(0), "direct transfer is only for contract address");
        } else {
            require(to == address(this), "direct transfer is not allowed");
        }
        
    }
    
    function enableDirectTransfer() external onlyOwner {
        _enableDirectTransfer = true;
    }

    function disableDirectTransfer() external onlyOwner {
        _enableDirectTransfer = false;
    }

    function mint(address _to, uint256 _amount) external nonReentrant onlyOwner {
        require(totalSupply() + _amount <= SUPPLY_CAP, "FractionToken: supply cap exceeded");
        require(!_paused, "FractionToken: contract is paused");

        _mint(_to, _amount);
    }

    function burn(uint256 _amount) external nonReentrant onlyOwner{
        require(!_paused, "FractionToken: contract is paused");

        _burn(msg.sender, _amount);
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
}