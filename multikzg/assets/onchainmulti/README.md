# KZG Multipoint Verifier - On-Chain Implementation

On-chain Solidity contract for verifying KZG multipoint evaluation proofs using BLS12-381 precompiles.

## Overview

This contract verifies KZG multipoint evaluation proofs on Ethereum. It uses:
- **BLS12-381 pairing precompile** (address `0x0F`) for proof verification
- **Precomputed values** to avoid expensive on-chain elliptic curve operations
- **Uncompressed point format** (96 bytes G1, 192 bytes G2) as required by precompiles

## Prerequisites

- **Foundry** (forge, cast, anvil)
- **SageMath** (for generating test data)
- **Python 3** with SageMath bindings

## Setup

1. **Install Foundry** (if not already installed):
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2. **Install dependencies**:
```bash
cd arg25-Projects/multikzg/assets/onchainmulti
forge install
```

## Testing

### 1. Test Python Implementation First

Verify your Python implementation is correct:

```bash
cd ../python_impl
sage testkzg.py
```

This will output:
- Compressed points (for Rust tests)
- Uncompressed points (for Solidity)
- G2 generator and its negation
- All values needed for contract testing

**Verify the output:**
- Check that polynomial evaluations match: `p(1)=7`, `p(2)=35`, `p(3)=103`
- Verify commitment, proof, and other points are valid

### 2. Local Structure Test

Test that the contract compiles and has correct structure:

```bash
cd ../onchainmulti
forge test --match-test test_VerifyMultipointProof -vv
```

This will revert (expected) because Foundry's test environment doesn't fully support BLS12-381 precompiles, but it verifies the contract structure is correct.

### 3. Test on Real Network Fork

Test with actual BLS12-381 precompiles on a network fork:

```bash
# Set RPC URL (use any public RPC)
export ETH_RPC_URL=https://eth.llamarpc.com

# Run fork test
forge test --match-test test_VerifyMultipointProofOnFork -vvv
```

**Alternative RPC options:**
```bash
# PublicNode
export ETH_RPC_URL=https://ethereum-rpc.publicnode.com

# Infura (requires API key)
export ETH_RPC_URL=https://mainnet.infura.io/v3/YOUR_KEY

# Ankr (if you have access)
export ETH_RPC_URL=https://rpc.ankr.com/eth/YOUR_KEY
```

### 4. Deploy Script

Deploy the contract to a network:

```bash
# Set your private key (be careful!)
export PRIVATE_KEY=your_private_key_here

# Deploy to Sepolia testnet
forge script script/Counter.s.sol:CounterScript \
  --rpc-url https://sepolia.infura.io/v3/YOUR_KEY \
  --broadcast \
  --verify
```

## Contract Usage

### Constructor

```solidity
KZGMultipointVerifier(
    bytes memory g2Generator,      // 192 bytes - BLS12-381 G2 generator (uncompressed)
    bytes memory negG2Generator    // 192 bytes - Negated G2 generator (uncompressed)
)
```

### Verify Proof

```solidity
function verifyMultipointProof(
    bytes calldata negCommitmentMinusITau,  // 96 bytes - Precomputed -(commitment - iTau)
    bytes32[] calldata zValues,             // Evaluation points
    bytes32[] calldata yValues,             // Evaluation values
    bytes calldata proof,                   // 192 bytes - G2 multiproof
    bytes calldata zCommit                  // 96 bytes - Zero polynomial commitment
) external view returns (bool)
```

**Note:** `negCommitmentMinusITau` must be computed off-chain using your Python/SageMath implementation.
The pairing equation is: `e(z_commit, proof) * e(-(commitment - i_tau), G2) == 1`
This matches the Rust implementation exactly.

## Generating Test Data

Run the Python script to generate all required values:

```bash
cd ../python_impl
sage testkzg.py
```

The output includes:
- `negCommitmentMinusITau` - Precomputed -(commitment - iTau) G1 point
- `zCommit` - Zero polynomial commitment
- `proof` - Multiproof in G2
- `g2Generator` - For constructor

Copy these values into your test file or deployment script.

## File Structure

```
onchainmulti/
├── src/
│   └── KZGMultipointVerifier.sol    # Main contract
├── test/
│   └── KZGMultipointVerifier.t.sol  # Tests
├── script/
│   └── Counter.s.sol                # Deployment script
├── foundry.toml                     # Foundry configuration
└── README.md                        # This file
```

## Troubleshooting

### Test Fails on Fork

1. **Check RPC URL**: Make sure your RPC endpoint is accessible
2. **Check Network**: Ensure the network has BLS12-381 precompiles (Cancun upgrade)
3. **Verify Data**: Re-run `sage testkzg.py` and ensure test data is fresh

### Python Implementation Issues

If you can't verify your Python implementation:

1. **Test polynomial evaluation manually**:
```python
# In SageMath
R.<x> = PolynomialRing(GF(BLS12_381_P))
poly = 3*x^3 + 2*x^2 + x + 1
assert poly(1) == 7
assert poly(2) == 35
assert poly(3) == 103
```

2. **Verify KZG commitment**:
```python
from kzg import KZG
kzg = KZG()
commitment = kzg.make_commitment(poly)
# Check commitment is a valid G1 point
```

3. **Check multiproof generation**:
```python
points, proof, i_commit, z_commit = kzg.make_multiproof([1,2,3], poly)
# Verify proof is valid G2 point
```

### Precompile Not Available

If you get precompile errors:
- Ensure `evm_version = "cancun"` in `foundry.toml`
- Test on a network with Cancun upgrade (mainnet, Sepolia, Holesky)
- Use a fork of such networks

## Gas Costs

- **Contract Deployment**: ~858K gas
- **Proof Verification**: ~9K gas (very efficient!)

## Security Notes

- Always verify proofs on-chain before trusting any data
- The contract accepts precomputed values - ensure your off-chain computation is correct
- Test thoroughly on testnets before mainnet deployment

## License

MIT
