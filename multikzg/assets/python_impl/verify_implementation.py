#!/usr/bin/env python3
"""
Verify that the Python KZG implementation is correct by testing:
1. Polynomial evaluation
2. Commitment generation
3. Multiproof generation
4. Proof verification
"""

import sys
sys.path.insert(0, '.')

from kzg import KZG, BLS12_381_P
from sage.all import ZZ, GF, PolynomialRing

def test_polynomial_evaluation():
    """Test that polynomial evaluation is correct"""
    print("=" * 60)
    print("TEST 1: Polynomial Evaluation")
    print("=" * 60)
    
    # Create polynomial: p(X) = 3*x^3 + 2*x^2 + x + 1
    R, x = PolynomialRing(GF(BLS12_381_P), 'x'), PolynomialRing(GF(BLS12_381_P), 'x').gen()
    poly = 3*x**3 + 2*x**2 + x + 1
    
    # Test evaluations
    test_points = [1, 2, 3]
    expected_values = [7, 35, 103]
    
    print(f"Polynomial: p(X) = 3*x^3 + 2*x^2 + x + 1")
    print()
    
    all_passed = True
    for z, expected in zip(test_points, expected_values):
        result = int(poly(z))
        passed = result == expected
        status = "✓ PASS" if passed else "✗ FAIL"
        print(f"  p({z}) = {result} (expected {expected}) {status}")
        if not passed:
            all_passed = False
    
    print()
    return all_passed

def test_commitment():
    """Test that commitment generation works"""
    print("=" * 60)
    print("TEST 2: Commitment Generation")
    print("=" * 60)
    
    kzg = KZG(t=128)
    R, x = kzg.polynomial_ring()
    poly = 3*x**3 + 2*x**2 + x + 1
    
    commitment = kzg.make_commitment(poly)
    commitment_bytes = kzg.compress_g1(commitment)
    
    print(f"Commitment generated: {commitment_bytes.hex()}")
    print(f"Commitment length: {len(commitment_bytes)} bytes (expected 48)")
    
    # Check commitment is on G1 curve
    is_valid = commitment.is_on_curve()
    status = "✓ PASS" if is_valid else "✗ FAIL"
    print(f"Commitment on curve: {is_valid} {status}")
    print()
    
    return is_valid and len(commitment_bytes) == 48

def test_multiproof_generation():
    """Test multiproof generation"""
    print("=" * 60)
    print("TEST 3: Multiproof Generation")
    print("=" * 60)
    
    kzg = KZG(t=128)
    R, x = kzg.polynomial_ring()
    poly = 3*x**3 + 2*x**2 + x + 1
    
    z_values = [1, 2, 3]
    points, proof_commitment, i_commit, z_commit = kzg.make_multiproof(z_values, poly)
    
    print(f"Evaluation points: {z_values}")
    print(f"Evaluations: {[int(y) for _, y in points]}")
    print()
    
    # Check all points are valid
    proof_valid = proof_commitment.is_on_curve()
    i_commit_valid = i_commit.is_on_curve()
    z_commit_valid = z_commit.is_on_curve()
    
    print(f"Proof (G2) on curve: {proof_valid} {'✓' if proof_valid else '✗'}")
    print(f"I commit (G1) on curve: {i_commit_valid} {'✓' if i_commit_valid else '✗'}")
    print(f"Z commit (G1) on curve: {z_commit_valid} {'✓' if z_commit_valid else '✗'}")
    print()
    
    # Check byte lengths
    proof_bytes = kzg.compress_g2(proof_commitment)
    i_commit_bytes = kzg.compress_g1(i_commit)
    z_commit_bytes = kzg.compress_g1(z_commit)
    
    print(f"Proof length: {len(proof_bytes)} bytes (expected 96)")
    print(f"I commit length: {len(i_commit_bytes)} bytes (expected 48)")
    print(f"Z commit length: {len(z_commit_bytes)} bytes (expected 48)")
    print()
    
    all_valid = (proof_valid and i_commit_valid and z_commit_valid and
                 len(proof_bytes) == 96 and len(i_commit_bytes) == 48 and len(z_commit_bytes) == 48)
    
    return all_valid

def test_proof_verification():
    """Test that the generated proof verifies correctly"""
    print("=" * 60)
    print("TEST 4: Proof Verification")
    print("=" * 60)
    
    kzg = KZG(t=128)
    R, x = kzg.polynomial_ring()
    poly = 3*x**3 + 2*x**2 + x + 1
    
    # Generate commitment and proof
    commitment = kzg.make_commitment(poly)
    z_values = [1, 2, 3]
    points, proof_commitment, i_commit, z_commit = kzg.make_multiproof(z_values, poly)
    
    # Verify the proof using the Rust implementation logic
    # e(z_commit, proof) * e(-(commitment - i_commit), G2) == 1
    
    commitment_minus_i = commitment - i_commit
    neg_commitment_minus_i = -commitment_minus_i
    g2 = kzg.G2
    
    # Pairing check: e(z_commit, proof) * e(neg_commitment_minus_i, g2)
    from sage.all import pairing
    pairing1 = pairing(z_commit, proof_commitment)
    pairing2 = pairing(neg_commitment_minus_i, g2)
    result = pairing1 * pairing2
    
    # Check if result is identity (1)
    is_identity = result == 1
    status = "✓ PASS" if is_identity else "✗ FAIL"
    
    print(f"Pairing 1: e(z_commit, proof)")
    print(f"Pairing 2: e(-(commitment - i_commit), G2)")
    print(f"Result: {result == 1} (should be 1) {status}")
    print()
    
    return is_identity

def main():
    print("\n" + "=" * 60)
    print("KZG Python Implementation Verification")
    print("=" * 60 + "\n")
    
    results = []
    
    # Run all tests
    results.append(("Polynomial Evaluation", test_polynomial_evaluation()))
    results.append(("Commitment Generation", test_commitment()))
    results.append(("Multiproof Generation", test_multiproof_generation()))
    results.append(("Proof Verification", test_proof_verification()))
    
    # Summary
    print("=" * 60)
    print("SUMMARY")
    print("=" * 60)
    
    all_passed = True
    for test_name, passed in results:
        status = "✓ PASS" if passed else "✗ FAIL"
        print(f"{test_name}: {status}")
        if not passed:
            all_passed = False
    
    print()
    if all_passed:
        print("🎉 All tests passed! Your Python implementation is correct.")
    else:
        print("❌ Some tests failed. Please review the output above.")
    
    return 0 if all_passed else 1

if __name__ == "__main__":
    sys.exit(main())

