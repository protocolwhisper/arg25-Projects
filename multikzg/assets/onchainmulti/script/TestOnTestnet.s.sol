// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {KZGMultipointVerifier} from "../src/KZGMultipointVerifier.sol";

/// @notice Script to test the deployed contract on testnet
/// Usage: forge script script/TestOnTestnet.s.sol:TestOnTestnetScript --rpc-url $RPC_URL --broadcast
contract TestOnTestnetScript is Script {
    function run() external {
        // Get contract address from environment or use a known deployment
        address verifierAddress = vm.envOr("VERIFIER_ADDRESS", address(0));
        require(verifierAddress != address(0), "VERIFIER_ADDRESS not set");
        
        console.log("Testing KZGMultipointVerifier at:", verifierAddress);
        
        KZGMultipointVerifier verifier = KZGMultipointVerifier(verifierAddress);
        
        // Test data from Rust generate_proof.rs
        // Polynomial: p(X) = 3*x^3 + 2*x^2 + x + 1
        // Evaluation points: [1, 2, 3]
        // Expected evaluations: p(1)=7, p(2)=35 (0x23), p(3)=103 (0x67)
        bytes memory negCommitmentMinusITau = hex"00993f79fb484cdf99c4616771e49dc09a38e8d0f0c6da761aa045d96b07c518246b6db57e2fb3534c34a702073210c1157fc455266f12a06979249b21dfa055cd5581d2f2132bc959ec047230909022db41ae0f31ec21f04861c3f305811514";
        bytes memory zCommit = hex"09935a0341bcab4e97800cc7cf78663b1d8e1a2218704189217810d32236f3c46a7d5312c80d2220bbd66da46240189500120bdbbd0da27f95e14d6bebe65257e196ef2b7bf4b680b1a8135eb7619e66f5310f053ad5aea0cd5f399a48a1f30d";
        bytes memory proof = hex"09380275bbc8e5dcea7dc4dd7e0550ff2ac480905396eda55062650f8d251c96eb480673937cc6d9d6a44aaa56ca66dc122915c824a0857e2ee414a3dccb23ae691ae54329781315a0c75df1c04d6d7a50a030fc866f09d516020ef82324afae08f239ba329b3967fe48d718a36cfe5f62a7e42e0bf1c1ed714150a166bfbd6bcf6b3b58b975b9edea56d53f23a0e8490b21da7955969e61010c7a1abc1a6f0136961d1e3b20b1a7326ac738fef5c721479dfd948b52fdf2455e44813ecfd892";
        
        bytes32[] memory zValues = new bytes32[](3);
        zValues[0] = bytes32(hex"0000000000000000000000000000000000000000000000000000000000000001");
        zValues[1] = bytes32(hex"0000000000000000000000000000000000000000000000000000000000000002");
        zValues[2] = bytes32(hex"0000000000000000000000000000000000000000000000000000000000000003");
        
        bytes32[] memory yValues = new bytes32[](3);
        yValues[0] = bytes32(hex"0000000000000000000000000000000000000000000000000000000000000007");
        yValues[1] = bytes32(hex"0000000000000000000000000000000000000000000000000000000000000023");
        yValues[2] = bytes32(hex"0000000000000000000000000000000000000000000000000000000000000067");
        
        console.log("Calling verifyMultipointProof...");
        bool result = verifier.verifyMultipointProof(
            negCommitmentMinusITau,
            zCommit,
            zValues,
            yValues,
            proof
        );
        
        console.log("Verification result:", result);
        
        if (result) {
            console.log("SUCCESS: Proof verification returned true!");
        } else {
            console.log("FAILURE: Proof verification returned false");
            console.log("This could indicate:");
            console.log("1. Point serialization issue");
            console.log("2. Pairing input format issue");
            console.log("3. Precompile availability issue");
        }
    }
}

