/// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

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
  mapping(address => mapping(uint256 => uint256)) public _depositBlocks;

  SoonanTsoorVilla private villaNFT;
  FractionManager private studioFraction;
  StakingToken private tokenRewards;
  address nullAddress = address(0); //0x0000000000000000000000000000000000000000;

  constructor(address _villa, address _studio, address _rewards, uint256 _villaRate, uint256 _studioRate, uint256 _expiration) {
    villaNFT = SoonanTsoorVilla(_villa);
    studioFraction = FractionManager(_studio);
    tokenRewards = StakingToken(_rewards);
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
  // 328,000 $STKN PER DAY for 1 NFT
  // n Blocks per day = 6000, Token Decimal = 18
  // Rate = 54_666_666_666_666_666_667
  /// @notice Set a multiplier for how many tokens to earn each time a block passes.
  /// @dev The formula (assuming per day) :
  ///      `rate = (X $STKN * 10^TokenDecimal) / n blocks per day`
  /// @param _rate new rate
  function setVillaRate(uint256 _rate) public onlyOwner {
    villaRate = _rate;
  }

  /// @notice check deposit amount.
  function depositsOfVilla(address _account) external view returns (uint256[] memory) {
    EnumerableSet.UintSet storage depositSet = _deposits[_account];
    uint256[] memory tokenIds = new uint256[] (depositSet.length());

    for (uint256 i; i < depositSet.length(); i++) {
      tokenIds[i] = depositSet.at(i);
    }

    return tokenIds;
  }

  /// @notice reward amount by address/tokenIds[]
  function calculateVillaRewards(
    address _account,
    uint256[] memory _tokenIds
  ) public view returns (uint256[] memory rewards) {
    rewards = new uint256[](_tokenIds.length);

    for (uint256 i; i < _tokenIds.length; i++) {
      uint256 tokenId = _tokenIds[i];
      rewards[i] = villaRate * (_deposits[_account].contains(tokenId) ? 1 : 0)
        * (Math.min(block.timestamp, expiration) - _depositBlocks[_account][tokenId]);
    }

    return rewards;
  }

  /// @notice reward amount by address/tokenId - Tested
  function calculateVillaReward(address _account, uint256 _tokenId) public view returns (uint256) {
    require(
      Math.min(block.timestamp, expiration) > _depositBlocks[_account][_tokenId], "Invalid blocks"
    );
    return villaRate * (_deposits[_account].contains(_tokenId) ? 1 : 0)
      * (Math.min(block.timestamp, expiration) - _depositBlocks[_account][_tokenId]);
  }

  /// @notice all villas reward claim function - Tested
  function claimVillaRewards(uint256[] calldata _tokensId) public whenNotPaused {
    uint256 reward;
    uint256 blockCur = Math.min(block.timestamp, expiration);

    for (uint256 i; i < _tokensId.length; i++) {
      reward += calculateVillaReward(msg.sender, _tokensId[i]);
      _depositBlocks[msg.sender][_tokensId[i]] = blockCur;
    }

    if (reward > 0) {
      tokenRewards.mint(msg.sender, reward);
    }
  }

  /// @notice deposit all NFTs to StakingManager contract address
  /// notes: if it is untrusted NFT, then you need to add nonReentrant
  function depositVillas(uint256[] calldata _tokenIds) external whenNotPaused {
    require(msg.sender != address(villaNFT), "Invalid address");
    claimVillaRewards(_tokenIds);

    for (uint256 i; i < _tokenIds.length; i++) {
      villaNFT.safeTransferFrom(msg.sender, address(this), _tokenIds[i], "");
      _deposits[msg.sender].add(_tokenIds[i]);
    }
  }
  
  /// @notice single villas reward claim function - Tested
  function claimVillaReward(uint256 _tokenId) public whenNotPaused {
    uint256 reward;
    uint256 blockCur = Math.min(block.timestamp, expiration);
    
    reward = calculateVillaReward(msg.sender, _tokenId);
    _depositBlocks[msg.sender][_tokenId] = blockCur;

    if (reward > 0) {
      tokenRewards.mint(msg.sender, reward);
    }
  }
  
  /// @notice deposit one NFTs to StakingManager contract address
  /// notes: if it is untrusted NFT, then you need to add nonReentrant
  function depositVilla(uint256 _tokenId) external whenNotPaused {
    require(msg.sender != address(villaNFT), "Invalid address");
    claimVillaReward(_tokenId);
    villaNFT.safeTransferFrom(msg.sender, address(this), _tokenId, "");
    _deposits[msg.sender].add(_tokenId);

  }

  //withdrawal all villas function. Tested
  function withdrawAllVillas(uint256[] calldata _tokenIds) external whenNotPaused nonReentrant {
    claimVillaRewards(_tokenIds);
    for (uint256 i; i < _tokenIds.length; i++) {
      require(msg.sender == originalOwner[_tokenIds[i]], "address is not the token owner");
      require(_deposits[msg.sender].contains(_tokenIds[i]), "Staking: token not deposited");
      _deposits[msg.sender].remove(_tokenIds[i]);
      villaNFT.safeTransferFrom(address(this), msg.sender, _tokenIds[i], "");
    }
  }
  
  //withdrawal all villas function. Tested
  function withdrawAllVilla(uint256 _tokenId) external whenNotPaused nonReentrant {
    claimVillaReward(_tokenId);
    require(msg.sender == originalOwner[_tokenId], "address is not the token owner");
    require(_deposits[msg.sender].contains(_tokenId), "Staking: token not deposited");
    _deposits[msg.sender].remove(_tokenId);
    villaNFT.safeTransferFrom(address(this), msg.sender, _tokenId, "");
  }
  
  /* STAKING STUDIO MECHANICS */
  
  /// @notice
  // 82 $STKN PER DAY for 1 fraction
  // n Blocks per day = 6000, Token Decimal = 18
  // Rate = 13_666_666_666_666_667
  /// @notice Set a multiplier for how many tokens to earn each time a block passes.
  /// @dev The formula (assuming per day) :
  ///      `rate = (X $STKN * 10^TokenDecimal) / n blocks per day`
  /// @param _rate new rate
  function setStudioRate(uint256 _rate) public onlyOwner {
    studioRate = _rate;
  }


  //withdrawal function.
  function withdrawTokens() external onlyOwner {
    uint256 tokenSupply = tokenRewards.balanceOf(address(this));
    tokenRewards.transfer(msg.sender, tokenSupply);
  }

  /**
   * @dev See {IERC721-onERC721Received}.
   */
  function onERC721Received(
    address, /* operator */
    address from,
    uint256 tokenId,
    bytes calldata /* data */
  ) external returns (bytes4) {
    originalOwner[tokenId] = from;
    return ERC721A__IERC721Receiver.onERC721Received.selector;
  }

}
