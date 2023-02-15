pragma solidity ^0.8.15;

import "Script.sol";
import "../src/1.0/FractionalizedNFT.sol";
import "../src/1.0/SoonanTsoorNFT.sol";
import "../src/1.0/StakingFractionNFT.sol";

contract Deploy is Script {
    address public fractionalizedNFT;
    address public soonanTsoorNFT;
    address public stakingFractionNFT;

    constructor() Script() {}

    function setup() external {
        // deploy SoonanTsoorNFT contract
        SoonanTsoorNFT soonanTsoorNFTContract = new SoonanTsoorNFT();
        soonanTsoorNFT = address(soonanTsoorNFTContract);

        // deploy FractionalizedNFT contract
        FractionalizedNFT fractionalizedNFTContract = new FractionalizedNFT(soonanTsoorNFT);
        fractionalizedNFT = address(fractionalizedNFTContract);

        // deploy StakingFractionNFT contract
        StakingFractionNFT stakingFractionNFTContract = new StakingFractionNFT(fractionalizedNFT);
        stakingFractionNFT = address(stakingFractionNFTContract);
    }
}
