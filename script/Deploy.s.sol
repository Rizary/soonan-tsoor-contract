// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "../src/1.0/FractionalizedNFT.sol";
import "../src/1.0/FractionToken.sol";
import "../src/1.0/SoonanTsoorNFT.sol";
import "../src/1.0/StakingFractionNFT.sol";

contract Deploy is Script {
    address public fractionalizedNFT;
    address public fractionToken;
    address public soonanTsoorNFT;
    address public stakingFractionNFT;
    address public USDCAddress;

    constructor() Script() {
    }

    function run() external {
        USDCAddress = vm.envAddress("USDC_ADDRESS");
        vm.startBroadcast();
        // deploy SoonanTsoorNFT contract
        SoonanTsoorNFT soonanTsoorNFTContract = new SoonanTsoorNFT(USDCAddress);
        soonanTsoorNFT = address(soonanTsoorNFTContract);
        
        FractionToken fractionTokenContract = new FractionToken();
        fractionToken = address(fractionTokenContract);

        // deploy FractionalizedNFT contract
        FractionalizedNFT fractionalizedNFTContract = new FractionalizedNFT(fractionToken, soonanTsoorNFT, USDCAddress);
        fractionalizedNFT = address(fractionalizedNFTContract);

        // deploy StakingFractionNFT contract
        StakingFractionNFT stakingFractionNFTContract = new StakingFractionNFT(fractionToken);
        stakingFractionNFT = address(stakingFractionNFTContract);
        
        vm.stopBroadcast();
    }
}
