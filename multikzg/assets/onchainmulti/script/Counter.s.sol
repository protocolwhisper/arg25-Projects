// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {KZGMultipointVerifier} from "../src/KZGMultipointVerifier.sol";


contract KZG is Script {
    KZGMultipointVerifier public kzg;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // G2 Generator from testkzg.py (BLS12-381 G2 generator in uncompressed format, 192 bytes)
        bytes memory g2Generator = hex"024aa2b2f08f0a91260805272dc51051c6e47ad4fa403b02b4510b647ae3d1770bac0326a805bbefd48056c8c121bdb813e02b6052719f607dacd3a088274f65596bd0d09920b61ab5da61bbdc7f5049334cf11213945d57e5ac7d055d042b7e0ce5d527727d6e118cc9cdc6da2e351aadfd9baa8cbdd3a76d429a695160d12c923ac9cc3baca289e193548608b828010606c4a02ea734cc32acd2b02bc28b99cb3e287e85a763af267492ab572e99ab3f370d275cec1da1aaa9075ff05f79be";
        kzg = new KZGMultipointVerifier(g2Generator);

        vm.stopBroadcast();
    }
}
