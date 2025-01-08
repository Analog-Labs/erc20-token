// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AnlogTokenV0} from "../src/AnlogTokenV0.sol";
import {AnlogTokenV1Upgrade} from "../src/AnlogTokenV1Upgrade.sol";

/// @notice test for V0->V1 AnlogToken upgrade
contract UpgradeV0V1Test is Test {
    AnlogTokenV0 public tokenV0;
    AnlogTokenV1Upgrade public tokenV1;

    address constant MINTER = address(0);
    address constant UPGRADER = address(1);
    address constant PAUSER = address(2);
    address constant UNPAUSER = address(3);

    uint256 constant mint_amount1 = 100_000;
    uint256 constant mint_amount2 = 50_000;

    /// @notice deploys an UUPS proxy.
    /// Here we start with the V0 implementation
    function setUp() public {
        // deploy proxy with V0 implementation having this contract as the Owner
        address proxy =
            Upgrades.deployUUPSProxy("AnlogTokenV0.sol", abi.encodeCall(AnlogTokenV0.initialize, (address(this))));
        tokenV0 = AnlogTokenV0(proxy);
    }

    modifier preUpgrade(address mint_to, uint256 mint_amount) {
        assertEq(tokenV0.totalSupply(), 0);
        // MINTER SHOULD NOT be able to mint yet
        vm.prank(MINTER);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, MINTER));
        tokenV0.mint(mint_to, mint_amount1);
        // OWNER SHOULD be able to mint
        tokenV0.mint(mint_to, 100_000);
        assertEq(tokenV0.totalSupply(), mint_amount);
        assertEq(tokenV0.balanceOf(mint_to), mint_amount);
        _;
    }

    modifier upgrade() {
        Upgrades.upgradeProxy(
            address(tokenV0),
            "AnlogTokenV1Upgrade.sol",
            abi.encodeCall(AnlogTokenV1Upgrade.initialize, (MINTER, UPGRADER, PAUSER, UNPAUSER))
        );
        tokenV1 = AnlogTokenV1Upgrade(address(tokenV0));
        _;
    }

    function test_preUpgrade() public preUpgrade(address(this), mint_amount1) {}

    function test_Upgrade() public upgrade {}

    function test_postUpgrade() public preUpgrade(address(this), mint_amount1) upgrade {
        // Total Supply SHOULD NOT change
        assertEq(tokenV1.totalSupply(), mint_amount1);
        // Balances SHOULD NOT change
        assertEq(tokenV0.balanceOf(address(this)), mint_amount1);
        // OWNER SHOULD NOT be able to mint anymore
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), keccak256("MINTER_ROLE")
            )
        );
        tokenV1.mint(address(this), mint_amount2);
        // MINTER SHOULD be able to mint
        vm.prank(MINTER);
        tokenV1.mint(address(this), mint_amount2);
        assertEq(tokenV0.totalSupply(), mint_amount1 + mint_amount2);
        assertEq(tokenV0.balanceOf(address(this)), mint_amount1 + mint_amount2);
    }
}
