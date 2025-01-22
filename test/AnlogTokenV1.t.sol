// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {AnlogTokenV1} from "../src/AnlogTokenV1.sol";

contract AnlogTokenV1Test is Test {
    AnlogTokenV1 public token;

    // Hardcode test addresses for roles
    address constant MINTER = address(0);
    address constant UPGRADER = address(1);
    address constant PAUSER = address(2);
    address constant UNPAUSER = address(3);

    // We'll also use these additional addresses in the new tests
    address constant NEW_ADDRESS = address(4);
    address constant UNAUTHORIZED = address(5);

    function setUp() public {
        // Deploy proxy with a distinct address assigned to each role
        address proxy = Upgrades.deployUUPSProxy(
            "AnlogTokenV1.sol",
            abi.encodeCall(AnlogTokenV1.initialize, (MINTER, UPGRADER, PAUSER, UNPAUSER))
        );
        token = AnlogTokenV1(proxy);
    }

    // -----------------------------------------
    // Existing tests
    // -----------------------------------------

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

    function test_RevertWhen_Unauthorized_Mint() public {
        vm.prank(UPGRADER);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                UPGRADER,
                keccak256("MINTER_ROLE")
            )
        );
        token.mint(UPGRADER, 100_000);
    }

    function test_RevertWhen_Unauthorized_Pause() public {
        vm.prank(MINTER);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                MINTER,
                keccak256("PAUSER_ROLE")
            )
        );
        token.pause();
    }

    function test_RevertWhen_Unauthorized_UnPause() public paused {
        vm.prank(MINTER);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                MINTER,
                keccak256("UNPAUSER_ROLE")
            )
        );
        token.unpause();
    }

    // -----------------------------------------
    // NEW TESTS for updateRole
    // -----------------------------------------

    /// @dev Test that only the UPGRADER can call updateRole.
    function test_RevertWhen_Unauthorized_UpdateRole() public {
        // Attempt from an address that does NOT have UPGRADER_ROLE
        vm.prank(UNAUTHORIZED);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                UNAUTHORIZED,
                keccak256("UPGRADER_ROLE")
            )
        );
        token.updateRole(keccak256("PAUSER_ROLE"), NEW_ADDRESS, true);
    }

    /// @dev Test granting a role (e.g. PAUSER_ROLE) to a new address by the UPGRADER.
    function test_GrantRole() public {
        // Confirm NEW_ADDRESS doesn't currently have PAUSER_ROLE
        assertFalse(token.hasRole(keccak256("PAUSER_ROLE"), NEW_ADDRESS));

        // Now do the update from the UPGRADER
        vm.prank(UPGRADER);
        token.updateRole(keccak256("PAUSER_ROLE"), NEW_ADDRESS, true);

        // Now NEW_ADDRESS should have the PAUSER_ROLE
        assertTrue(token.hasRole(keccak256("PAUSER_ROLE"), NEW_ADDRESS));

        // Prove that NEW_ADDRESS can now pause the contract
        vm.prank(NEW_ADDRESS);
        token.pause();
        assertTrue(token.paused());
    }

    /// @dev Test revoking a role from a previously granted address.
    function test_RevokeRole() public {
        // First, grant PAUSER_ROLE to NEW_ADDRESS so we can then revoke
        vm.prank(UPGRADER);
        token.updateRole(keccak256("PAUSER_ROLE"), NEW_ADDRESS, true);

        assertTrue(token.hasRole(keccak256("PAUSER_ROLE"), NEW_ADDRESS));

        // Revoke that role
        vm.prank(UPGRADER);
        token.updateRole(keccak256("PAUSER_ROLE"), NEW_ADDRESS, false);

        assertFalse(token.hasRole(keccak256("PAUSER_ROLE"), NEW_ADDRESS));

        // Attempt to pause by NEW_ADDRESS should revert now
        vm.prank(NEW_ADDRESS);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                NEW_ADDRESS,
                keccak256("PAUSER_ROLE")
            )
        );
        token.pause();
    }
}