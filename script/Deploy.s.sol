// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {AssetRegistry} from "../src/AssetRegistry.sol";
import {SimpleToken} from "../src/SimpleToken.sol";

/// @notice Deploys both practice contracts to whichever network you point
///         this at (e.g. Sepolia). Run with:
///         forge script script/Deploy.s.sol:DeployScript --rpc-url $SEPOLIA_RPC_URL --broadcast
contract DeployScript is Script {
    function run() public {
        // Reads PRIVATE_KEY from your local .env (never hardcode this)
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Everything between startBroadcast/stopBroadcast gets sent as
        // real (test-net) transactions, signed by the key above.
        vm.startBroadcast(deployerPrivateKey);

        AssetRegistry registry = new AssetRegistry();
        console.log("AssetRegistry deployed at:", address(registry));

        SimpleToken token = new SimpleToken("Practice Token", "PRAC", 1_000_000 * 10 ** 18);
        console.log("SimpleToken deployed at:", address(token));

        vm.stopBroadcast();
    }
}
