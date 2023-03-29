set dotenv-load

test_fractnft:
    forge test --match-contract FractionalizedNFTTest  --match-path test/FractionalizedNFT.t.sol -vvvvv

local:
    #!/usr/bin/env bash
    USDC_ADDRESS=0xE097d6B3100777DC31B34dC2c58fB524C2e76921
    OWNER_WALLET_ADDRESS=0x26a3E0CBf8240E303EcdF36a2ccaef74A32692db forge script --force --rpc-url $LOCALHOST_URL --private-key $LOCALHOST_PRIVATE_KEY -C script/Deploy.s.sol Deploy --sig "run()" --broadcast -vvvv ./script/Deploy.s.sol

mumbai:
    #!/usr/bin/env bash
    USDC_ADDRESS=0xE097d6B3100777DC31B34dC2c58fB524C2e76921 OWNER_WALLET_ADDRESS=0x26a3E0CBf8240E303EcdF36a2ccaef74A32692db forge script --force --rpc-url $POLYGON_MUMBAI_URL --private-key $POLYGON_MUMBAI_PRIVATE_KEY -C script/Deploy.s.sol Deploy --sig "run()" --broadcast -vvvv ./script/Deploy.s.sol

mainnet:
    #!/usr/bin/env bash
    USDC_ADDRESS=0xE097d6B3100777DC31B34dC2c58fB524C2e76921 OWNER_WALLET_ADDRESS=0x26a3E0CBf8240E303EcdF36a2ccaef74A32692db forge script --force --rpc-url $POLYGON_MUMBAI_URL --private-key $POLYGON_MUMBAI_PRIVATE_KEY -C script/Deploy.s.sol Deploy --sig "run()" --broadcast -vvvv ./script/Deploy.s.sol