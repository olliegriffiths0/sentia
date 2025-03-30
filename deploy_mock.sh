#!/bin/bash

source .env
echo "deploying on $BASE_SEPOLIA_RPC"


forge script ./script/Mock.s.sol --rpc-url $BASE_SEPOLIA_RPC --broadcast --verify -vvvv --retries 4 --delay 10