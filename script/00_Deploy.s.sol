// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {AnlogTokenV1} from "../src/AnlogTokenV1.sol";

contract AnlogTokenScript is Script {
    AnlogTokenV1 public token;

    function setUp() public {}

    function run() public {
        address deployer = vm.envAddress("DEPLOYER");
        vm.startBroadcast(deployer);

        address proxyAddress = Upgrades.deployUUPSProxy(
            "AnlogTokenV1.sol", abi.encodeCall(AnlogTokenV1.initialize, (deployer, deployer, deployer, deployer))
        );

        vm.stopBroadcast();

        console.log("Deployed AnlogTokenV1.sol at ", proxyAddress);
    }
}
