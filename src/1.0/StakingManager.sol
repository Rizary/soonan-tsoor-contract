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

    // lock duration in month.
    uint256 public villaLockDuration;
    uint256 public villaClaimDuration;
    uint256 public fractionLockDuration;
    uint256 public fractionClaimDuration;
    //rate governs how often you receive your token
    uint256 public villaRate;
    uint256 public fractionRate;

    // mappings
    mapping(uint256 => address) public originalOwner;
    mapping(address => EnumerableSet.UintSet) private _deposits;
    mapping(address => mapping(uint256 => uint256)) private _depositBlocksFractions;
    mapping(uint256 => uint256) public depositStart;
    mapping(uint256 => uint256) public lastRewardClaim;

    SoonanTsoorVilla private _villaNFT;
    FractionManager private _fractionManager;
    StakingToken private _tokenRewards;
    address _nullAddress = address(0); //0x0000000000000000000000000000000000000000;

    constructor(address _villa, address _studioFraction, address _rewards) {
        _villaNFT = SoonanTsoorVilla(_villa);
        _fractionManager = FractionManager(_studioFraction);
        _tokenRewards = StakingToken(_rewards);
        villaRate = 3_805_1175_038_05_750_381;
        fractionRate = 1_268_391_679_350_584;
        villaLockDuration = 1;
        villaClaimDuration = 1;
        fractionLockDuration = 1;
        fractionClaimDuration = 1;
        _pause();
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    /* STAKING VILLA MECHANICS */

    /// @notice
    /// Default is 327,963 $STKN PER DAY for 1 NFT
    /// Token Decimal = 18
    /// Rate = 3_805_1175_038_05_750_381
    /// @notice Set a multiplier for how many tokens to earn each time a block passes.
    /// @dev The formula (assuming per day) :
    ///      `rate = (X $STKN * 10^TokenDecimal) / 31_536_000`
    /// @param _rate new rate
    function setVillaRate(uint256 _rate) public onlyOwner {
        villaRate = _rate;
    }

    /// @notice set this for villa staking period
    function setVillaLockDuration(uint256 _newValue) public onlyOwner {
        villaLockDuration = _newValue;
    }

    /// @notice set this for villa reward claim period
    function setVillaClaimDuration(uint256 _newValue) public onlyOwner {
        villaClaimDuration = _newValue;
    }

    /// @notice deposit all NFTs to StakingManager contract address
    /// notes: if it is untrusted NFT, then you need to add nonReentrant
    function depositVilla(uint256 _tokenId) public whenNotPaused {
        require(msg.sender != address(_villaNFT), "Invalid address");
        claimVillaReward(_tokenId);

        _villaNFT.safeTransferFrom(msg.sender, address(this), _tokenId, "");
        originalOwner[_tokenId] = msg.sender;
        _deposits[msg.sender].add(_tokenId);
        if (depositStart[_tokenId] == 0) {
            depositStart[_tokenId] = block.timestamp;
        }
    }

    function depositVillas(uint256[] calldata _tokenIds) external whenNotPaused {
        require(msg.sender != address(_villaNFT), "Invalid address");
        for (uint256 i; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            depositVilla(tokenId);
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

    /// @notice reward amount by address
    function calculateVillaReward(address _account, uint256 _tokenId) public view returns (uint256 reward) {
        // Ensure the token is actually staked by the account
        if (!_deposits[_account].contains(_tokenId)) {
            return 0;
        }

        uint256 lastEventTime =
            lastRewardClaim[_tokenId] > depositStart[_tokenId] ? lastRewardClaim[_tokenId] : depositStart[_tokenId];

        uint256 timeDelta = block.timestamp > lastEventTime ? block.timestamp - lastEventTime : 0;

        return timeDelta * villaRate;
    }

    /// @notice all fractions reward claim function - Tested
    function claimVillaReward(uint256 _tokenId) public whenNotPaused nonReentrant {
        uint256 reward = calculateVillaReward(msg.sender, _tokenId);
        uint256 lastEventTime =
            lastRewardClaim[_tokenId] > depositStart[_tokenId] ? lastRewardClaim[_tokenId] : depositStart[_tokenId];
        if (reward > 0) {
            require(msg.sender == originalOwner[_tokenId], "address is not the token owner");

            require(
                block.timestamp - lastEventTime >= villaClaimDuration * 1 days, "can only claim reward once every month"
            );
            lastRewardClaim[_tokenId] = block.timestamp;
            _tokenRewards.mint(msg.sender, reward);
        }
    }

    //withdrawal all fractions function. Tested
    function withdrawVilla(uint256 _tokenId) external whenNotPaused {
        claimVillaReward(_tokenId);
        require(msg.sender == originalOwner[_tokenId], "address is not the token owner");
        require(_deposits[msg.sender].contains(_tokenId), "staking: token not deposited");
        require(
            block.timestamp >= depositStart[_tokenId] + (villaLockDuration * 1 days),
            "staking: this token is still within the lock duration"
        );
        _deposits[msg.sender].remove(_tokenId);
        _villaNFT.safeTransferFrom(address(this), msg.sender, _tokenId, "");
        depositStart[_tokenId] = 0;
    }

    function getRemainingVillaLockTime(uint256 tokenId) public view returns (uint256) {
        uint256 elapsedTime = block.timestamp - depositStart[tokenId];
        if (elapsedTime >= villaLockDuration * 1 days) {
            return 0;
        }
        return villaLockDuration * 1 days - elapsedTime;
    }

    function getRemainingVillaClaimTime(uint256 tokenId) public view returns (uint256) {
        uint256 lastEventTime =
            lastRewardClaim[tokenId] > depositStart[tokenId] ? lastRewardClaim[tokenId] : depositStart[tokenId];
        uint256 elapsedTime = block.timestamp - lastEventTime;
        if (elapsedTime >= villaClaimDuration * 1 days) {
            return 0;
        }
        return villaClaimDuration * 1 days - elapsedTime;
    }

    /* STAKING STUDIO MECHANICS */

    mapping(address => uint256) private _totalFractionStaked;
    mapping(address => mapping(uint256 => uint256)) private _fractionStaked;
    mapping(address => uint256) private _startStaked;
    mapping(address => uint256) private _lastFractionClaimed;

    /// @dev The formula (assuming per day) :
    ///      `rate = (X $STKN * 10^TokenDecimal) / 31_536_000`
    /// @param _rate new rate

    function setFractionRate(uint256 _rate) public onlyOwner {
        fractionRate = _rate;
    }

    /// @notice set this for fraction staking period
    function setFractionLockDuration(uint256 _newValue) public onlyOwner {
        fractionLockDuration = _newValue;
    }

    /// @notice set this for fraction reward claim period
    function setFractionClaimDuration(uint256 _newValue) public onlyOwner {
        fractionClaimDuration = _newValue;
    }

    /// @notice deposit all NFTs to StakingManager contract address
    function depositFractions(uint256[] calldata _tokenIds) public whenNotPaused {
        require(msg.sender != address(_fractionManager), "Invalid address");
        claimFractionsRewards(_tokenIds);
        _startStaked[msg.sender] = block.timestamp;
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            uint256 amount = _fractionManager.fractByTokenId(msg.sender, tokenId);

            if (_fractionStaked[msg.sender][tokenId] > 0) {
                require(
                    _fractionManager.transferFraction(tokenId, amount, msg.sender, address(this)),
                    "staking fraction: failed to stake the fraction"
                );

                _fractionStaked[msg.sender][tokenId] += amount;
                continue;
            }

            require(
                _fractionManager.transferFraction(tokenId, amount, msg.sender, address(this)),
                "staking fraction: failed to stake the fraction"
            );
            _fractionStaked[msg.sender][tokenId] += amount;
            _totalFractionStaked[msg.sender] += amount;
        }
    }

    /// @notice check deposit amount.
    function allStakedFractions(address _account) external view returns (uint256) {
        return _totalFractionStaked[_account];
    }

    function stakedFractionByTokenId(address _account, uint256 tokenId) external view returns (uint256) {
        return _fractionStaked[_account][tokenId];
    }

    /// @notice reward amount by address/tokenIds[]
    function calculateFractionsReward(address _account, uint256 tokenId) public view returns (uint256 rewards) {
        if (_fractionStaked[_account][tokenId] < 1) {
            return 0;
        }
        uint256 lastEventTime = _lastFractionClaimed[_account] > _startStaked[_account]
            ? _lastFractionClaimed[_account]
            : _startStaked[_account];

        uint256 timeDelta = block.timestamp > lastEventTime ? block.timestamp - lastEventTime : 0;

        return (_fractionStaked[_account][tokenId] / 1000) * timeDelta * fractionRate;
    }

    /// @notice all fractions reward claim function - Tested
    function calculateFractionsRewards(uint256[] calldata _tokenIds)
        public
        view
        whenNotPaused
        returns (uint256 rewards)
    {
        require(msg.sender != address(_fractionManager), "Invalid address");
        uint256 rewards;
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            if (_fractionStaked[msg.sender][tokenId] < 1) continue;
            rewards += calculateFractionsReward(msg.sender, tokenId);
        }
        return rewards;
    }

    /// @notice single fraction reward claim function - Tested
    function claimFractionsReward(uint256 tokenId) internal whenNotPaused {
        uint256 rewards = calculateFractionsReward(msg.sender, tokenId);

        _tokenRewards.mint(msg.sender, rewards);
        _lastFractionClaimed[msg.sender] = block.timestamp;
    }

    /// @notice all fractions reward claim function - Tested
    function claimFractionsRewards(uint256[] calldata _tokenIds) public whenNotPaused nonReentrant {
        require(msg.sender != address(_fractionManager), "Invalid address");
        uint256 lastEventTime = _lastFractionClaimed[msg.sender] > _startStaked[msg.sender]
            ? _lastFractionClaimed[msg.sender]
            : _startStaked[msg.sender];
        uint256 timeDelta = block.timestamp - lastEventTime;
        require(timeDelta >= fractionClaimDuration * 1 days, "can only withdraw the fraction once every month");

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            if (_fractionStaked[msg.sender][tokenId] < 1) continue;
            claimFractionsReward(tokenId);
        }
    }

    //withdrawal all fractions function. Tested
    function withdrawFractions(uint256[] calldata _tokenIds) external whenNotPaused nonReentrant {
        uint256 rewards = calculateFractionsRewards(_tokenIds);
        uint256 startingTime = _startStaked[msg.sender];
        _tokenRewards.mint(msg.sender, rewards);
        require(
            block.timestamp - startingTime >= fractionLockDuration * 1 days,
            "staking: the token is still within lock period"
        );
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            require(
                _fractionManager.transferFraction(
                    tokenId, _fractionStaked[msg.sender][tokenId], address(this), msg.sender
                ),
                "staking fraction: failed to stake the fraction"
            );
            delete _fractionStaked[msg.sender][tokenId];
        }
        delete _startStaked[msg.sender];
        delete _lastFractionClaimed[msg.sender];
        _totalFractionStaked[msg.sender] = 0;
    }

    function getRemainingFractionLockTime() public view returns (uint256) {
        uint256 elapsedTime = block.timestamp - _startStaked[msg.sender];
        if (elapsedTime >= fractionLockDuration * 1 days) {
            return 0;
        }
        return fractionLockDuration * 1 days - elapsedTime;
    }

    function getRemainingFractionClaimTime() public view returns (uint256) {
        uint256 lastEventTime = _lastFractionClaimed[msg.sender] > _startStaked[msg.sender]
            ? _lastFractionClaimed[msg.sender]
            : _startStaked[msg.sender];
        uint256 elapsedTime = block.timestamp - lastEventTime;
        if (elapsedTime >= fractionClaimDuration * 1 days) {
            return 0;
        }
        return fractionClaimDuration * 1 days - elapsedTime;
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
