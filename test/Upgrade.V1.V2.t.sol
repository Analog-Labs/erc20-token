// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AnlogTokenV1} from "../src/AnlogTokenV1.sol";
import {AnlogTokenV2} from "../src/AnlogTokenV2.sol";
import {AnlogTokenV2Test} from "./AnlogTokenV2.t.sol";

/// @notice test for V1->V2 AnlogToken upgrade
contract UpgradeV1V2Test is Test, AnlogTokenV2Test {
    AnlogTokenV1 public tokenV1;

    uint256 constant MINT_AMOUNT1 = 100_000;
    uint256 constant MINT_AMOUNT2 = 50_000;

    /// @notice deploys an UUPS proxy.
    /// Here we start with the V1 implementation
    function setUp() public override {
        // NOTE: we need this in order to have deployed gateway.
        sepoliaFork = vm.createFork(SEPOLIA_RPC_URL);
        vm.selectFork(sepoliaFork);
        assertEq(vm.activeFork(), sepoliaFork);

        // deploy proxy with V1 implementation having this contract as the Owner
        address proxy = Upgrades.deployUUPSProxy(
            "AnlogTokenV1.sol", abi.encodeCall(AnlogTokenV1.initialize, (MINTER, UPGRADER, PAUSER, UNPAUSER))
        );
        tokenV1 = AnlogTokenV1(proxy);
    }

    modifier preUpgrade(address mint_to, uint256 mint_amount) {
        assertEq(tokenV1.totalSupply(), 0);
        // MINTER SHOULD be able to mint
        vm.prank(MINTER);
        tokenV1.mint(mint_to, mint_amount);
        assertEq(tokenV1.totalSupply(), mint_amount);
        assertEq(tokenV1.balanceOf(mint_to), mint_amount);
        _;
    }

    modifier upgrade() {
        Options memory opts;
        // Constructor we need only for setting immutables
        opts.constructorData = abi.encode(GATEWAY);

        vm.startPrank(UPGRADER);
        Upgrades.upgradeProxy(
            address(tokenV1),
            "AnlogTokenV2.sol",
            abi.encodeCall(AnlogTokenV2.initialize, (MINTER, UPGRADER, PAUSER, UNPAUSER, CAP)),
            opts
        );
        tokenV2 = AnlogTokenV2(address(tokenV1));
        vm.stopPrank();
        _;
    }

    function test_preUpgrade() public preUpgrade(address(this), MINT_AMOUNT1) {}

    function test_Upgrade() public upgrade {}

    function test_postUpgrade() public preUpgrade(address(this), MINT_AMOUNT1) upgrade {
        // Total Supply SHOULD NOT change
        assertEq(tokenV2.totalSupply(), MINT_AMOUNT1);
        // Balances SHOULD NOT change
        assertEq(tokenV2.balanceOf(address(this)), MINT_AMOUNT1);
        assertEq(tokenV2.balanceOf(PAUSER), 0);
        // TOKENS are transferrable
        tokenV2.transfer(PAUSER, MINT_AMOUNT2);
        assertEq(tokenV2.balanceOf(PAUSER), MINT_AMOUNT2);
        assertEq(tokenV2.balanceOf(address(this)), MINT_AMOUNT1 - MINT_AMOUNT2);
    }

    /* ENSURE ALL AnlogTokenV2 functional WORKS fine AFTER UPGRADE */
    /* BASIC */
    function test_name_and_ticker() public override upgrade {}
    function test_decimals() public override upgrade {}
    function test_Mint() public override upgrade preMint(address(this), 20_000) {}
    function test_Transfer() public override upgrade preMint(address(this), 20_000) {}
    function test_Pause() public override upgrade preMint(address(this), 20_000) paused {}
    function test_UnPause() public override upgrade preMint(address(this), 20_000) paused {}
    function test_GrantRole() public override upgrade preMint(address(this), 20_000) {}
    function test_RevokeRole() public override upgrade preMint(address(this), 20_000) {}
    function test_RevertWhen_Unauthorized_RevokeRole() public override upgrade {}
    function test_RevertWhen_Unauthorized_Mint() public override upgrade {}
    function test_RevertWhen_Unauthorized_Pause() public override upgrade {}
    function test_RevertWhen_Unauthorized_UnPause() public override upgrade paused {}

    /* OATS */
    function test_Cost() public override upgrade {}
    function test_Recieve() public override upgrade preMint(MINTER, CAP / 2) {}
    function test_Send() public override upgrade preMint(MINTER, CAP / 2) {}
}
