set dotenv-load

tnft:
    #!/usr/bin/env bash
    FOUNDRY_PROFILE=dev forge test -f $POLYGON_MUMBAI_URL --match-contract SoonanTsoorTest  --match-path test/SoonanTsoor.t.sol

tsingle name:
    #!/usr/bin/env bash
    FOUNDRY_PROFILE=dev forge test -f $POLYGON_MUMBAI_URL --match-contract SoonanTsoorTest  --match-path test/SoonanTsoor.t.sol --match-test {{name}} -vvvvv

flatten:
    #!/usr/bin/env bash
    files = [
        "FractionManager.sol",
        "FractionToken.sol",
        "StakingToken.sol",
        "StakingManager.sol",
        "SoonanTsoorStudio.sol",
        "SoonanTsoorVilla.sol",
    ]
    @for file in ${files} ; do \
        base_filename=$${file%.*} ; \
        echo "Flattening $${file}..." ; \
        forge flatten -C src -o src/1.0/$${base_filename}.flatten.sol src/1.0/$${file} ; \
    done

mumbai: flatten
    #!/usr/bin/env bash
    FOUNDRY_PROFILE=dev
    USDC_ADDRESS=0xE097d6B3100777DC31B34dC2c58fB524C2e76921 
    PRICE_FEED_ADDRESS=0x572dDec9087154dC5dfBB1546Bb62713147e0Ab0 forge script script/Deploy.s.sol:Deploy --broadcast --verify --rpc-url $POLYGON_MUMBAI_URL --private-key $POLYGON_MUMBAI_PRIVATE_KEY --etherscan-api-key $ETHERSCAN_DEV_KEY

mumbaiwl:
    #!/usr/bin/env bash
    FOUNDRY_PROFILE=dev
    USDC_ADDRESS=0xE097d6B3100777DC31B34dC2c58fB524C2e76921  PRICE_FEED_ADDRESS=0x572dDec9087154dC5dfBB1546Bb62713147e0Ab0 forge script script/Deploy.s.sol:Deploy --broadcast --rpc-url $POLYGON_MUMBAI_URL --private-key $POLYGON_MUMBAI_PRIVATE_KEY --etherscan-api-key $ETHERSCAN_DEV_KEY --sig "whitelist()"

mainnet:
    #!/usr/bin/env bash
    FOUNDRY_PROFILE=dev
    USDC_ADDRESS=0xE097d6B3100777DC31B34dC2c58fB524C2e76921
    PRICE_FEED_ADDRESS=0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7 forge script script/Deploy.s.sol:Deploy --broadcast --verify --rpc-url $POLYGON_MAINNET_URL --private-key $POLYGON_MAINNET_PRIVATE_KEY --etherscan-api-key $ETHERSCAN_MAINNET_KEY