// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import "../src/SENTIA.sol";
import "forge-std/console.sol";

contract SENTIAScript is Script {
    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("DEV_PRIVATE_KEY");

        address account = vm.addr(privateKey);

        console.log("Account", account);
        console.log("Balance: ", address(account).balance);

        vm.startBroadcast(privateKey);

        //SENTIA theContract = new SENTIA(0x526167531ee6a1d57cf37283c4DF546c6E7c629d, 0x6dFdF0905Bd072f5dB70BcE147eF1947F6FA2A16);

        //a
        SENTIA theContract =
            new SENTIA(0xc029fd4de94C139734C946456BD2F314fA739911, 0xc029fd4de94C139734C946456BD2F314fA739911);

        vm.stopBroadcast();
    }
}
