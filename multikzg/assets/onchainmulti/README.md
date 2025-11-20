# KZG Multipoint Verifier

On-chain Solidity contract for verifying KZG multipoint evaluation proofs using BLS12-381 precompiles.

## Overview

Verifies KZG multipoint proofs using the **BLS12-381 pairing precompile at address `0x0F`**.

**Note:** The KZG multipoint evaluation precompile is at address `0x12` (0x0B-0x11 are taken by BLS12-381 precompiles).

Pairing equation: `e(z_commit, proof) * e(-(commitment - i_tau), G2) == 1`

## Setup

```bash
cd arg25-Projects/multikzg/assets/onchainmulti
forge install
```

## Testing

```bash
forge test
```

## Contract Usage

```solidity
function verifyMultipointProof(
    bytes calldata negCommitmentMinusITau,  // 96 bytes - Precomputed -(commitment - iTau)
    bytes calldata zCommit,                 // 96 bytes - Zero polynomial commitment
    bytes32[] calldata zValues,             // Evaluation points
    bytes32[] calldata yValues,             // Evaluation values
    bytes calldata proof                    // 192 bytes - G2 multiproof
) external view returns (bool)
```

**Note:** Points must be uncompressed (96 bytes G1, 192 bytes G2) as required by the precompile.

## License

MIT
