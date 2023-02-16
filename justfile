set dotenv-load

local:
    #!/usr/bin/env bash
    forge create --rpc-url $LOCALHOST_URL --private-key $LOCALHOST_PRIVATE_KEY -c src/ProudCamel.sol ProudCamel --constructor-args 0xE097d6B3100777DC31B34dC2c58fB524C2e76921

mumbai:
    #!/usr/bin/env bash
    USDC_ADDRESS=0xE097d6B3100777DC31B34dC2c58fB524C2e76921 forge script --rpc-url $POLYGON_MUMBAI_URL --private-key $POLYGON_MUMBAI_PRIVATE_KEY -c script/Deploy.s.sol Deploy --sig "run()" --broadcast -vvvv ./script/Deploy.s.sol

build-test:
    forge build --contracts src/ProudCamel.sol

mainnet:
    #!/usr/bin/env bash
    forge create --rpc-url $POLYGON_MAINNET_URL --private-key $POLYGON_MAINNET_PRIVATE_KEY -c src/ProudCamel.sol ProudCamel --constructor-args 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174

build-mainnet:
    forge build --contracts src/ProudCamel.sol