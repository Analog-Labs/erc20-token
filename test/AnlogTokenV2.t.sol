// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AnlogTokenV2} from "../src/AnlogTokenV2.sol";

import {Gateway, Route, NetworkID, ERC1967} from "analog-gmp/src/Gateway.sol";

/// @notice OZ ERC20 and its presets are covered with Hardhat tests.
/// Hence we keep these few basic tests here more as a boilerplate for
/// the future tests for custom added fetaures.
contract AnlogTokenV2Test is Test {
    AnlogTokenV2 public token;

    address constant MINTER = address(0);
    address constant UPGRADER = address(1);
    address constant PAUSER = address(2);
    address constant UNPAUSER = address(3);
    address constant NEW_MINTER = address(4);

    // Teleport-related
    address constant GATEWAY = 0xEb73D0D236DE8F8D09dc6A52916e5849ff1E8dfA;
    // ERC-1967 storage slot for admin address:
    // 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
    // Can be queried with
    // cast storage 0xEb73D0D236DE8F8D09dc6A52916e5849ff1E8dfA 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103 -r $SEPOLIA_RPC_URL
    address constant GW_ADMIN = 0x38a78edA59AC73A95281Cb009A5EF986e320509F;
    uint16 constant TIMECHAIN_ID = 1000;
    uint256 constant MIN_TELEPORT_VAL = 1000000000000;

    // fork testing
    string SEPOLIA_RPC_URL = vm.envString("SEPOLIA_RPC_URL");
    uint256 sepoliaFork;

    /// @notice deploys an UUPS proxy.
    /// Here we start with the V1 implementation right away.
    /// For V0->V1 upgrade see another test.
    function setUp() public {
        sepoliaFork = vm.createFork(SEPOLIA_RPC_URL);
        vm.selectFork(sepoliaFork);
        assertEq(vm.activeFork(), sepoliaFork);

        Options memory opts;
        opts.constructorData = abi.encode(GATEWAY, TIMECHAIN_ID, MIN_TELEPORT_VAL);

        // deploy proxy with a distinct address assigned to each role
        address proxy = Upgrades.deployUUPSProxy(
            "AnlogTokenV2.sol", abi.encodeCall(AnlogTokenV2.initialize, (MINTER, UPGRADER, PAUSER, UNPAUSER)), opts
        );
        token = AnlogTokenV2(proxy);
    }

    modifier setRoute() {
        Route memory route = Route(NetworkID.wrap(1000), 15_000_000, 0, bytes32(bytes20(address(42))), 1, 1);
        address payable gw = payable(GATEWAY);

        vm.prank(GW_ADMIN);
        Gateway(gw).setRoute(route);

        _;
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

    function test_TeleportOut_Below_ED() public preMint(address(this), MIN_TELEPORT_VAL - 1) {
        bytes32 dest = bytes32(bytes20(UPGRADER));
        vm.expectRevert("value below minimum required");
        token.teleport(dest, MIN_TELEPORT_VAL - 1);
    }

    function test_TeleportOut_Low_Value() public preMint(address(this), MIN_TELEPORT_VAL) setRoute {
        bytes32 dest = bytes32(bytes20(UPGRADER));

        vm.expectEmit(address(token));
        emit IERC20.Transfer(address(this), address(0), MIN_TELEPORT_VAL);
        vm.expectRevert("insufficient tx value");
        token.teleport(dest, MIN_TELEPORT_VAL);
    }
}
