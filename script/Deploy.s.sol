// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {OrkoPay} from "../src/OrkoPay.sol";
import {OrkoPayRegistry} from "../src/OrkoPayRegistry.sol";
import {OrkoPayLens} from "../src/periphery/OrkoPayLens.sol";

/// @notice Deploys the registry, settlement contract and lens, then hands
///         ownership of both admin contracts to the operations multisig.
///
/// The multisig must call `acceptOwnership()` on OrkoPayRegistry and OrkoPay
/// to complete the handover. Until then the deployer remains owner.
///
/// Usage:
///   forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --verify
contract Deploy is Script {
    function run() external returns (OrkoPayRegistry registry, OrkoPay pay, OrkoPayLens lens) {
        uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(pk);

        address owner = vm.envAddress("OWNER");
        address operator = vm.envOr("OPERATOR", address(0));
        address feeRecipient = vm.envOr("FEE_RECIPIENT", owner);
        uint16 baseFeeBps = uint16(vm.envOr("BASE_FEE_BPS", uint256(250)));
        uint32 refundWindow = uint32(vm.envOr("REFUND_WINDOW", uint256(14 days)));
        address usdc = vm.envOr("USDC_ADDRESS", address(0));

        console2.log("Chain id:      ", block.chainid);
        console2.log("Deployer:      ", deployer);
        console2.log("Owner (pending):", owner);

        vm.startBroadcast(pk);

        registry = new OrkoPayRegistry(deployer);
        pay = new OrkoPay(deployer, registry, feeRecipient, baseFeeBps, refundWindow);
        lens = new OrkoPayLens();

        if (operator != address(0)) registry.setOperator(operator, true);
        if (usdc != address(0)) pay.setSupportedAsset(usdc, true);

        registry.transferOwnership(owner);
        pay.transferOwnership(owner);

        vm.stopBroadcast();

        console2.log("OrkoPayRegistry:", address(registry));
        console2.log("OrkoPay:        ", address(pay));
        console2.log("OrkoPayLens:    ", address(lens));
    }
}
