// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "../src/1.0/FractionalizedNFT.sol";
import "../src/1.0/FractionToken.sol";
import "../src/1.0/SoonanTsoorStudio.sol";
import "../src/1.0/SoonanTsoorVilla.sol";
import "../src/1.0/StakingFractionNFT.sol";

contract Deploy is Script {
    address public fractionalizedNFT;
    address public fractionToken;
    address payable public soonanTsoorStudio;
    address payable public soonanTsoorVilla;
    address public stakingFractionNFT;
    address public USDCAddress;
    address private OwnerAddress;

    event log_named_uint (string key, uint val);

    constructor() Script() {
    }

    function run() external {
        USDCAddress = address(0xE097d6B3100777DC31B34dC2c58fB524C2e76921);
        // vm.envAddress("USDC_ADDRESS");
        OwnerAddress = vm.envAddress("OWNER_WALLET_ADDRESS");
        vm.startBroadcast();
        
        SoonanTsoorVilla soonanVillaContract = new SoonanTsoorVilla(USDCAddress);
        soonanTsoorVilla = payable(address(soonanVillaContract));
        
        // deploy SoonanTsoorStudio contract and mint all to owner wallet
        SoonanTsoorStudio soonanStudioContract = new SoonanTsoorStudio(USDCAddress);
        soonanTsoorStudio = payable(address(soonanStudioContract));
        // for (uint i = 1; i <= 5000; i++) {
        //     soonanStudioContract.ownerMint(msg.sender, 1);
        // }

        FractionToken fractionTokenContract = new FractionToken();
        fractionToken = address(fractionTokenContract);

        // deploy FractionalizedNFT contract
        FractionalizedNFT fractionalizedNFTContract = new FractionalizedNFT(fractionToken, soonanTsoorStudio, USDCAddress);
        fractionalizedNFT = address(fractionalizedNFTContract);
        // for (uint i = 101; i <= 5100; i++) {
        //     soonanStudioContract.approve(fractionalizedNFT, i);
        // }

        // for (uint i = 101; i <= 5100; i++) {
        //     fractionalizedNFTContract.fractionalize(i);
        // }

        // deploy StakingFractionNFT contract
        StakingFractionNFT stakingFractionNFTContract = new StakingFractionNFT(fractionToken);
        stakingFractionNFT = address(stakingFractionNFTContract);
        vm.stopBroadcast();
        
    }
}
