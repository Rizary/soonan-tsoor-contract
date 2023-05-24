/// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC721A__IERC721Receiver} from "@erc721A/contracts/ERC721A.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {FractionManager} from "./FractionManager.sol";
import {SoonanTsoorVilla} from "./SoonanTsoorVilla.sol";
import {StakingToken} from "./StakingToken.sol";
import {ERC165Storage} from "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

/// @title StakingManager
/// @notice This contract manage NFT staking feature and its rewards
contract StakingManager is ERC165Storage, ERC721A__IERC721Receiver, ReentrancyGuard, Pausable, Ownable {
    using EnumerableSet for EnumerableSet.UintSet;

    //uint256's
    uint256 public expiration;
    //rate governs how often you receive your token
    uint256 public villaRate;
    uint256 public studioRate;

    // mappings
    mapping(uint256 => address) public originalOwner;
    mapping(address => EnumerableSet.UintSet) private _deposits;
    mapping(address => mapping(uint256 => uint256)) public depositBlocks;
    mapping(address => mapping(uint256 => uint256)) private _depositBlocksFractions;

    SoonanTsoorVilla private _villaNFT;
    FractionManager private _fractionManager;
    StakingToken private _tokenRewards;
    address _nullAddress = address(0); //0x0000000000000000000000000000000000000000;

    constructor(
        address _villa,
        address _studioFraction,
        address _rewards,
        uint256 _villaRate,
        uint256 _studioRate,
        uint256 _expiration
    ) {
        _villaNFT = SoonanTsoorVilla(_villa);
        _fractionManager = FractionManager(_studioFraction);
        _tokenRewards = StakingToken(_rewards);
        villaRate = _villaRate;
        studioRate = _studioRate;
        expiration = block.timestamp + _expiration;
        _pause();
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    /// @notice Set this to a block to disable the ability to continue accruing tokens past that
    /// block timestamp.
    function setExpiration(uint256 _expiration) public onlyOwner {
        expiration = block.timestamp + _expiration;
    }

    /* STAKING VILLA MECHANICS */

    /// @notice
    // 327,963 $STKN PER DAY for 1 NFT
    // Token Decimal = 18
    // Rate = 3_805_1175_038_05_750_381
    /// @notice Set a multiplier for how many tokens to earn each time a block passes.
    /// @dev The formula (assuming per day) :
    ///      `rate = (X $STKN * 10^TokenDecimal) / 31_536_000`
    /// @param _rate new rate
    function setVillaRate(uint256 _rate) public onlyOwner {
        villaRate = _rate;
    }

    /// @notice deposit all NFTs to StakingManager contract address
    /// notes: if it is untrusted NFT, then you need to add nonReentrant
    function depositVillas(uint256[] calldata _tokenIds) external whenNotPaused {
        require(msg.sender != address(_villaNFT), "Invalid address");
        claimVillaRewards(_tokenIds);

        for (uint256 i; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            _villaNFT.safeTransferFrom(msg.sender, address(this), tokenId, "");
            _deposits[msg.sender].add(tokenId);
        }
    }

    /// @notice check deposit amount.
    function depositOfVillas(address _account) external view returns (uint256[] memory) {
        EnumerableSet.UintSet storage depositSet = _deposits[_account];
        uint256[] memory tokenIds = new uint256[] (depositSet.length());

        for (uint256 i; i < depositSet.length(); i++) {
            tokenIds[i] = depositSet.at(i);
        }

        return tokenIds;
    }

    /// @notice reward amount by address/tokenIds[]
    function calculateVillaRewards(address _account, uint256[] memory _tokenIds)
        public
        view
        returns (uint256[] memory rewards)
    {
        require(_tokenIds.length > 1, "villa reward: nothing to caltulate");

        rewards = new uint256[](_tokenIds.length);

        for (uint256 i; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            rewards[i] = (Math.min(block.timestamp, expiration) - depositBlocks[_account][tokenId]) * villaRate
                * (_deposits[_account].contains(tokenId) ? 1 : 0);
        }

        return rewards;
    }

    /// @notice all fractions reward claim function - Tested
    function claimVillaRewards(uint256[] calldata _tokenIds) public whenNotPaused {
        uint256[] memory rewards = calculateVillaRewards(msg.sender, _tokenIds);
        uint256 blockCur = Math.min(block.timestamp, expiration);

        for (uint256 i; i < _tokenIds.length; i++) {
            depositBlocks[msg.sender][_tokenIds[i]] = blockCur;
            if (rewards[i] > 0) {
                _tokenRewards.mint(msg.sender, rewards[i]);
            }
        }
    }

    //withdrawal all fractions function. Tested
    function withdrawVillas(uint256[] calldata _tokenIds) external whenNotPaused nonReentrant {
        claimVillaRewards(_tokenIds);
        for (uint256 i; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            require(msg.sender == originalOwner[tokenId], "address is not the token owner");
            require(_deposits[msg.sender].contains(tokenId), "Staking: token not deposited");
            _deposits[msg.sender].remove(tokenId);
            _villaNFT.safeTransferFrom(address(this), msg.sender, tokenId, "");
        }
    }

    /* STAKING STUDIO MECHANICS */

    mapping(address => uint256) private _totalFractionStaked;
    mapping(address => mapping(uint256 => uint256)) private _stakerTimestamp;
    mapping(address => mapping(uint256 => uint256)) private _originalOwnership;
    mapping(address => uint256[]) private _tokenIdStaked;
    mapping(address => mapping(uint256 => bool)) _exists;

    /// @notice
    // 109,592 $STKN PER DAY for 1000 fraction
    // Token Decimal = 18
    // Rate = 1_268_391_679_350_584
    /// @notice Set a multiplier for how many tokens to earn each time a block passes.
    /// @dev The formula (assuming per day) :
    ///      `rate = (X $STKN * 10^TokenDecimal) / 31_536_000`
    /// @param _rate new rate
    function setStudioRate(uint256 _rate) public onlyOwner {
        studioRate = _rate;
    }

    /// @notice deposit all NFTs to StakingManager contract address
    /// notes: if it is untrusted NFT, then you need to add nonReentrant
    function depositFractions(uint256[] calldata _tokenIds) external whenNotPaused {
        require(msg.sender != address(_fractionManager), "Invalid address");
        require(
            _fractionManager.tokenIdSharedByAddress(msg.sender).length > 0,
            "minimum stake fraction should equal or greater than 1000"
        );
        claimFractionsRewards(_tokenIds);

        uint256 totalFraction;

        for (uint256 i; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            uint256 amount = _fractionManager.fractByTokenId(msg.sender, tokenId);
            require(
                _fractionManager.transferFraction(tokenId, amount, msg.sender, address(this)),
                "staking fraction: failed to stake the fraction"
            );
            _originalOwnership[msg.sender][tokenId] = amount;
            _stakerTimestamp[msg.sender][tokenId] = block.timestamp;
            totalFraction += amount;
            if (!_exists[msg.sender][tokenId]) {
                _tokenIdStaked[msg.sender].push(tokenId);
                _exists[msg.sender][tokenId] = true;
            }
        }

        _totalFractionStaked[msg.sender] = totalFraction;
    }

    /// @notice check deposit amount.
    function depositOfFractions(address _account) external view returns (uint256) {
        return _totalFractionStaked[_account];
    }

    function depositOfFractionByTokenId(address _account, uint256 tokenId) external view returns (uint256) {
        return _originalOwnership[_account][tokenId];
    }

    /// @notice reward amount by address/tokenIds[]
    function calculateFractionsRewards(address _account, uint256[] memory _tokenIds)
        public
        view
        returns (uint256[] memory rewards)
    {
        require(_tokenIds.length > 1, "fraction reward: nothing to caltulate");
        require(
            _fractionManager.tokenIdSharedByAddress(_account).length > 0,
            "fraction reward: address not owned any fraction"
        );

        rewards = new uint256[](_tokenIds.length);

        for (uint256 i; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];

            rewards[i] = (Math.min(block.timestamp, expiration) - _depositBlocksFractions[_account][tokenId])
                * studioRate * (_totalFractionStaked[_account]);
        }

        return rewards;
    }

    /// @notice all fractions reward claim function - Tested
    function claimFractionsRewards(uint256[] calldata _tokenIds) public whenNotPaused {
        uint256[] memory rewards = calculateFractionsRewards(msg.sender, _tokenIds);
        uint256 blockCur = Math.min(block.timestamp, expiration);

        for (uint256 i; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            _depositBlocksFractions[msg.sender][tokenId] = blockCur;
            if (rewards[i] > 0) {
                _tokenRewards.mint(msg.sender, rewards[i]);
            }
        }
    }

    //withdrawal all fractions function. Tested
    function withdrawFractions(uint256[] calldata _tokenIds) external whenNotPaused nonReentrant {
        claimFractionsRewards(_tokenIds);
        for (uint256 i; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            require(
                _fractionManager.transferFraction(
                    tokenId, _originalOwnership[msg.sender][tokenId], address(this), msg.sender
                ),
                "staking fraction: failed to stake the fraction"
            );
        }
    }

    /**
     * @dev See {IERC721-onERC721Received}.
     */
    function onERC721Received(address, /* operator */ address from, uint256 tokenId, bytes calldata /* data */ )
        external
        returns (bytes4)
    {
        originalOwner[tokenId] = from;
        return ERC721A__IERC721Receiver.onERC721Received.selector;
    }
}
