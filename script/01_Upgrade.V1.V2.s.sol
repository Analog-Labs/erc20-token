// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {AnlogTokenV1} from "../src/AnlogTokenV1.sol";
import {AnlogTokenV2} from "../src/AnlogTokenV2.sol";

contract AnlogTokenV1V2UpgradeScript is Script {
    AnlogTokenV1 public token;

    function setUp() public {}

    function run() public {
        address proxy = vm.envAddress("PROXY");
        address upgrader = vm.envAddress("UPGRADER");
        address minter = vm.envAddress("MINTER");
        address pauser = vm.envAddress("PAUSER");
        address unpauser = vm.envAddress("UNPAUSER");
        uint256 cap = vm.envUint("CAP");

        // Teleport-related
        address gateway = vm.envAddress("GATEWAY");

        Options memory opts;
        // Constructor we need only for setting immutables
        opts.constructorData = abi.encode(gateway);

        vm.startBroadcast(upgrader);
        Upgrades.upgradeProxy(
            proxy,
            "AnlogTokenV2.sol",
            abi.encodeCall(AnlogTokenV2.initialize, (minter, upgrader, pauser, unpauser, cap)),
            opts
        );
        vm.stopBroadcast();

        console.log("[dry-run] Upgraded to AnlogTokenV2.sol implentation to proxy address: ", proxy);
        console.log(" V2 SETTINGS:");
        console.log("   GATEWAY: ", gateway);
        console.log("   CAP: ", cap);
        console.log(" ROLES: ");
        console.log("   UPGRADER: ", upgrader);
        console.log("   MINTER:   ", minter);
        console.log("   PAUSER:   ", pauser);
        console.log("   UNPAUSER: ", unpauser);
    }
}
