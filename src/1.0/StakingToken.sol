// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC1363} from "@erc1363-payable-token/contracts/token/ERC1363/ERC1363.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StakingToken is ERC20Burnable, ERC1363, Ownable, Pausable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    constructor() ERC20("Staking Token", "SRSTS") {}
    
    /// @notice pause minting token
    function pause() public onlyOwner {
        _pause();
    }

    /// @notice unpause minting token
    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }
    
    /// @notice execute before token transfer
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }
}