// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {RWAShareToken} from "../src/RWAShareToken.sol";
import {SecureVault} from "../src/SecureVault.sol";
import {SecureWallet} from "../src/SecureWallet.sol";
import {CheckedCounter} from "../src/CheckedCounter.sol";
import {CommitRevealGame} from "../src/CommitRevealGame.sol";

/// @notice Deploys the SECURE/production-shaped contracts from the
///         security case studies. Deliberately does NOT deploy the
///         vulnerable counterparts (VulnerableVault, TxOriginWallet,
///         UncheckedCounter, GuessingGame) — those exist purely as
///         documented, tested exploits in the repo's source code, not
///         as things worth having live on a public explorer.
///
///         Run with:
///         forge script script/DeploySecurity.s.sol:DeploySecurityScript --rpc-url $SEPOLIA_RPC_URL --broadcast
contract DeploySecurityScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        RWAShareToken rwaToken = new RWAShareToken("Nairobi Office Tower Shares", "NOTS", deployer);
        console.log("RWAShareToken deployed at:", address(rwaToken));

        SecureVault secureVault = new SecureVault();
        console.log("SecureVault deployed at:", address(secureVault));

        SecureWallet secureWallet = new SecureWallet();
        console.log("SecureWallet deployed at:", address(secureWallet));

        CheckedCounter checkedCounter = new CheckedCounter();
        console.log("CheckedCounter deployed at:", address(checkedCounter));

        CommitRevealGame commitRevealGame = new CommitRevealGame{value: 0}("blockchain");
        console.log("CommitRevealGame deployed at:", address(commitRevealGame));

        vm.stopBroadcast();
    }
}
