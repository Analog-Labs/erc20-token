// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {AnlogTokenV0} from "../src/AnlogTokenV0.sol";

contract AnlogTokenScript is Script {
    AnlogTokenV0 public token;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        //        token = new AnlogToken("Analog One", "ANLOG");

        vm.stopBroadcast();
    }
}
