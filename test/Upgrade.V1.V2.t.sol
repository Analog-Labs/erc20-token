// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AnlogTokenV1} from "../src/AnlogTokenV1.sol";
import {AnlogTokenV2} from "../src/AnlogTokenV2.sol";

/// @notice test for V1->V2 AnlogToken upgrade
contract UpgradeV1V2Test is Test {
    AnlogTokenV1 public tokenV1;
    AnlogTokenV2 public tokenV2;

    address constant MINTER = address(0);
    address constant UPGRADER = address(1);
    address constant PAUSER = address(2);
    address constant UNPAUSER = address(3);

    uint256 constant mint_amount1 = 100_000;
    uint256 constant mint_amount2 = 50_000;

    // V2 immutables
    address constant GATEWAY = 0xEb73D0D236DE8F8D09dc6A52916e5849ff1E8dfA;
    uint16 constant TIMECHAIN_ID = 1000;
    uint256 constant MIN_TELEPORT_VAL = 1000000000000;

    // fork testing
    string SEPOLIA_RPC_URL = vm.envString("SEPOLIA_RPC_URL");
    uint256 sepoliaFork;

    /// @notice deploys an UUPS proxy.
    /// Here we start with the V1 implementation
    function setUp() public {
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
        // We don't need initializer to be called for this upgrade,
        // as all the initial V1 token config stays the same.
        // Thus `data` is empty.
        //        bytes memory emptyData;

        Options memory opts;
        // Constructor we need only for setting immutables
        opts.constructorData = abi.encode(GATEWAY, TIMECHAIN_ID, MIN_TELEPORT_VAL);

        vm.startPrank(UPGRADER);
        Upgrades.upgradeProxy(
            address(tokenV1),
            "AnlogTokenV2.sol",
            abi.encodeCall(AnlogTokenV2.initialize, (MINTER, UPGRADER, PAUSER, UNPAUSER)),
            opts
        );
        vm.stopPrank;

        tokenV2 = AnlogTokenV2(address(tokenV1));
        _;
    }

    function test_preUpgrade() public preUpgrade(address(this), mint_amount1) {}

    function test_Upgrade() public upgrade {}

    // function test_postUpgrade() public preUpgrade(address(this), mint_amount1) upgrade {
    //     // Total Supply SHOULD NOT change
    //     assertEq(tokenV1.totalSupply(), mint_amount1);
    //     // Balances SHOULD NOT change
    //     assertEq(tokenV0.balanceOf(address(this)), mint_amount1);
    //     // OWNER SHOULD NOT be able to mint anymore
    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), keccak256("MINTER_ROLE")
    //         )
    //     );
    //     tokenV1.mint(address(this), mint_amount2);
    //     // MINTER SHOULD be able to mint
    //     vm.prank(MINTER);
    //     tokenV1.mint(address(this), mint_amount2);
    //     assertEq(tokenV0.totalSupply(), mint_amount1 + mint_amount2);
    //     assertEq(tokenV0.balanceOf(address(this)), mint_amount1 + mint_amount2);
    // }
}
