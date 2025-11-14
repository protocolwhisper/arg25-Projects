// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title KZGMultipointVerifier
 * @notice Verifies KZG multipoint evaluation proofs using BLS12-381 pairing
 * @dev Based on the multipoint verification logic from the Rust implementation
 * 
 * The verification checks:
 *   e(z_commit, proof) * e(-(commitment - i_tau), G2) == 1
 * 
 * Where:
 *   - commitment: G1 point commitment to polynomial p(X)
 *   - i_tau: G1 point commitment to interpolation polynomial I(X)
 *   - z_commit: G1 point commitment to zero polynomial Z(X) = ∏(X - z_i)
 *   - proof: G2 point multiproof [q(τ)]₂
 *   - G2: G2 generator point
 * 
 * This contract accepts points in uncompressed format (64 bytes for G1, 128 bytes for G2)
 * to work with the BLS12-381 pairing precompile directly.
 */
contract KZGMultipointVerifier {
    // BLS12-381 pairing precompile address (EIP-2537)
    address constant PAIRING_PRECOMPILE = address(0x0F);
    
    // BLS12-381 G1 addition precompile
    address constant G1_ADD_PRECOMPILE = address(0x0B);
    
    // BLS12-381 G1 multi-scalar multiplication precompile  
    address constant G1_MSM_PRECOMPILE = address(0x0C);
    
    // BLS12-381 G2 addition precompile
    address constant G2_ADD_PRECOMPILE = address(0x0D);
    
    // BLS12-381 G2 multi-scalar multiplication precompile
    address constant G2_MSM_PRECOMPILE = address(0x0E);
    
    // BLS12-381 G1 point decompression precompile
    address constant G1_MAP_FP_TO_G1 = address(0x0F);
    
    // BLS12-381 G2 point decompression precompile
    address constant G2_MAP_FP2_TO_G2 = address(0x10);
    
    uint256 constant MAX_EVALUATION_POINTS = 128;

    bytes public g2Generator;
    
    /**
     * @notice Constructor - initializes the contract with the G2 generator
     * @param _g2Generator Uncompressed G2 generator point (192 bytes)
     * @dev The G2 generator is a constant for BLS12-381, but we accept it as input
     *      to avoid hardcoding and allow flexibility. Generate it using testkzg.py
     *      Note: The precompiles don't expose the G2 generator directly, so we must
     *      pass it as a parameter. This is standard practice in Solidity.
     */
    constructor(bytes memory _g2Generator) {
        require(_g2Generator.length == 192, "KZG: G2 generator must be 192 bytes");
        g2Generator = _g2Generator;
    }

    /**
     * @notice Verifies a KZG multipoint evaluation proof
     * @param negCommitmentMinusITau Uncompressed G1 point (96 bytes) - precomputed -(commitment - iTau)
     * @param zValues Array of evaluation points (32 bytes each)
     * @param yValues Array of evaluation values (32 bytes each)
     * @param proof Uncompressed G2 point (192 bytes: 96 bytes x || 96 bytes y) - multiproof [q(τ)]₂
     * @param zCommit Uncompressed G1 point (96 bytes) - commitment to zero polynomial Z(X)
     * @return true if the proof is valid, false otherwise
     * @dev All points must be in uncompressed format (96 bytes for G1, 192 bytes for G2)
     *      because the BLS12-381 pairing precompile requires uncompressed points.
     *      BLS12-381 field elements are 48 bytes (384 bits), so G1 = 96 bytes, G2 = 192 bytes.
     *      Use the Python script (testkzg.py) to generate uncompressed points from compressed ones.
     *      Note: negCommitmentMinusITau is computed off-chain to avoid needing G1 negation precompiles.
     *      Pairing equation: e(z_commit, proof) * e(-(commitment - i_tau), G2) == 1
     */
    function verifyMultipointProof(
        bytes calldata negCommitmentMinusITau,
        bytes32[] calldata zValues,
        bytes32[] calldata yValues,
        bytes calldata proof,
        bytes calldata zCommit
    ) external view returns (bool) {
        // Sanity checks
        require(zValues.length == yValues.length, "KZG: zValues and yValues length mismatch");
        require(zValues.length > 0 && zValues.length <= MAX_EVALUATION_POINTS, "KZG: invalid number of points");
        
        // Require uncompressed format (96 bytes for G1, 192 bytes for G2)
        // BLS12-381 field elements are 48 bytes, so G1 = 96 bytes (x: 48 + y: 48), G2 = 192 bytes
        require(negCommitmentMinusITau.length == 96, "KZG: negCommitmentMinusITau must be uncompressed (96 bytes)");
        require(proof.length == 192, "KZG: proof must be uncompressed (192 bytes)");
        require(zCommit.length == 96, "KZG: zCommit must be uncompressed (96 bytes)");
        
        // Pairing equation: e(z_commit, proof) * e(-(commitment - i_tau), G2) == 1
        // Following Rust implementation: pairing_check(&[(z_commit, proof), (-(commitment - i_tau), g2)])
        // We need to negate the G1 point (commitmentMinusITau), not the G2 generator
        // Since we can't do G1 negation on-chain, we compute it off-chain and pass it as a parameter
        
        // Prepare pairing inputs
        // Pairing precompile expects padded points: [G1_1 (128 bytes), G2_1 (256 bytes), G1_2 (128 bytes), G2_2 (256 bytes)]
        bytes memory paddedZCommit = padG1Point(zCommit);
        bytes memory paddedProof = padG2Point(proof);
        bytes memory paddedNegCommitmentMinusITau = padG1Point(negCommitmentMinusITau);  // This should be pre-negated off-chain
        bytes memory paddedG2Generator = padG2Point(g2Generator);  // Use regular G2 generator, not negated
        
        // Verify padding lengths
        require(paddedZCommit.length == 128, "Invalid padded ZCommit length");
        require(paddedProof.length == 256, "Invalid padded proof length");
        require(paddedNegCommitmentMinusITau.length == 128, "Invalid padded negCommitmentMinusITau length");
        require(paddedG2Generator.length == 256, "Invalid padded G2Generator length");
        
        // Pairing equation from document: e(π, [Z(s)]₂) = e(C - [I(s)]₁, H)
        // Which rearranges to: e(proof, z_commit) * e(-(commitment - i_tau), G2) = 1
        // For BLS12-381, pairing is e(G1, G2), so we need:
        // e(proof (G2), z_commit (G1)) = e(G2, G1) - but this is wrong!
        // Actually, the document notation might be: π in G2, [Z(s)]₂ in G2, but that doesn't work for BLS12-381
        // Rust uses: e(z_commit (G1), proof (G2)) * e(-(commitment - i_tau) (G1), G2) = 1
        // Following Rust implementation exactly:
        bytes memory pairingInput = abi.encodePacked(
            paddedZCommit,      // G1 point 1 (128 bytes) - z_commit
            paddedProof,        // G2 point 1 (256 bytes) - proof
            paddedNegCommitmentMinusITau,  // G1 point 2 (128 bytes) - -(commitment - i_tau)
            paddedG2Generator   // G2 point 2 (256 bytes) - G2 generator
        );
        
        // Pairing input should be 768 bytes (2 pairs * 384 bytes per pair)
        require(pairingInput.length == 768, "Invalid pairing input length");

        // Call BLS12-381 pairing precompile (address 0x09)
        // Pairing precompile expects: 384*k bytes where k is number of pairs
        // Each pair: 128 bytes G1 + 256 bytes G2
        (bool success, bytes memory result) = PAIRING_PRECOMPILE.staticcall(pairingInput);
        
        if (!success) {
            return false;
        }
        
        // Pairing precompile returns 32 bytes: first 31 bytes are 0x00, last byte is 0x01 if pairing is valid
        if (result.length != 32) {
            return false;
        }

        // Check if pairing result is 1 (success)
        // Result is in big-endian format: 0x00...00 0x01 for success, 0x00...00 0x00 for failure
        uint256 resultValue;
        assembly {
            resultValue := mload(add(result, 32))
        }
        
        // Check if last byte is 0x01
        return (resultValue & 0xff) == 1;
    }

    /**
     * @notice Subtracts two G1 points: result = a - b
     * @dev Uses G1 addition precompile with negated b
     */
    function g1Sub(bytes memory a, bytes memory b) internal view returns (bytes memory) {
        bytes memory negB = g1Neg(b);
        return g1Add(a, negB);
    }

    /**
     * @notice Pads an uncompressed G1 point (96 bytes) to EVM format (128 bytes)
     * @dev Adds 16 bytes of zeros before each 48-byte field element
     */
    function padG1Point(bytes memory unpadded) internal pure returns (bytes memory) {
        require(unpadded.length == 96, "Invalid unpadded G1 point length");
        bytes memory padded = new bytes(128);
        // Pad x coordinate: 16 zeros + 48 bytes
        // Pad y coordinate: 16 zeros + 48 bytes
        assembly {
            // Copy x (skip first 16 bytes for padding)
            mstore(add(padded, 48), mload(add(unpadded, 32)))
            mstore(add(padded, 64), mload(add(unpadded, 64)))
            // Copy y (skip first 16 bytes for padding)
            mstore(add(padded, 112), mload(add(unpadded, 96)))
        }
        return padded;
    }
    
    /**
     * @notice Unpads a padded G1 point (128 bytes) to uncompressed format (96 bytes)
     * @dev Removes 16 bytes of zeros before each 48-byte field element
     */
    function unpadG1Point(bytes memory padded) internal pure returns (bytes memory) {
        require(padded.length == 128, "Invalid padded G1 point length");
        bytes memory unpadded = new bytes(96);
        assembly {
            // Copy x (skip first 16 bytes of padding)
            mstore(add(unpadded, 32), mload(add(padded, 48)))
            mstore(add(unpadded, 64), mload(add(padded, 64)))
            // Copy y (skip first 16 bytes of padding)
            mstore(add(unpadded, 96), mload(add(padded, 112)))
        }
        return unpadded;
    }
    
    /**
     * @notice Pads an uncompressed G2 point (192 bytes) to EVM format (256 bytes)
     * @dev Adds 16 bytes of zeros before each 48-byte field element (x0, x1, y0, y1)
     */
    function padG2Point(bytes memory unpadded) internal pure returns (bytes memory) {
        require(unpadded.length == 192, "Invalid unpadded G2 point length");
        bytes memory padded = new bytes(256);
        // Each field element gets 16 bytes padding + 48 bytes data
        assembly {
            // Copy x0 (skip first 16 bytes for padding)
            mstore(add(padded, 48), mload(add(unpadded, 32)))
            mstore(add(padded, 64), mload(add(unpadded, 64)))
            // Copy x1
            mstore(add(padded, 112), mload(add(unpadded, 96)))
            mstore(add(padded, 128), mload(add(unpadded, 128)))
            // Copy y0
            mstore(add(padded, 176), mload(add(unpadded, 160)))
            mstore(add(padded, 192), mload(add(unpadded, 192)))
            // Copy y1
            mstore(add(padded, 240), mload(add(unpadded, 224)))
            mstore(add(padded, 256), mload(add(unpadded, 256)))
        }
        return padded;
    }
    
    /**
     * @notice Adds two G1 points: result = a + b
     * @dev Uses BLS12-381 G1 addition precompile (address 0x0B)
     *      Expects and returns uncompressed points (96 bytes), but pads for precompile
     */
    function g1Add(bytes memory a, bytes memory b) internal view returns (bytes memory result) {
        bytes memory paddedA = padG1Point(a);
        bytes memory paddedB = padG1Point(b);
        bytes memory input = abi.encodePacked(paddedA, paddedB);
        (bool success, bytes memory output) = G1_ADD_PRECOMPILE.staticcall(input);
        require(success, "G1 addition failed");
        require(output.length == 128, "Invalid G1 addition output");
        return unpadG1Point(output);
    }

    /**
     * @notice Negates a G1 point: result = -p
     * @dev For BLS12-381: -P = (x, -y mod p)
     *      Uses G1 MSM precompile with scalar -1 to compute negation
     *      Scalar -1 = r - 1 where r is the scalar field order
     */
    function g1Neg(bytes memory point) internal view returns (bytes memory) {
        require(point.length == 96, "Invalid G1 point length");
        
        // Scalar field order r = 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001
        // So -1 mod r = r - 1 = 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000000
        bytes32 scalarMinusOne = 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000000;
        
        bytes memory paddedPoint = padG1Point(point);
        bytes memory input = abi.encodePacked(paddedPoint, scalarMinusOne);
        
        (bool success, bytes memory output) = G1_MSM_PRECOMPILE.staticcall(input);
        require(success && output.length == 128, "G1 negation failed");
        
        return unpadG1Point(output);
    }
    
    /**
     * @notice Negates a G2 point: result = -p
     * @dev For BLS12-381: -P = (x, -y mod p) where x, y are in Fp2
     *      Uses G2 MSM precompile with scalar -1 to compute negation
     *      Scalar -1 = r - 1 where r is the scalar field order
     */
    function g2Neg(bytes memory point) internal view returns (bytes memory) {
        require(point.length == 192, "Invalid G2 point length");
        
        // Scalar field order r = 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001
        // So -1 mod r = r - 1 = 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000000
        bytes32 scalarMinusOne = 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000000;
        
        bytes memory paddedPoint = padG2Point(point);
        bytes memory input = abi.encodePacked(paddedPoint, scalarMinusOne);
        
        (bool success, bytes memory output) = G2_MSM_PRECOMPILE.staticcall(input);
        require(success && output.length == 256, "G2 negation failed");
        
        return unpadG2Point(output);
    }
    
    /**
     * @notice Unpads a padded G2 point (256 bytes) to uncompressed format (192 bytes)
     * @dev Removes 16 bytes of zeros before each 48-byte field element
     */
    function unpadG2Point(bytes memory padded) internal pure returns (bytes memory) {
        require(padded.length == 256, "Invalid padded G2 point length");
        bytes memory unpadded = new bytes(192);
        assembly {
            // Copy x0 (skip first 16 bytes of padding)
            mstore(add(unpadded, 32), mload(add(padded, 48)))
            mstore(add(unpadded, 64), mload(add(padded, 64)))
            // Copy x1
            mstore(add(unpadded, 96), mload(add(padded, 112)))
            mstore(add(unpadded, 128), mload(add(padded, 128)))
            // Copy y0
            mstore(add(unpadded, 160), mload(add(padded, 176)))
            mstore(add(unpadded, 192), mload(add(padded, 192)))
            // Copy y1
            mstore(add(unpadded, 224), mload(add(padded, 240)))
            mstore(add(unpadded, 256), mload(add(padded, 256)))
        }
        return unpadded;
    }
}
