/// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {ERC721A, ERC721A__IERC721Receiver} from "@erc721A/contracts/ERC721A.sol";
import {IERC721AQueryable} from "@erc721A/contracts/extensions/IERC721AQueryable.sol";
import {ERC721AQueryable} from "@erc721A/contracts/extensions/ERC721AQueryable.sol";
import {IERC721A} from "@erc721A/contracts/IERC721A.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {ERC165Storage} from "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title SoonanTsoorStudio
/// @notice This is the main contract of Soonan Tsoor's Villa, NFT for Soonan Tsoor Project
contract SoonanTsoorStudio is ERC165Storage, ERC721A, ERC721AQueryable, Ownable2Step, ERC2981, ReentrancyGuard {
    IERC20 immutable _usdcToken;
    AggregatorV3Interface immutable _priceFeed;

    uint256 public _usdPrice;

    // Token name
    string private constant _name = "SoonanTsoorStudio";

    // Token symbol
    string private constant _symbol = "STS";

    // Enable Trading
    bool public publicMintingEnabled = false;

    // max supply cap
    uint256 private constant MAX_SUPPLY = 5_001;

    // base URI
    string private _baseNftURI = "url/";
    string private _ending = ".json";

    constructor(address _usdc, address _feed, address fractionManager) ERC721A(_name, _symbol) {
        _usdcToken = IERC20(_usdc);
        _priceFeed = AggregatorV3Interface(_feed);
        _usdPrice = 100;
        _setDefaultRoyalty(msg.sender, 250);
        _mintERC2309(fractionManager, 5000);
    }

    /// @dev See {ERC721A-_startTokenId}.
    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721A, IERC721A, ERC2981, ERC165Storage)
        returns (bool)
    {
        return interfaceId == type(IERC721AQueryable).interfaceId || interfaceId == type(IERC721A).interfaceId
            || interfaceId == type(IERC20).interfaceId || interfaceId == type(ERC2981).interfaceId
            || interfaceId == type(ERC165Storage).interfaceId || super.supportsInterface(interfaceId);
    }

    function renounceOwnership() public pure override {
        require(false, "cannot renounce");
    }

    function getCurrentPrice() public view returns (uint256) {
        (, int256 price,, uint256 updatedAt,) = _priceFeed.latestRoundData();
        require(price > 0, "Feed price should be greater than 0");
        require(updatedAt > block.timestamp - 86_400, "Stale Price");
        uint256 usdcPrice = _usdPrice / uint256(price);
        return usdcPrice * 10 ** 6;
    }

    function setUSDPrice(uint256 _newPrice) external onlyOwner {
        _usdPrice = _newPrice;
    }

    /// @dev See {ERC721A-tokenURI}
    function tokenURI(uint256 tokenId) public view virtual override(ERC721A, IERC721A) returns (string memory) {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();
        string memory baseURI = _baseURI();
        return bytes(baseURI).length != 0 ? string(abi.encodePacked(baseURI, _toString(tokenId), _ending)) : "";
    }

    /// @dev @dev See {ERC721A-_baseURI}
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseNftURI;
    }

    function setBaseURI(string calldata newURI) external onlyOwner {
        _baseNftURI = newURI;
    }

    function setURIExtention(string calldata newExtention) external onlyOwner {
        _ending = newExtention;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public pure override(ERC721A, IERC721A) returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public pure override(ERC721A, IERC721A) returns (string memory) {
        return _symbol;
    }
}
