// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "../src/1.0/FractionManager.sol";
import "../src/1.0/FractionToken.sol";
import "../src/1.0/SoonanTsoorStudio.sol";
import "../src/1.0/SoonanTsoorVilla.sol";
import "../src/1.0/StakingToken.sol";
import "../src/1.0/StakingManager.sol";

contract Deploy is Script {
    address public fractionManager;
    address public fractionToken;
    address payable public soonanTsoorStudio;
    address payable public soonanTsoorVilla;
    address public stakingToken;
    address public stakingManager;
    address public USDCAddress;
    address private FeedAddress;

    event log_named_uint (string key, uint val);

    constructor() Script() {
    }

    function run() external {
        USDCAddress = vm.envAddress("USDC_ADDRESS");
        FeedAddress = vm.envAddress("PRICE_FEED_ADDRESS");
        vm.startBroadcast();
        
        SoonanTsoorVilla soonanVillaContract = new SoonanTsoorVilla(USDCAddress, FeedAddress);
        console.log("Villa deployed -->", address(soonanVillaContract));
        soonanTsoorVilla = payable(address(soonanVillaContract));
        
        // deploy FractionManager contract
        FractionManager fractionManagerContract = new FractionManager(fractionToken, soonanTsoorStudio, USDCAddress);
        console.log("FractionManager deployed -->", address(fractionManagerContract));
        fractionManager = address(fractionManagerContract);
        
        // deploy SoonanTsoorStudio contract and mint all to owner wallet
        SoonanTsoorStudio soonanStudioContract = new SoonanTsoorStudio(USDCAddress, FeedAddress, fractionManager);
        console.log("Studio deployed -->", address(soonanStudioContract));
        soonanTsoorStudio = payable(address(soonanStudioContract));

        FractionToken fractionTokenContract = new FractionToken();
        console.log("FractionToken deployed -->", address(fractionTokenContract));
        fractionToken = address(fractionTokenContract);

        // deploy StakingToken contract
        StakingToken stakingTokenContract = new StakingToken();
        console.log("StakingToken deployed -->", address(stakingTokenContract));
        stakingToken = address(stakingTokenContract);
        
        // deploy StakingManager contract
        StakingManager stakingManagerContract = new StakingManager(soonanTsoorVilla, soonanTsoorStudio, stakingToken, 54_666_666_666_666_666_667, 13_666_666_666_666_667, 31_536_000);
        console.log("StakingManager deployed -->", address(stakingManagerContract));
        stakingManager = address(stakingManagerContract);
        vm.stopBroadcast();
        
    }
}
