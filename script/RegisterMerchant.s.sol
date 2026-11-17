// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {OrkoPayRegistry} from "../src/OrkoPayRegistry.sol";

/// @notice Registers a single merchant. Normally done by the onboarding
///         service; this script exists for staging and manual recovery.
///
/// Usage:
///   REGISTRY=0x... MERCHANT=0x... PAYOUT=0x... MERCHANT_NAME="Acme" \
///   forge script script/RegisterMerchant.s.sol --rpc-url $RPC_URL --broadcast
contract RegisterMerchant is Script {
    function run() external {
        uint256 pk = vm.envUint("OPERATOR_PRIVATE_KEY");
        OrkoPayRegistry registry = OrkoPayRegistry(vm.envAddress("REGISTRY"));

        address merchant = vm.envAddress("MERCHANT");
        address payout = vm.envAddress("PAYOUT");
        uint16 tier = uint16(vm.envOr("TIER_DISCOUNT_BPS", uint256(0)));
        string memory name = vm.envString("MERCHANT_NAME");

        vm.startBroadcast(pk);
        registry.register(merchant, payout, tier, name);
        vm.stopBroadcast();

        console2.log("Registered merchant:", merchant);
        console2.log("Payout:             ", payout);
        console2.log("Tier discount (bps):", tier);
    }
}
