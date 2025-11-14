#!/usr/bin/env python3
# This implementation is for counter-testing for the revm precompile
import sys
sys.path.insert(0, '.')

from kzg import KZG, BLS12_381_P
from sage.all import ZZ

def main():
    # Initialize KZG
    kzg = KZG(t=128)
    
    # Create test polynomial: p(X) = 3*x^3 + 2*x^2 + x + 1
    R, x = kzg.polynomial_ring()
    poly = 3*x**3 + 2*x**2 + x + 1
    
    # Generate commitment
    commitment = kzg.make_commitment(poly)
    commitment_bytes = kzg.compress_g1(commitment)
    
    # Generate multiproof for evaluation points [1, 2, 3]
    z_values = [1, 2, 3]
    points, proof_commitment, i_commit, z_commit = kzg.make_multiproof(z_values, poly)
    
    # Compress all points
    proof_bytes = kzg.compress_g2(proof_commitment)
    i_tau_bytes = kzg.compress_g1(i_commit)
    z_commit_bytes = kzg.compress_g1(z_commit)
    
    # Also get uncompressed points for Solidity contract
    # BLS12-381 field elements are 48 bytes (384 bits), not 32 bytes
    def uncompress_g1(point):
        """Convert G1 point to uncompressed format (96 bytes: x || y, each 48 bytes)"""
        x = int(ZZ(point[0]))
        y = int(ZZ(point[1]))
        # BLS12-381 field modulus is ~48 bytes, so we need 48 bytes per coordinate
        # Reduce modulo p to ensure it's in the field
        p = BLS12_381_P
        x_mod = x % p
        y_mod = y % p
        x_bytes = x_mod.to_bytes(48, 'big')
        y_bytes = y_mod.to_bytes(48, 'big')
        return x_bytes + y_bytes
    
    def uncompress_g2(point):
        """Convert G2 point to uncompressed format (192 bytes: x || y, each 96 bytes)"""
        # Use the same method as _point_to_py_ecc to extract coefficients
        x_poly, y_poly = point[0].polynomial(), point[1].polynomial()
        x_coeffs = x_poly.coefficients(sparse=False)
        y_coeffs = y_poly.coefficients(sparse=False)
        
        # Extract coefficients (pad with 0 if needed)
        x0 = int(ZZ(x_coeffs[0])) if len(x_coeffs) > 0 else 0
        x1 = int(ZZ(x_coeffs[1])) if len(x_coeffs) > 1 else 0
        y0 = int(ZZ(y_coeffs[0])) if len(y_coeffs) > 0 else 0
        y1 = int(ZZ(y_coeffs[1])) if len(y_coeffs) > 1 else 0
        
        # Convert to bytes (48 bytes per coefficient)
        # BLS12-381 field modulus is ~384 bits, so we need 48 bytes
        def to_bytes48(val):
            """Convert integer to 48-byte big-endian representation"""
            val_int = int(val)
            # Get the field modulus for BLS12-381
            p = BLS12_381_P
            # Reduce modulo p to ensure it's in the field
            val_mod = val_int % p
            return val_mod.to_bytes(48, 'big')
        
        x0_bytes = to_bytes48(x0)
        x1_bytes = to_bytes48(x1)
        y0_bytes = to_bytes48(y0)
        y1_bytes = to_bytes48(y1)
        
        return x0_bytes + x1_bytes + y0_bytes + y1_bytes
    
    commitment_uncompressed = uncompress_g1(commitment)
    i_tau_uncompressed = uncompress_g1(i_commit)
    z_commit_uncompressed = uncompress_g1(z_commit)
    proof_uncompressed = uncompress_g2(proof_commitment)
    
    # Compute -(commitment - iTau) off-chain (to avoid needing G1 negation in Solidity)
    # Following Rust implementation: we negate the G1 point, not the G2 generator
    commitment_minus_i_tau = commitment - i_commit
    neg_commitment_minus_i_tau = -commitment_minus_i_tau
    neg_commitment_minus_i_tau_uncompressed = uncompress_g1(neg_commitment_minus_i_tau)
    
    # Scalars
    z_vals = [z for z, _ in points]
    y_vals = [y for _, y in points]
    z_bytes_list = [kzg.scalar_to_bytes32(z) for z in z_vals]
    y_bytes_list = [kzg.scalar_to_bytes32(y) for y in y_vals]
    

    print("=== Compressed points (for Rust) ===")
    print(f"commitment: {commitment_bytes.hex()}")
    print(f"num_points: {len(z_bytes_list)}")
    for i, z_bytes in enumerate(z_bytes_list):
        print(f"z_values[{i}]: {z_bytes.hex()}")
    for i, y_bytes in enumerate(y_bytes_list):
        print(f"y_values[{i}]: {y_bytes.hex()}")
    print(f"i_tau: {i_tau_bytes.hex()}")
    print(f"z_commit: {z_commit_bytes.hex()}")
    print(f"proof: {proof_bytes.hex()}")
    
    print("\n=== Uncompressed points (for Solidity) ===")
    print(f"commitment_uncompressed: {commitment_uncompressed.hex()}")
    print(f"i_tau_uncompressed: {i_tau_uncompressed.hex()}")
    print(f"z_commit_uncompressed: {z_commit_uncompressed.hex()}")
    print(f"proof_uncompressed: {proof_uncompressed.hex()}")
    
    # Get G2 generator in uncompressed format
    g2_generator = kzg.G2
    g2_generator_uncompressed = uncompress_g2(g2_generator)
    
    print("\n=== Solidity test format ===")
    print(f"bytes memory negCommitmentMinusITau = hex\"{neg_commitment_minus_i_tau_uncompressed.hex()}\";")
    print(f"bytes memory zCommit = hex\"{z_commit_uncompressed.hex()}\";")
    print(f"bytes memory proof = hex\"{proof_uncompressed.hex()}\";")
    print(f"\n// G2 Generator (for contract constructor)")
    print(f"bytes memory g2Generator = hex\"{g2_generator_uncompressed.hex()}\";")
    print(f"verifier = new KZGMultipointVerifier(g2Generator);")

if __name__ == "__main__":
    main()

