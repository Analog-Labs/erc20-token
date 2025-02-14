// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {AnlogTokenV1} from "../src/AnlogTokenV1.sol";

contract AnlogTokenV1DeploymentScript is Script {
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

        console.log("[dry-run] Deployed AnlogTokenV1.sol implentation to proxy address: ", proxyAddress);
        console.log(" ROLES:");
        console.log("   MINTER: ", minter);
        console.log("   UPGRADER: ", upgrader);
        console.log("   PAUSER: ", pauser);
        console.log("   UNPAUSER: ", unpauser);
    }
}
