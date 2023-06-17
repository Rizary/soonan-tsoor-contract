// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import {SoonanTsoorStudio} from "../src/1.0/flatten/SoonanTsoorStudio.flatten.sol";
import "../src/1.0/flatten/StakingManager.flatten.sol";

contract Deploy is Script {
    address public fractionManager;
    address public fractionToken;
    address payable public soonanTsoorStudio;
    address payable public soonanTsoorVilla;
    address public stakingToken;
    address public stakingManager;
    address public USDCAddress;
    address private FeedAddress;

    event log_named_uint(string key, uint256 val);

    constructor() Script() {}

    function run() external {
        USDCAddress = vm.envAddress("USDC_ADDRESS");
        FeedAddress = vm.envAddress("PRICE_FEED_ADDRESS");
        vm.startBroadcast();

        FractionToken fractionTokenContract = new FractionToken();
        console.log("\"FractionToken\": \"", address(fractionTokenContract), "\"");
        fractionToken = address(fractionTokenContract);

        // deploy FractionManager contract
        FractionManager fractionManagerContract = new FractionManager(fractionToken, USDCAddress, FeedAddress);
        console.log("\"FractionManager\": \"", address(fractionManagerContract), "\"");
        fractionManager = address(fractionManagerContract);

        console.log("Setup FractionManager...");
        fractionTokenContract.setMaxSupply(fractionManagerContract.totalFractions() * 10 ** 18);
        fractionTokenContract.unpause();
        fractionTokenContract.mint(fractionManager, fractionManagerContract.totalFractions() * 10 ** 18);
        fractionTokenContract.pause();
        console.log("Setup finished");

        // deploy SoonanTsoorStudio contract and mint all to owner wallet
        SoonanTsoorStudio soonanStudioContract = new SoonanTsoorStudio(USDCAddress, FeedAddress, fractionManager);
        console.log("\"Studio\": \"", address(soonanStudioContract), "\",");

        soonanTsoorStudio = payable(address(soonanStudioContract));

        SoonanTsoorVilla soonanVillaContract = new SoonanTsoorVilla(USDCAddress, FeedAddress);
        console.log("\"Villa\": \"", address(soonanVillaContract), "\",");
        soonanTsoorVilla = payable(address(soonanVillaContract));

        // deploy StakingToken contract
        StakingToken stakingTokenContract = new StakingToken();
        console.log("\"StakingToken\": \"", address(stakingTokenContract), "\",");
        stakingToken = address(stakingTokenContract);

        // deploy StakingManager contract
        StakingManager stakingManagerContract = new StakingManager(soonanTsoorVilla, fractionManager, stakingToken);
        console.log("\"StakingManager\": \"", address(stakingManagerContract), "\",");
        stakingManager = address(stakingManagerContract);
        vm.stopBroadcast();
    }
}
