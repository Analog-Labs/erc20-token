// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {AnlogTokenV1} from "../src/AnlogTokenV1.sol";

contract AnlogTokenV1V2UpgradeScript is Script {
    AnlogTokenV1 public token;

    function setUp() public {}

    function run() public {
        address proxy = vm.envAddress("PROXY");
        address upgrader = vm.envAddress("UPGRADER");

        // Teleport-related
        address gateway = vm.envAddress("GATEWAY");
        uint16 timechainId = uint16(vm.envUint("TIMECHAIN_ROUTE_ID"));
        uint256 minimalTeleport = vm.envUint("MINIMAL_TELEPORT_VALUE");

        // We don't need initializer to be called for this upgrade,
        // as all the initial V1 token config stays the same.
        // Thus `data` is empty.
        bytes memory emptyData;

        Options memory opts;
        opts.constructorData = abi.encode(gateway, timechainId, minimalTeleport);

        vm.startBroadcast(upgrader);
        Upgrades.upgradeProxy(proxy, "AnlogTokenV2.sol", emptyData, opts);
        vm.stopBroadcast();

        console.log("[dry-run] Upgraded to AnlogTokenV2.sol implentation to proxy address: ", proxy);
        console.log(" TELEPORT SETTINGS:");
        console.log("   GATEWAY: ", gateway);
        console.log("   TIMECHAIN_ROUTE_ID: ", timechainId);
        console.log("   MINIMAL_TELEPORT_VALUE: ", minimalTeleport);
    }
}
