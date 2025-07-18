// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {AnlogTokenV1} from "../src/AnlogTokenV1.sol";

/// @notice OZ ERC20 and its presets are covered with Hardhat tests.
/// Hence we keep these few basic tests here more as a boilerplate for
/// the future tests for custom added fetaures.
contract AnlogTokenV1Test is Test {
    AnlogTokenV1 public token;

    address constant MINTER = address(0);
    address constant UPGRADER = address(1);
    address constant PAUSER = address(2);
    address constant UNPAUSER = address(3);
    address constant NEW_MINTER = address(4);

    /// @notice deploys an UUPS proxy.
    /// Here we start with the V1 implementation right away.
    /// For V0->V1 upgrade see another test.
    function setUp() public {
        // deploy proxy with a distinct address assigned to each role
        address proxy = Upgrades.deployUUPSProxy(
            "AnlogTokenV1.sol", abi.encodeCall(AnlogTokenV1.initialize, (MINTER, UPGRADER, PAUSER, UNPAUSER))
        );
        token = AnlogTokenV1(proxy);
    }

    modifier preMint(address to, uint256 amount) {
        assertEq(token.totalSupply(), 0);
        vm.prank(MINTER);
        token.mint(to, amount);
        assertEq(token.totalSupply(), amount);
        assertEq(token.balanceOf(to), amount);
        _;
    }

    modifier paused() {
        vm.prank(PAUSER);
        token.pause();
        _;
    }

    function test_name_and_ticker() public view {
        assertEq(token.name(), "Wrapped Analog One Token");
        assertEq(token.symbol(), "WANLOG");
    }

    function test_decimals() public view {
        assertEq(token.decimals(), 12);
    }

    function test_Mint() public preMint(address(this), 20_000) {
        assertEq(token.balanceOf(address(this)), 20_000);
    }

    function test_Transfer() public preMint(address(this), 20_000) {
        assertEq(token.balanceOf(address(2)), 0);
        token.transfer(address(2), 5_000);
        assertEq(token.balanceOf(address(2)), 5_000);
    }

    function test_Pause() public preMint(address(this), 20_000) paused {
        // error EnforcedPause()
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        token.transfer(address(2), 5_000);

        vm.prank(MINTER);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        token.mint(address(this), 1);
    }

    function test_UnPause() public preMint(address(this), 20_000) paused {
        vm.prank(UNPAUSER);
        token.unpause();

        token.transfer(address(2), 5_000);
        assertEq(token.balanceOf(address(2)), 5_000);
    }

    function test_GrantRole() public preMint(address(this), 20_000) {
        assertFalse(token.hasRole(keccak256("MINTER_ROLE"), NEW_MINTER));

        vm.prank(UPGRADER);
        token.grantRole(keccak256("MINTER_ROLE"), NEW_MINTER);

        vm.prank(NEW_MINTER);
        token.mint(NEW_MINTER, 5_000);
        assertEq(token.balanceOf(NEW_MINTER), 5_000);
        assertEq(token.totalSupply(), 25_000);
    }

    function test_RevokeRole() public preMint(address(this), 20_000) {
        vm.prank(UPGRADER);
        token.revokeRole(keccak256("MINTER_ROLE"), MINTER);

        vm.prank(MINTER);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, MINTER, keccak256("MINTER_ROLE")
            )
        );
        token.mint(MINTER, 5_000);
    }

    function test_RevertWhen_Unauthorized_RevokeRole() public {
        vm.prank(PAUSER);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, PAUSER, 0x00));
        token.revokeRole(keccak256("MINTER_ROLE"), MINTER);

        assert(token.hasRole(keccak256("MINTER_ROLE"), MINTER));
    }

    function test_RevertWhen_Unauthorized_Mint() public {
        vm.prank(UPGRADER);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, UPGRADER, keccak256("MINTER_ROLE")
            )
        );
        token.mint(UPGRADER, 100_000);
    }

    function test_RevertWhen_Unauthorized_Pause() public {
        vm.prank(MINTER);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, MINTER, keccak256("PAUSER_ROLE")
            )
        );
        token.pause();
    }

    function test_RevertWhen_Unauthorized_UnPause() public paused {
        vm.prank(MINTER);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, MINTER, keccak256("UNPAUSER_ROLE")
            )
        );
        token.unpause();
    }
}
