// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AnlogTokenV2} from "../src/AnlogTokenV2.sol";

import {
    IGateway,
    IExecutor,
    Gateway,
    Route,
    NetworkID,
    ERC1967,
    TssKey,
    GmpMessage,
    Signature
} from "analog-gmp/src/Gateway.sol";
import {GmpMessage, PrimitiveUtils, GmpSender, GmpStatus} from "analog-gmp/src/Primitives.sol";
import {TestUtils, SigningKey, SigningUtils} from "analog-gmp/test/TestUtils.sol";

/// @notice OZ ERC20 and its presets are covered with Hardhat tests.
/// Hence we keep these few basic tests here more as a boilerplate for
/// the future tests for custom added features.
contract AnlogTokenV2Test is Test {
    using PrimitiveUtils for GmpMessage;
    using SigningUtils for SigningKey;

    AnlogTokenV2 public tokenV2;

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

    // Chronicle TSS Secret
    uint256 private constant SECRET = 0x42;
    address private constant SIGNER_ADDRESS = 0x2e234DAe75C793f67A35089C9d99245E1C58470b;
    uint256 private constant SIGNING_NONCE = 0x69;

    /// @notice deploys an UUPS proxy.
    /// Here we start with the V2 implementation right away.
    /// For V1->V2 upgrade see another test.
    function setUp() public virtual {
        sepoliaFork = vm.createFork(SEPOLIA_RPC_URL);
        vm.selectFork(sepoliaFork);
        assertEq(vm.activeFork(), sepoliaFork);

        Options memory opts;
        opts.constructorData = abi.encode(GATEWAY, TIMECHAIN_ID, MIN_TELEPORT_VAL);

        // deploy proxy with a distinct address assigned to each role
        address proxy = Upgrades.deployUUPSProxy(
            "AnlogTokenV2.sol", abi.encodeCall(AnlogTokenV2.initialize, (MINTER, UPGRADER, PAUSER, UNPAUSER)), opts
        );
        tokenV2 = AnlogTokenV2(proxy);
    }

    modifier setRoute() {
        Route memory route = Route(NetworkID.wrap(1000), 15_000_000, 0, bytes32(bytes20(address(42))), 1, 1);
        address payable gw = payable(GATEWAY);

        vm.prank(GW_ADMIN);
        Gateway(gw).setRoute(route);

        _;
    }

    modifier setShard() {
        Route memory route = Route(NetworkID.wrap(1000), 15_000_000, 0, bytes32(bytes20(address(42))), 1, 1);
        address payable gw = payable(GATEWAY);

        SigningKey memory signer = TestUtils.createSigner(SECRET);
        TssKey memory shardKey = TssKey({yParity: signer.yParity() == 28 ? 3 : 2, xCoord: signer.xCoord()});

        vm.prank(GW_ADMIN);
        Gateway(gw).setShard(shardKey);

        _;
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

    function sign(GmpMessage memory gmp) internal pure returns (Signature memory) {
        bytes32 hash = gmp.opHash();
        SigningKey memory signer = TestUtils.createSigner(SECRET);
        (uint256 e, uint256 s) = signer.signPrehashed(hash, SIGNING_NONCE);
        return Signature({xCoord: signer.xCoord(), e: e, s: s});
    }

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

    function test_TeleportOut_Below_ED() public virtual preMint(address(this), MIN_TELEPORT_VAL - 1) {
        bytes32 dest = bytes32(bytes20(UPGRADER));
        vm.expectRevert("value below minimum required");
        tokenV2.teleport(dest, MIN_TELEPORT_VAL - 1);
    }

    function test_TeleportOut_Low_Value() public virtual preMint(address(this), MIN_TELEPORT_VAL) setRoute {
        bytes32 dest = bytes32(bytes20(uint160(UPGRADER)));

        vm.expectEmit(address(tokenV2));
        emit IERC20.Transfer(address(this), address(0), MIN_TELEPORT_VAL);
        vm.expectRevert("insufficient tx value");
        tokenV2.teleport(dest, MIN_TELEPORT_VAL);
    }

    function test_TeleportOut() public virtual preMint(address(this), MIN_TELEPORT_VAL) setRoute {
        address payable gw = payable(GATEWAY);
        bytes32 dest = bytes32(uint256(uint160(UPGRADER)));
        uint256 cost = tokenV2.estimateTeleportCost();

        GmpSender source = GmpSender.wrap(bytes32(uint256(uint160(SIGNER_ADDRESS))));

        AnlogTokenV2.OutboundTeleportCommand memory command =
            AnlogTokenV2.OutboundTeleportCommand(address(this), dest, MIN_TELEPORT_VAL);

        GmpMessage memory gmp = GmpMessage({
            source: source,
            srcNetwork: Gateway(gw).networkId(),
            dest: address(0),
            destNetwork: TIMECHAIN_ID,
            gasLimit: 100_000,
            nonce: 0,
            data: abi.encode(command)
        });

        bytes32 messageID = gmp.opHash();

        vm.expectEmit(address(tokenV2));
        emit IERC20.Transfer(address(this), address(0), MIN_TELEPORT_VAL);

        vm.expectEmit(true, true, true, true, address(GATEWAY));
        emit IGateway.GmpCreated(
            messageID,
            GmpSender.unwrap(gmp.source),
            gmp.dest,
            gmp.destNetwork,
            gmp.gasLimit,
            179835,
            gmp.nonce,
            gmp.data
        );

        vm.expectEmit(true, true, true, true, address(tokenV2));
        emit AnlogTokenV2.OutboundTransfer(messageID, address(this), dest, MIN_TELEPORT_VAL);

        tokenV2.teleport{value: cost}(dest, MIN_TELEPORT_VAL);
    }

    function test_TeleportIn() public virtual setRoute setShard {
        address payable gw = payable(GATEWAY);
        GmpSender source = GmpSender.wrap(bytes32(uint256(uint160(0))));

        AnlogTokenV2.InboundTeleportCommand memory command =
            AnlogTokenV2.InboundTeleportCommand(GmpSender.unwrap(source), UPGRADER, MIN_TELEPORT_VAL);

        GmpMessage memory gmp = GmpMessage({
            source: source,
            srcNetwork: TIMECHAIN_ID,
            dest: address(tokenV2),
            destNetwork: Gateway(gw).networkId(),
            gasLimit: 100_000,
            nonce: 0,
            data: abi.encode(command)
        });

        assertEq(tokenV2.totalSupply(), 0);

        Signature memory sig = sign(gmp);
        bytes32 messageID = gmp.opHash();

        vm.expectEmit(true, true, true, true, GATEWAY);
        emit IExecutor.GmpExecuted(messageID, gmp.source, gmp.dest, GmpStatus.SUCCESS, bytes32(MIN_TELEPORT_VAL));

        Gateway(gw).execute(sig, gmp);
        assertTrue(Gateway(gw).gmpInfo(messageID).status == GmpStatus.SUCCESS, "failed to execute GMP message");

        assertEq(tokenV2.balanceOf(UPGRADER), MIN_TELEPORT_VAL);
        assertEq(tokenV2.totalSupply(), MIN_TELEPORT_VAL);
    }
}
