// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {KZGMultipointVerifier} from "../src/KZGMultipointVerifier.sol";

contract KZGMultipointVerifierTest is Test {
    KZGMultipointVerifier verifier;

    function setUp() public {
        bytes memory g2Generator = hex"13e02b6052719f607dacd3a088274f65596bd0d09920b61ab5da61bbdc7f5049334cf11213945d57e5ac7d055d042b7e024aa2b2f08f0a91260805272dc51051c6e47ad4fa403b02b4510b647ae3d1770bac0326a805bbefd48056c8c121bdb80606c4a02ea734cc32acd2b02bc28b99cb3e287e85a763af267492ab572e99ab3f370d275cec1da1aaa9075ff05f79be0ce5d527727d6e118cc9cdc6da2e351aadfd9baa8cbdd3a76d429a695160d12c923ac9cc3baca289e193548608b82801";
        verifier = new KZGMultipointVerifier(g2Generator);
    }

    function test_VerifyMultipointProof() public view {
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

        bool result = verifier.verifyMultipointProof(
            negCommitmentMinusITau,
            zCommit,
            zValues,
            yValues,
            proof
        );

        assertFalse(result, "Without precompiles the verifier should return false");
    }
}
