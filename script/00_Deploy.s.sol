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
        address minter = vm.envAddress("MINTER");
        address upgrader = vm.envAddress("UPGRADER");
        address pauser = vm.envAddress("PAUSER");
        address unpauser = vm.envAddress("UNPAUSER");

        vm.startBroadcast(deployer);

        address proxyAddress = Upgrades.deployUUPSProxy(
            "AnlogTokenV1.sol", abi.encodeCall(AnlogTokenV1.initialize, (minter, upgrader, pauser, unpauser))
        );

        vm.stopBroadcast();

        console.log("Deployed AnlogTokenV1.sol at ", proxyAddress);
    }
}
