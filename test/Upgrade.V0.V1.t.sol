// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {AnlogTokenV0} from "../src/AnlogTokenV0.sol";
import {AnlogTokenV1} from "../src/AnlogTokenV1.sol";

/// @notice test for V0->V1 AnlogToken upgrade
contract UpgradeV0V1Test is Test {
    AnlogTokenV0 public tokenV0;
    AnlogTokenV1 public tokenV1;

    address constant MINTER = address(0);
    address constant UPGRADER = address(1);
    address constant PAUSER = address(2);
    address constant UNPAUSER = address(3);

    /// @notice deploys an UUPS proxy.
    /// Here we start with the V0 implementation
    function setUp() public {
        // deploy proxy with V0 implementation having this contract as the Owner
        address proxy =
            Upgrades.deployUUPSProxy("AnlogTokenV0.sol", abi.encodeCall(AnlogTokenV0.initialize, (address(this))));
        tokenV0 = AnlogTokenV0(proxy);
    }

    // TODO
    modifier preMint(address to, uint256 amount) {
        assertEq(tokenV0.totalSupply(), 0);
        vm.prank(MINTER);
        tokenV0.mint(to, amount);
        assertEq(tokenV0.totalSupply(), amount);
        _;
    }

    // TODO
    modifier paused() {
        vm.prank(PAUSER);
        tokenV0.pause();
        _;
    }

    function test_Upgrade() public {
        Upgrades.upgradeProxy(
            address(tokenV0),
            "AnlogTokenV1.sol",
            abi.encodeCall(AnlogTokenV1.initialize, (MINTER, UPGRADER, PAUSER, UNPAUSER))
        );
    }
}
