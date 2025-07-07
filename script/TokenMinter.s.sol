// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {AnlogTokenV1} from "../src/AnlogTokenV1.sol";

contract TokenMintScript is Script {
    function run() public {
        address minter = vm.envAddress("MINTER");
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        address recipient = vm.envAddress("RECIPIENT");
        uint256 amount = vm.envUint("MINT_AMOUNT");

        AnlogTokenV1 token = AnlogTokenV1(proxyAddress);

        vm.startBroadcast(minter);
        token.mint(recipient, amount);
        vm.stopBroadcast();

        console.log("Minted %s tokens to %s", amount, recipient);
        console.log("New balance: %s", token.balanceOf(recipient));
        console.log("Total supply: %s", token.totalSupply());
    }
}
