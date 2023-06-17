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
    function depositVillas(uint256[] calldata _tokenIds) external whenNotPaused {
        require(msg.sender != address(_villaNFT), "Invalid address");
        claimVillaRewards(_tokenIds);

        for (uint256 i; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            _villaNFT.safeTransferFrom(msg.sender, address(this), tokenId, "");
            originalOwner[tokenId] = msg.sender;
            _deposits[msg.sender].add(tokenId);
            if (depositStart[tokenId] == 0) {
                depositStart[tokenId] = block.timestamp;
            }
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
        rewards = new uint256[](_tokenIds.length);

        for (uint256 i; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];

            // Ensure the token is actually staked by the account
            if (!_deposits[_account].contains(tokenId)) {
                rewards[i] = 0;
                continue;
            }

            uint256 lastEventTime =
                lastRewardClaim[tokenId] > depositStart[tokenId] ? lastRewardClaim[tokenId] : depositStart[tokenId];

            uint256 timeDelta = block.timestamp > lastEventTime ? block.timestamp - lastEventTime : 0;

            rewards[i] = timeDelta * villaRate;
        }

        return rewards;
    }

    /// @notice all fractions reward claim function - Tested
    function claimVillaRewards(uint256[] calldata _tokenIds) public whenNotPaused {
        uint256[] memory rewards = calculateVillaRewards(msg.sender, _tokenIds);

        for (uint256 i; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            uint256 lastEventTime =
                lastRewardClaim[tokenId] > depositStart[tokenId] ? lastRewardClaim[tokenId] : depositStart[tokenId];
            if (rewards[i] > 0) {
                require(msg.sender == originalOwner[tokenId], "address is not the token owner");

                require(
                    block.timestamp - lastEventTime >= villaClaimDuration * 1 days,
                    "can only claim reward once every month"
                );
                lastRewardClaim[tokenId] = block.timestamp;
                _tokenRewards.mint(msg.sender, rewards[i] * 10 ** 18);
            }
        }
    }

    //withdrawal all fractions function. Tested
    function withdrawVillas(uint256[] calldata _tokenIds) external whenNotPaused nonReentrant {
        claimVillaRewards(_tokenIds);
        for (uint256 i; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            require(msg.sender == originalOwner[tokenId], "address is not the token owner");
            require(_deposits[msg.sender].contains(tokenId), "staking: token not deposited");
            require(
                block.timestamp >= depositStart[tokenId] + (villaLockDuration * 1 days),
                "staking: this token is still within the lock duration"
            );
            _deposits[msg.sender].remove(tokenId);
            _villaNFT.safeTransferFrom(address(this), msg.sender, tokenId, "");
            depositStart[tokenId] = 0;
        }
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

    mapping(address => uint256) private _totalFractionOwned;
    mapping(address => uint256) private _totalFractionStaked;
    mapping(address => mapping(uint256 => uint256)) private _fractionStaked;
    mapping(address => mapping(uint256 => uint256)) private _startStaked;
    mapping(address => mapping(uint256 => uint256)) private _lastFractionClaimed;
    mapping(address => mapping(uint256 => uint256)) public lastGroupRewardClaim;
    mapping(address => mapping(uint256 => uint256)) private _stakeGroupId;
    mapping(address => uint256) private _numStakeGroups;

    struct Stake {
        uint256 amount;
        uint256 timestamp;
        bool isActive;
    }

    /// @notice
    /// Default is 109,592 $STKN PER DAY for 1000 fraction
    /// Token Decimal = 18
    /// Rate = 1_268_391_679_350_584
    /// @notice Set a multiplier for how many tokens to earn each time a block passes.
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
    function depositFractions(uint256[] calldata _tokenIds) external whenNotPaused {
        require(msg.sender != address(_fractionManager), "Invalid address");

        uint256 totalFraction = 0;

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            totalFraction += _fractionManager.fractByTokenId(msg.sender, tokenId);
        }

        require(totalFraction >= 1000, "minimum stake fraction should equal or greater than 1000");

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            uint256 amount = _fractionManager.fractByTokenId(msg.sender, tokenId);
            uint256 startingTime = _startStaked[msg.sender][tokenId];

            if (_fractionStaked[msg.sender][tokenId] > 0) {
                require(
                    block.timestamp - startingTime >= fractionClaimDuration * 1 days,
                    "can only re-stake the fraction once every month"
                );
                claimFractionsReward(tokenId);
                require(
                    _fractionManager.transferFraction(tokenId, amount, msg.sender, address(this)),
                    "staking fraction: failed to stake the fraction"
                );
                _startStaked[msg.sender][tokenId] = block.timestamp;
                _fractionStaked[msg.sender][tokenId] += amount;
                continue;
            }

            require(
                _fractionManager.transferFraction(tokenId, amount, msg.sender, address(this)),
                "staking fraction: failed to stake the fraction"
            );

            _startStaked[msg.sender][tokenId] = block.timestamp;
            _fractionStaked[msg.sender][tokenId] += amount;
        }

        _totalFractionStaked[msg.sender] += totalFraction;
    }

    /// @notice check deposit amount.
    function allStakedFractions(address _account) external view returns (uint256) {
        return _totalFractionStaked[_account];
    }

    function stakedFractionByTokenId(address _account, uint256 tokenId) external view returns (uint256) {
        return _fractionStaked[_account][tokenId];
    }

    /// @notice reward amount by address/tokenIds[]
    function calculateFractionsRewards(address _account, uint256 tokenId) public view returns (uint256 rewards) {
        if (_fractionStaked[_account][tokenId] < 1) {
            return 0;
        }
        uint256 lastEventTime = _lastFractionClaimed[_account][tokenId] > _startStaked[_account][tokenId]
            ? _lastFractionClaimed[_account][tokenId]
            : _startStaked[_account][tokenId];

        uint256 timeDelta = block.timestamp > lastEventTime ? block.timestamp - lastEventTime : 0;

        return (_fractionStaked[_account][tokenId] / 1000) * timeDelta * fractionRate;
    }

    /// @notice single fraction reward claim function - Tested
    function claimFractionsReward(uint256 tokenId) internal whenNotPaused {
        require(_fractionStaked[msg.sender][tokenId] > 0, "no fraction is staked for the given token");
        uint256 lastEventTime = _lastFractionClaimed[msg.sender][tokenId] > _startStaked[msg.sender][tokenId]
            ? _lastFractionClaimed[msg.sender][tokenId]
            : _startStaked[msg.sender][tokenId];
        require(
            block.timestamp - lastEventTime >= fractionClaimDuration * 1 days,
            "can only withdraw the fraction once every month"
        );

        uint256 rewards = calculateFractionsRewards(msg.sender, tokenId);

        _tokenRewards.mint(msg.sender, rewards * 10 ** 18);
        _lastFractionClaimed[msg.sender][tokenId] = block.timestamp;
    }

    /// @notice all fractions reward claim function - Tested
    function claimFractionsRewards(uint256[] calldata _tokenIds) public whenNotPaused {
        require(msg.sender != address(_fractionManager), "Invalid address");

        uint256 totalFraction = 0;

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            totalFraction += _fractionStaked[msg.sender][tokenId];
        }

        require(totalFraction >= 1000, "minimum stake fraction should equal or greater than 1000");

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            claimFractionsReward(tokenId);
        }
    }

    //withdrawal all fractions function. Tested
    function withdrawFractions(uint256[] calldata _tokenIds) external whenNotPaused nonReentrant {
        uint256 totalFraction = 0;

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            totalFraction += _fractionStaked[msg.sender][tokenId];
        }

        require(totalFraction <= _totalFractionStaked[msg.sender], "fraction staked was not enough to be withdrawn");

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            uint256 startingTime = _startStaked[msg.sender][tokenId];
            require(
                block.timestamp - startingTime >= fractionLockDuration * 1 days,
                "staking: the token is still within lock period"
            );
            claimFractionsReward(tokenId);
            require(
                _fractionManager.transferFraction(
                    tokenId, _fractionStaked[msg.sender][tokenId], address(this), msg.sender
                ),
                "staking fraction: failed to stake the fraction"
            );
            delete _fractionStaked[msg.sender][tokenId];
            delete _startStaked[msg.sender][tokenId];
        }
        _totalFractionStaked[msg.sender] -= totalFraction;
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
