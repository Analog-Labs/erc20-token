// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20CappedUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {Utils, ICallee} from "@oats/IOATS.sol";
import {IGmpReceiver} from "gmp-2.0.0/src/IGmpReceiver.sol";
import {IGateway} from "gmp-2.0.0/src/IGateway.sol";

import {AnlogTokenV2} from "../src/AnlogTokenV2.sol";

/// @notice OZ ERC20 and its presets are covered with Hardhat tests.
/// Hence we keep these few basic tests here more as a boilerplate for
/// the future tests for custom added features.
contract AnlogTokenV2Test is Test {
    AnlogTokenV2 public tokenV2;
    Callee public callee;

    address constant MINTER = address(1);
    address constant UPGRADER = address(2);
    address constant PAUSER = address(3);
    address constant UNPAUSER = address(4);
    address constant NEW_MINTER = address(5);

    // Teleport-related
    address constant GATEWAY = 0xEb73D0D236DE8F8D09dc6A52916e5849ff1E8dfA;
    // ERC-1967 storage slot for admin address:
    // 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
    // Can be queried with
    // cast storage 0xEb73D0D236DE8F8D09dc6A52916e5849ff1E8dfA 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103 -r $SEPOLIA_RPC_URL
    address constant GW_ADMIN = 0x38a78edA59AC73A95281Cb009A5EF986e320509F;

    // Address of this token on this and the other network
    address constant TOKEN = address(6);
    address constant TOKEN_OTHER = address(7);

    uint256 constant CAP = 1_000_000;
    uint256 constant AMOUNT = 100500;

    // Mocked
    uint256 constant COST = 42;
    uint16 constant NETWORK = 2;
    bytes32 constant MSG_ID = bytes32(uint256(0xff));

    // fork testing
    string SEPOLIA_RPC_URL = vm.envString("SEPOLIA_RPC_URL");
    uint256 sepoliaFork;

    /// @notice deploys an UUPS proxy.
    /// Here we start with the V2 implementation right away.
    /// For V1->V2 upgrade see another test.
    function setUp() public virtual {
        sepoliaFork = vm.createFork(SEPOLIA_RPC_URL);
        vm.selectFork(sepoliaFork);
        assertEq(vm.activeFork(), sepoliaFork);

        Options memory opts;
        opts.constructorData = abi.encode(GATEWAY);

        // deploy proxy with a distinct address assigned to each role
        address proxy = Upgrades.deployUUPSProxy(
            "AnlogTokenV2.sol", abi.encodeCall(AnlogTokenV2.initialize, (MINTER, UPGRADER, PAUSER, UNPAUSER, CAP)), opts
        );

        tokenV2 = AnlogTokenV2(proxy);
        callee = new Callee(address(tokenV2));

        // Mock message cost
        vm.mockCall(GATEWAY, abi.encodeWithSelector(IGateway.estimateMessageCost.selector), abi.encode(COST));
        // Mock submit message
        vm.mockCall(GATEWAY, abi.encodeWithSelector(IGateway.submitMessage.selector), abi.encode(MSG_ID));
    }

    modifier preMint(address to, uint256 amount) {
        assertEq(tokenV2.totalSupply(), 0);
        vm.prank(MINTER);
        tokenV2.mint(to, amount);
        assertEq(tokenV2.totalSupply(), amount);
        assertEq(tokenV2.balanceOf(to), amount);
        _;
    }

    modifier paused() {
        vm.prank(PAUSER);
        tokenV2.pause();
        _;
    }

    /* BASIC FUNCTIONAL */

    function test_name_and_ticker() public virtual {
        assertEq(tokenV2.name(), "Wrapped Analog One Token");
        assertEq(tokenV2.symbol(), "WANLOG");
    }

    function test_decimals() public virtual {
        assertEq(tokenV2.decimals(), 12);
    }

    function test_Mint() public virtual preMint(address(this), 20_000) {
        assertEq(tokenV2.balanceOf(address(this)), 20_000);
    }

    function test_Transfer() public virtual preMint(address(this), 20_000) {
        assertEq(tokenV2.balanceOf(address(2)), 0);
        tokenV2.transfer(address(2), 5_000);
        assertEq(tokenV2.balanceOf(address(2)), 5_000);
    }

    function test_Pause() public virtual preMint(address(this), 20_000) paused {
        // error EnforcedPause()
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        tokenV2.transfer(address(2), 5_000);

        vm.prank(MINTER);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        tokenV2.mint(address(this), 1);
    }

    function test_UnPause() public virtual preMint(address(this), 20_000) paused {
        vm.prank(UNPAUSER);
        tokenV2.unpause();

        tokenV2.transfer(address(2), 5_000);
        assertEq(tokenV2.balanceOf(address(2)), 5_000);
    }

    function test_GrantRole() public virtual preMint(address(this), 20_000) {
        assertFalse(tokenV2.hasRole(keccak256("MINTER_ROLE"), NEW_MINTER));

        vm.prank(UPGRADER);
        tokenV2.grantRole(keccak256("MINTER_ROLE"), NEW_MINTER);

        vm.prank(NEW_MINTER);
        tokenV2.mint(NEW_MINTER, 5_000);
        assertEq(tokenV2.balanceOf(NEW_MINTER), 5_000);
        assertEq(tokenV2.totalSupply(), 25_000);
    }

    function test_RevokeRole() public virtual preMint(address(this), 20_000) {
        vm.prank(UPGRADER);
        tokenV2.revokeRole(keccak256("MINTER_ROLE"), MINTER);

        vm.prank(MINTER);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, MINTER, keccak256("MINTER_ROLE")
            )
        );
        tokenV2.mint(MINTER, 5_000);
    }

    function test_RevertWhen_Unauthorized_RevokeRole() public virtual {
        vm.prank(PAUSER);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, PAUSER, 0x00));
        tokenV2.revokeRole(keccak256("MINTER_ROLE"), MINTER);

        assert(tokenV2.hasRole(keccak256("MINTER_ROLE"), MINTER));
    }

    function test_RevertWhen_Unauthorized_Mint() public virtual {
        vm.prank(UPGRADER);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, UPGRADER, keccak256("MINTER_ROLE")
            )
        );
        tokenV2.mint(UPGRADER, 100_000);
    }

    function test_RevertWhen_Unauthorized_Pause() public virtual {
        vm.prank(MINTER);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, MINTER, keccak256("PAUSER_ROLE")
            )
        );
        tokenV2.pause();
    }

    function test_RevertWhen_Unauthorized_UnPause() public virtual paused {
        vm.prank(MINTER);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, MINTER, keccak256("UNPAUSER_ROLE")
            )
        );
        tokenV2.unpause();
    }

    /* OATS-specific FUNCTIONAL */

    function test_Cost() public virtual {
        bytes memory caldata;
        assertEq(tokenV2.cost(NETWORK, 21_000, caldata), COST);
    }

    function test_Recieve() public virtual preMint(MINTER, CAP / 2) {
        assertEq(tokenV2.balanceOf(MINTER), CAP / 2);
        assertEq(tokenV2.totalSupply(), CAP / 2);
        assertEq(tokenV2.balanceOf(PAUSER), 0);

        AnlogTokenV2.TransferCmd memory cmd = AnlogTokenV2.TransferCmd({
            from: MINTER,
            to: PAUSER,
            amount: AMOUNT,
            callee: address(0),
            caldata: new bytes(0)
        });

        bytes memory data = abi.encode(cmd);
        bytes32 token_b = bytes32(uint256(uint160(TOKEN_OTHER)));

        // NOT GATEWAY CB
        vm.expectPartialRevert(Utils.UnauthorizedGW.selector);
        tokenV2.onGmpReceived(MSG_ID, NETWORK, token_b, 0, data);

        // NETWORK NOT SET
        vm.prank(GATEWAY);
        vm.expectPartialRevert(Utils.UnknownNetwork.selector);
        tokenV2.onGmpReceived(MSG_ID, NETWORK, token_b, 0, data);

        vm.prank(UPGRADER);
        tokenV2.set_network(NETWORK, TOKEN_OTHER);

        // NO CALL
        vm.startPrank(GATEWAY);
        tokenV2.onGmpReceived(MSG_ID, NETWORK, token_b, 0, data);
        assertEq(tokenV2.balanceOf(PAUSER), AMOUNT);
        assertEq(tokenV2.totalSupply(), CAP / 2 + AMOUNT);
        assertEq(callee.total(), 0);

        // INVALID CALL:
        // - should not revert, but emit InvalidCallee event,
        // - should deliver the transfer
        cmd.callee = address(1);
        data = abi.encode(cmd);
        vm.expectEmit(true, false, false, false, address(tokenV2));
        emit Utils.InvalidCallee(address(1));
        tokenV2.onGmpReceived(MSG_ID, NETWORK, token_b, 0, data);
        assertEq(tokenV2.balanceOf(PAUSER), AMOUNT * 2);
        assertEq(tokenV2.totalSupply(), CAP / 2 + AMOUNT * 2);
        assertEq(callee.total(), 0);

        // CALL SUCCEED
        cmd.callee = address(callee);
        data = abi.encode(cmd);
        vm.expectEmit(address(tokenV2));
        emit Utils.CallSucceed();
        tokenV2.onGmpReceived(MSG_ID, NETWORK, token_b, 0, data);
        assertEq(tokenV2.balanceOf(PAUSER), AMOUNT * 3);
        assertEq(tokenV2.totalSupply(), CAP / 2 + AMOUNT * 3);
        assertEq(callee.total(), AMOUNT);

        // CALL FAILED:
        // - should not revert, but emit callFailed event,
        // - should deliver the transfer
        cmd.from = address(0);
        data = abi.encode(cmd);
        vm.expectEmit(address(tokenV2));
        emit Utils.CallFailed();
        tokenV2.onGmpReceived(MSG_ID, NETWORK, token_b, 0, data);
        assertEq(tokenV2.balanceOf(PAUSER), AMOUNT * 4);
        assertEq(tokenV2.totalSupply(), CAP / 2 + AMOUNT * 4);
        assertEq(callee.total(), AMOUNT);

        // CAP EXCEEDED
        data = abi.encode(
            AnlogTokenV2.TransferCmd({
                from: MINTER,
                to: PAUSER,
                amount: CAP / 2,
                callee: address(callee),
                caldata: new bytes(0)
            })
        );
        vm.expectPartialRevert(ERC20CappedUpgradeable.ERC20ExceededCap.selector);
        tokenV2.onGmpReceived(MSG_ID, NETWORK, token_b, 0, data);
    }

    function test_Send() public virtual preMint(MINTER, CAP / 2) {
        assertEq(tokenV2.balanceOf(MINTER), CAP / 2);
        assertEq(tokenV2.balanceOf(PAUSER), 0);

        vm.prank(PAUSER);
        vm.expectPartialRevert(Utils.UnknownToken.selector);
        tokenV2.send(NETWORK, MINTER, AMOUNT);

        vm.prank(UPGRADER);
        tokenV2.set_network(NETWORK, TOKEN);

        vm.prank(PAUSER);
        vm.expectPartialRevert(IERC20Errors.ERC20InsufficientBalance.selector);
        tokenV2.send(NETWORK, MINTER, AMOUNT);

        vm.prank(MINTER);
        tokenV2.transfer(PAUSER, AMOUNT);

        vm.prank(PAUSER);
        tokenV2.send(NETWORK, MINTER, AMOUNT);
        assertEq(tokenV2.balanceOf(PAUSER), 0);
        assertEq(tokenV2.totalSupply(), CAP / 2 - AMOUNT);
    }
}

contract Callee is ICallee {
    uint256 public total;
    address immutable _token;

    constructor(address token) {
        _token = token;
    }

    function onTransferReceived(address from, address, uint256 amount, bytes calldata) external {
        require(msg.sender == _token, "Unauthorized");
        require(from != address(0), "Failed");

        total += amount;
    }
}
