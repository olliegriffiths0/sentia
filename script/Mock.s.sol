// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import "../src/MockToken.sol";
import "forge-std/console.sol";

contract MockTokenScript is Script {
    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("DEV_PRIVATE_KEY");

        address account = vm.addr(privateKey);

        console.log("Account", account);
        console.log("Balance: ", address(account).balance);

        vm.startBroadcast(privateKey);

        MockToken theContract = new MockToken();

        vm.stopBroadcast();
    }
}
