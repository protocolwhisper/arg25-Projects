// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {KZGMultipointVerifier} from "../src/KZGMultipointVerifier.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        // G2 Generator (from Rust generate_proof.rs output)
        bytes memory g2Generator = hex"13e02b6052719f607dacd3a088274f65596bd0d09920b61ab5da61bbdc7f5049334cf11213945d57e5ac7d055d042b7e024aa2b2f08f0a91260805272dc51051c6e47ad4fa403b02b4510b647ae3d1770bac0326a805bbefd48056c8c121bdb80606c4a02ea734cc32acd2b02bc28b99cb3e287e85a763af267492ab572e99ab3f370d275cec1da1aaa9075ff05f79be0ce5d527727d6e118cc9cdc6da2e351aadfd9baa8cbdd3a76d429a695160d12c923ac9cc3baca289e193548608b82801";
        
        console.log("Deploying KZGMultipointVerifier...");
        KZGMultipointVerifier verifier = new KZGMultipointVerifier(g2Generator);
        
        console.log("KZGMultipointVerifier deployed at:", address(verifier));
        console.log("G2 Generator length:", g2Generator.length);
        
        vm.stopBroadcast();
    }
}

