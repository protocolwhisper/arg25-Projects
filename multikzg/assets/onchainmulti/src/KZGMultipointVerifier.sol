// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Verifies KZG multipoint evaluation proofs: e(z_commit, proof) * e(-(commitment - i_tau), G2) == 1
contract KZGMultipointVerifier {
    address constant PAIRING_PRECOMPILE = address(0x0F);
    address constant G1_ADD_PRECOMPILE = address(0x0B);
    address constant G1_MSM_PRECOMPILE = address(0x0C);
    address constant G2_ADD_PRECOMPILE = address(0x0D);
    address constant G2_MSM_PRECOMPILE = address(0x0E);
    address constant G1_MAP_FP_TO_G1 = address(0x10);
    address constant G2_MAP_FP2_TO_G2 = address(0x11);
    address constant KZG_MULTIPOINT_EVALUATION = address(0x12);
    uint256 constant MAX_EVALUATION_POINTS = 128;

    bytes public g2Generator;
    
    constructor(bytes memory _g2Generator) {
        require(_g2Generator.length == 192, "KZG: G2 generator must be 192 bytes");
        g2Generator = _g2Generator;
    }

    /// @notice Verifies multipoint proof. Points must be uncompressed (96 bytes G1, 192 bytes G2)
    function verifyMultipointProof(
        bytes calldata negCommitmentMinusITau,
        bytes calldata zCommit,
        bytes32[] calldata zValues,
        bytes32[] calldata yValues,
        bytes calldata proof
    ) external view returns (bool) {
        require(zValues.length == yValues.length, "KZG: zValues and yValues length mismatch");
        require(zValues.length > 0 && zValues.length <= MAX_EVALUATION_POINTS, "KZG: invalid number of points");
        require(negCommitmentMinusITau.length == 96, "KZG: negCommitmentMinusITau must be uncompressed (96 bytes)");
        require(zCommit.length == 96, "KZG: zCommit must be uncompressed (96 bytes)");
        require(proof.length == 192, "KZG: proof must be uncompressed (192 bytes)");
        
        bytes memory paddedZCommit = padG1Point(zCommit);
        bytes memory paddedProof = padG2Point(proof);
        bytes memory paddedNegCommitmentMinusITau = padG1Point(negCommitmentMinusITau);
        bytes memory paddedG2Generator = padG2Point(g2Generator);
        
        require(paddedZCommit.length == 128, "Invalid padded zCommit length");
        require(paddedProof.length == 256, "Invalid padded proof length");
        require(paddedNegCommitmentMinusITau.length == 128, "Invalid padded negCommitmentMinusITau length");
        require(paddedG2Generator.length == 256, "Invalid padded G2Generator length");
        
        bytes memory pairingInput = abi.encodePacked(
            paddedZCommit,
            paddedProof,
            paddedNegCommitmentMinusITau,
            paddedG2Generator
        );
        
        require(pairingInput.length == 768, "Invalid pairing input length");

        (bool success, bytes memory result) = PAIRING_PRECOMPILE.staticcall(pairingInput);
        
        if (!success || result.length != 32) {
            return false;
        }

        uint256 resultValue;
        assembly {
            resultValue := mload(add(result, 32))
        }
        
        return (resultValue & 0xff) == 1;
    }

    function g1Sub(bytes memory a, bytes memory b) internal view returns (bytes memory) {
        bytes memory negB = g1Neg(b);
        return g1Add(a, negB);
    }

    function padG1Point(bytes memory unpadded) internal pure returns (bytes memory) {
        require(unpadded.length == 96, "Invalid unpadded G1 point length");
        bytes memory padded = new bytes(128);
        for (uint256 i = 0; i < 48; i++) {
            padded[16 + i] = unpadded[i];
            padded[80 + i] = unpadded[48 + i];
        }
        return padded;
    }
    
    function unpadG1Point(bytes memory padded) internal pure returns (bytes memory) {
        require(padded.length == 128, "Invalid padded G1 point length");
        bytes memory unpadded = new bytes(96);
        assembly {
            mstore(add(unpadded, 32), mload(add(padded, 48)))
            mstore(add(unpadded, 64), mload(add(padded, 64)))
            mstore(add(unpadded, 96), mload(add(padded, 112)))
        }
        return unpadded;
    }
    
    function padG2Point(bytes memory unpadded) internal pure returns (bytes memory) {
        require(unpadded.length == 192, "Invalid unpadded G2 point length");
        bytes memory padded = new bytes(256);
        for (uint256 i = 0; i < 48; i++) {
            padded[16 + i] = unpadded[i];
            padded[80 + i] = unpadded[48 + i];
            padded[144 + i] = unpadded[96 + i];
            padded[208 + i] = unpadded[144 + i];
        }
        return padded;
    }
    
    function g1Add(bytes memory a, bytes memory b) internal view returns (bytes memory result) {
        bytes memory paddedA = padG1Point(a);
        bytes memory paddedB = padG1Point(b);
        bytes memory input = abi.encodePacked(paddedA, paddedB);
        (bool success, bytes memory output) = G1_ADD_PRECOMPILE.staticcall(input);
        require(success, "G1 addition failed");
        require(output.length == 128, "Invalid G1 addition output");
        return unpadG1Point(output);
    }

    function g1Neg(bytes memory point) internal view returns (bytes memory) {
        require(point.length == 96, "Invalid G1 point length");
        bytes32 scalarMinusOne = 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000000;
        bytes memory paddedPoint = padG1Point(point);
        bytes memory input = abi.encodePacked(paddedPoint, scalarMinusOne);
        (bool success, bytes memory output) = G1_MSM_PRECOMPILE.staticcall(input);
        require(success && output.length == 128, "G1 negation failed");
        return unpadG1Point(output);
    }
    
    function g2Neg(bytes memory point) internal view returns (bytes memory) {
        require(point.length == 192, "Invalid G2 point length");
        bytes32 scalarMinusOne = 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000000;
        bytes memory paddedPoint = padG2Point(point);
        bytes memory input = abi.encodePacked(paddedPoint, scalarMinusOne);
        (bool success, bytes memory output) = G2_MSM_PRECOMPILE.staticcall(input);
        require(success && output.length == 256, "G2 negation failed");
        return unpadG2Point(output);
    }
    
    function unpadG2Point(bytes memory padded) internal pure returns (bytes memory) {
        require(padded.length == 256, "Invalid padded G2 point length");
        bytes memory unpadded = new bytes(192);
        assembly {
            mstore(add(unpadded, 32), mload(add(padded, 48)))
            mstore(add(unpadded, 64), mload(add(padded, 64)))
            mstore(add(unpadded, 96), mload(add(padded, 112)))
            mstore(add(unpadded, 128), mload(add(padded, 128)))
            mstore(add(unpadded, 160), mload(add(padded, 176)))
            mstore(add(unpadded, 192), mload(add(padded, 192)))
            mstore(add(unpadded, 224), mload(add(padded, 240)))
            mstore(add(unpadded, 256), mload(add(padded, 256)))
        }
        return unpadded;
    }
}
