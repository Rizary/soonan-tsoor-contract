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

    // Web 2.0 Wallet
    address public teamWalletW2 = 0x7C8c679CE072544Aa7a73b85d5Ea9b3195Fa7Bd2;

    // Web 3.0 Wallet
    address public teamWalletW3 = 0x26a3E0CBf8240E303EcdF36a2ccaef74A32692db;

    // base URI
    string private _baseNftURI = "url/";
    string private _ending = ".json";

    constructor(address _usdc, address _feed, address fractionManager) ERC721A(_name, _symbol) {
        _usdcToken = IERC20(_usdc);
        _priceFeed = AggregatorV3Interface(_feed);
        _usdPrice = 100; // 239 USD by default
        _setDefaultRoyalty(msg.sender, 250);
        _mintERC2309(fractionManager, 5000);
    }

    /// @dev See {ERC721A-_startTokenId}.
    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    /// @notice Minting the NFT publicly
    /// @dev Explain to a developer any extra details
    function publicMint(uint256 _amount) external payable {
        require(msg.sender == tx.origin, "public: bot is not allowed");
        require(totalSupply() < MAX_SUPPLY, "public: supply exceeded");
        require(publicMintingEnabled, "public: minting is not enabled");
        uint256 price = getCurrentPrice();
        _transferIn(price * _amount);
        _safeMint(msg.sender, _amount);
        _distribute();
    }

    /// @notice Minting that available only for address listed in presale
    /// @dev We use merkle root to verify the minter and bitmap to track minted amount
    /// @param _amount amount to be minted
    function presale(uint256 _amount) external payable {
        require(msg.sender == tx.origin, "presale: bot is not allowed");
        require(totalSupply() < MAX_SUPPLY, "presale: supply exceeded");
        require(_getAux(msg.sender) >= _amount, "presale: cannot minted more than allowed");
        require(!publicMintingEnabled, "presale: public minting already live");
        uint256 price = getCurrentPrice();
        // transfer in cost
        _transferIn(price * _amount);
        _safeMint(msg.sender, _amount);
        uint64 newAux = _getAux(msg.sender) - uint64(_amount);
        _setAux(msg.sender, newAux);
        _distribute();
    }

    function getAux(address owner) external view returns (uint64) {
        return _getAux(owner);
    }

    function setAux(address owner, uint64 aux) external onlyOwner {
        return _setAux(owner, aux);
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

    function _transferIn(uint256 _amount) internal {
        require(_usdcToken.allowance(msg.sender, address(this)) >= _amount, "transferIn: insufficient allowance");
        require(_usdcToken.transferFrom(msg.sender, address(this), _amount), "transferFrom: cannot transfer token");
    }

    function enablePublicMinting() external onlyOwner {
        publicMintingEnabled = true;
    }

    function disablePublicMinting() external onlyOwner {
        publicMintingEnabled = false;
    }

    function setTeamWalletW2(address teamWallet_) external onlyOwner {
        require(teamWallet_ != address(0), "Zero Address");
        teamWalletW2 = teamWallet_;
    }

    function setTeamWalletW3(address teamWallet_) external onlyOwner {
        require(teamWallet_ != address(0), "Zero Address");
        teamWalletW3 = teamWallet_;
    }

    function distribute() external onlyOwner {
        _distribute();
    }

    /// @notice Distribution of USDC token received from minting
    function _distribute() private {
        uint256 currentBalance = _usdcToken.balanceOf(address(this));
        require(currentBalance > 0, "No USDC to distribute");

        uint256 forWeb2 = currentBalance / 2;
        uint256 forWeb3 = currentBalance / 2;

        _usdcToken.transfer(teamWalletW2, forWeb2);
        _usdcToken.transfer(teamWalletW3, forWeb3);
    }

    function getCurrentPrice() public view returns (uint256) {
        (, int256 price,, uint256 updatedAt,) = _priceFeed.latestRoundData();
        require(price > 0, "Feed price should be greater than 0");
        require(updatedAt > block.timestamp - 86_400, "Stale Price");
        uint256 usdcPrice = _usdPrice * 10 ** _priceFeed.decimals() / uint256(price);
        return usdcPrice * 10 ** 6;
    }

    function setUSDPrice(uint256 _newPrice) external onlyOwner {
        _usdPrice = _newPrice;
    }

    function ownerMint(address to, uint256 quantity) external onlyOwner {
        // mint NFTs
        _safeMint(to, quantity);
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
