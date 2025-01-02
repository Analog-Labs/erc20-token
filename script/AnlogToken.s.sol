// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {AnlogToken} from "../src/AnlogToken.sol";

contract AnlogTokenScript is Script {
    AnlogToken public token;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        token = new AnlogToken("Analog One", "ANLOG");

        vm.stopBroadcast();
    }
}
