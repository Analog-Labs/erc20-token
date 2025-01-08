// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AnlogTokenV0} from "../src/AnlogTokenV0.sol";

/// @notice OZ ERC20 and its presets are covered with Hardhat tests.
/// Hence we keep these few basic tests here more as a boilerplate for
/// the future tests for custom added fetaures.
contract AnlogTokenV0Test is Test {
    AnlogTokenV0 public token;

    /// @notice deploys an UUPS proxy
    function setUp() public {
        // deploy proxy with V0 implementation having this contract as the Owner
        address proxy =
            Upgrades.deployUUPSProxy("AnlogTokenV0.sol", abi.encodeCall(AnlogTokenV0.initialize, (address(this))));
        token = AnlogTokenV0(proxy);
    }

    modifier preMint(address to, uint256 amount) {
        assertEq(token.totalSupply(), 0);
        token.mint(to, amount);
        assertEq(token.totalSupply(), amount);
        assertEq(token.balanceOf(to), amount);
        _;
    }

    function test_Mint() public preMint(address(1), 20_000) {
        assertEq(token.balanceOf(address(1)), 20_000);
    }

    function test_Transfer() public preMint(address(this), 20_000) {
        assertEq(token.balanceOf(address(2)), 0);
        token.transfer(address(2), 5_000);
        assertEq(token.balanceOf(address(2)), 5_000);
    }

    function test_Pause() public preMint(address(this), 20_000) {
        token.pause();

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        token.transfer(address(2), 5_000);

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        token.mint(address(this), 1);
    }
}
