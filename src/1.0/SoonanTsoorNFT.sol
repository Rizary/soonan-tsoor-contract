// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {ERC721A, ERC721A__IERC721Receiver} from "@erc721A/contracts/ERC721A.sol";
import {IERC721A} from "@erc721A/contracts/IERC721A.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";

contract SoonanTsoorNFT is Context, ERC165, ERC721A,  Ownable {
    using Address for address;

    // Token name
    string private constant _name = "SoonanTsoorNFT";

    // Token symbol
    string private constant _symbol = "SNSR";

    // max supply cap
    uint256 public constant MAX_SUPPLY = 5_100;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // cost for minting NFT
    uint256 public cost = 85 * 10**6;

    // whether or not mints should auto distribute
    bool public autoDistribute = true;

    // base URI
    string private baseURI = "url";
    string private ending = ".json";

    // Enable Trading
    bool public mintingEnabled = false;

    // Mint Token
    IERC20 public immutable mintToken;

    // Web 2.0 Wallet
    address public teamWalletW2 = 0x7C8c679CE072544Aa7a73b85d5Ea9b3195Fa7Bd2;

    // Web 3.0 Wallet
    address public teamWalletW3 = 0x26a3E0CBf8240E303EcdF36a2ccaef74A32692db;

    // Swap Path
    address[] private path;

    constructor(address usdc) ERC721A(_name, _symbol) {
        mintToken = IERC20(usdc);
    }

    ////////////////////////////////////////////////
    ///////////   RESTRICTED FUNCTIONS   ///////////
    ////////////////////////////////////////////////
    function enableMinting() external onlyOwner {
        mintingEnabled = true;
    }

    function disableMinting() external onlyOwner {
        mintingEnabled = false;
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
    
    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    function setCost(uint256 newCost) external onlyOwner {
        cost = newCost;
    }

    function setBaseURI(string calldata newURI) external onlyOwner {
        baseURI = newURI;
    }

    function setURIExtention(string calldata newExtention) external onlyOwner {
        ending = newExtention;
    }

    function setAutoDistribute(bool auto_) external onlyOwner {
        autoDistribute = auto_;
    }

    function setTeamWalletW2(address teamWallet_) external onlyOwner {
        require(teamWallet_ != address(0), "Zero Address");
        teamWalletW2 = teamWallet_;
    }

    function setTeamWalletW3(address teamWallet_) external onlyOwner {
        require(teamWallet_ != address(0), "Zero Address");
        teamWalletW3 = teamWallet_;
    }

    ////////////////////////////////////////////////
    ///////////     PUBLIC FUNCTIONS     ///////////
    ////////////////////////////////////////////////

    /**
     * Mints `numberOfMints` NFTs To Caller
     */
    function mint(uint256 numberOfMints) external {
        require(mintingEnabled, "Minting Not Enabled");
        require(numberOfMints > 0, "Invalid Input");

        // transfer in cost
        _transferIn(cost * numberOfMints);

        // mint NFTs

        _safeMint(msg.sender, numberOfMints);


        // divvy up funds
        if (autoDistribute) {
            _distribute();
        }
    }
    
    function ownerMint(address to, uint256 quantity) external onlyOwner {
        // mint NFTs
       require(owner() == to, "address is not the owner");
        _safeMint(to, quantity);
    }

    receive() external payable {}

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) payable public override {
        address pcowner = ownerOf(tokenId);
        require(to != pcowner, "ERC721: approval to current owner");

        require(
            _msgSender() == pcowner || isApprovedForAll(pcowner, _msgSender()),
            "ERC721: not approved or owner"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address _operator, bool approved)
        public
        override
    {
        _setApprovalForAll(_msgSender(), _operator, approved);
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) payable public override {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "caller not owner nor approved"
        );
        _transfer(from, to, tokenId);
    }

    ////////////////////////////////////////////////
    ///////////     READ FUNCTIONS       ///////////
    ////////////////////////////////////////////////

    function getIDsByOwner(address owner)
        external
        view
        returns (uint256[] memory)
    {
        uint256[] memory ids = new uint256[](balanceOf(owner));
        if (balanceOf(owner) == 0) return ids;
        uint256 count = 0;
        for (uint256 i = 0; i < super.totalSupply(); i++) {
            if (_owners[i] == owner) {
                ids[count] = i;
                count++;
            }
        }
        return ids;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC165, ERC721A)
        returns (bool)
    {
        return
            interfaceId == type(IERC721A).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address pcowner) public view override returns (uint256) {
        require(pcowner != address(0), "query for the zero address");
        return _balances[pcowner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        return super.ownerOf(tokenId);
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public pure override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public pure override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(tokenId), "nonexistent token");

        string memory fHalf = string.concat(baseURI, uint2str(tokenId));
        return string.concat(fHalf, ending);
    }

    /**
        Converts A Uint Into a String
    */
    function uint2str(uint256 _i)
        internal
        pure
        returns (string memory _uintAsString)
    {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId)
        public
        view
        override
        returns (address)
    {
        require(_exists(tokenId), "ERC721: query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address pcowner, address _operator)
        public
        view
        override
        returns (bool)
    {
        return _operatorApprovals[pcowner][_operator];
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted
     */
    function _exists(uint256 tokenId) internal view override returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId)
        internal
        view
        returns (bool)
    {
        require(_exists(tokenId), "ERC721: nonexistent token");
        address pcowner = ownerOf(tokenId);
        return (spender == pcowner ||
            getApproved(tokenId) == spender ||
            isApprovedForAll(pcowner, spender));
    }

    ////////////////////////////////////////////////
    ///////////    INTERNAL FUNCTIONS    ///////////
    ////////////////////////////////////////////////

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(address to, uint256 quantity) internal override {
        super._mint(to, quantity);
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 quantity) internal override {
        require(super.totalSupply() < MAX_SUPPLY, "All NFTs Have Been Minted");

        _balances[to] += quantity;

        super._mint(to, quantity);
        emit Transfer(address(0), to, quantity);
    }
    
    function _afterTokenTransfers(
        address /*from*/, 
        address to, 
        uint256 startTokenId, 
        uint256 quantity
    ) internal virtual override {
        for (uint256 i = startTokenId; i <= quantity; i++) {
            _owners[i] = to;
        }    
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

    function _distribute() internal {
        // send half of the usdc to web 2.0 business wallet
        uint256 forWeb2 = mintToken.balanceOf(address(this)) / 2;
        if (forWeb2 > 0) {
            mintToken.transfer(teamWalletW2, forWeb2);
        }

        // send the rest to web 3.0 business wallet
        uint256 forWeb3 = mintToken.balanceOf(address(this));
        if (forWeb3 > 0) {
            mintToken.transfer(teamWalletW3, forWeb3);
        }
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal {
        _transfer(from, to, tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal {
        require(ownerOf(tokenId) == from, "Incorrect owner");
        require(to != address(0), "zero address");
        require(balanceOf(from) > 0, "Zero Balance");
        require(tokenId <= 100, "this NFT are fractionalized and cannot be transferred");

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        // Allocate balances
        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        // emit transfer
        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal override {
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits a {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address pcowner,
        address _operator,
        bool approved
    ) internal {
        require(pcowner != _operator, "ERC721: approve to caller");
        _operatorApprovals[pcowner][_operator] = approved;
        emit ApprovalForAll(pcowner, _operator, approved);
    }

    function onReceivedRetval() public pure returns (bytes4) {
        return ERC721A__IERC721Receiver.onERC721Received.selector;
    }
}
