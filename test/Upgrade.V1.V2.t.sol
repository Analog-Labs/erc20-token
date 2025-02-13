// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
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

    /// @notice deploys an UUPS proxy.
    /// Here we start with the V1 implementation
    function setUp() public {
        // deploy proxy with V0 implementation having this contract as the Owner
        address proxy = Upgrades.deployUUPSProxy(
            "AnlogTokenV1.sol", abi.encodeCall(AnlogTokenV1.initialize, (MINTER, UPGRADER, PAUSER, UNPAUSER))
        );
        tokenV1 = AnlogTokenV1(proxy);
    }

    // modifier preUpgrade(address mint_to, uint256 mint_amount) {
    //     assertEq(tokenV0.totalSupply(), 0);
    //     // MINTER SHOULD NOT be able to mint yet
    //     vm.prank(MINTER);
    //     vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, MINTER));
    //     tokenV0.mint(mint_to, mint_amount1);
    //     // OWNER SHOULD be able to mint
    //     tokenV0.mint(mint_to, 100_000);
    //     assertEq(tokenV0.totalSupply(), mint_amount);
    //     assertEq(tokenV0.balanceOf(mint_to), mint_amount);
    //     _;
    // }

    modifier upgrade() {
        // We don't need initializer to be called for this upgrade,
        // thus data is empty;
        bytes memory emptyData;
        Upgrades.upgradeProxy(address(tokenV1), "AnlogTokenV2.sol", emptyData);
        tokenV2 = AnlogTokenV2(address(tokenV1));
        _;
    }

    //    function test_preUpgrade() public preUpgrade(address(this), mint_amount1) {}

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
