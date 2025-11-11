#!/usr/bin/env python3
# This implementation is for counter-testing for the revm precompile
import sys
sys.path.insert(0, '.')

from kzg import KZG

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
    
    # Scalars
    z_vals = [z for z, _ in points]
    y_vals = [y for _, y in points]
    z_bytes_list = [kzg.scalar_to_bytes32(z) for z in z_vals]
    y_bytes_list = [kzg.scalar_to_bytes32(y) for y in y_vals]
    

    print(f"commitment: {commitment_bytes.hex()}")
    print(f"num_points: {len(z_bytes_list)}")
    for i, z_bytes in enumerate(z_bytes_list):
        print(f"z_values[{i}]: {z_bytes.hex()}")
    for i, y_bytes in enumerate(y_bytes_list):
        print(f"y_values[{i}]: {y_bytes.hex()}")
    print(f"i_tau: {i_tau_bytes.hex()}")
    print(f"z_commit: {z_commit_bytes.hex()}")
    print(f"proof: {proof_bytes.hex()}")

if __name__ == "__main__":
    main()

