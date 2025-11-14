#!/usr/bin/env python3
"""
Helper script to decompress BLS12-381 points for Solidity tests.
Decompresses points from compressed format (48 bytes G1, 96 bytes G2) 
to uncompressed format (64 bytes G1, 128 bytes G2).
"""
import sys
sys.path.insert(0, '../python_impl')

from py_ecc.optimized_bls12_381 import uncompress_G1, uncompress_G2, FQ, FQ2
from py_ecc.bls.g2_primitives import compress_G1, compress_G2

def decompress_g1(compressed_bytes):
    """Decompress a G1 point from 48 bytes to 64 bytes (uncompressed)."""
    # py_ecc uses little-endian for compression, but we have big-endian
    # Need to reverse the bytes
    compressed_le = bytes(reversed(compressed_bytes))
    
    # Uncompress
    point = uncompress_G1(compressed_le)
    
    # Convert to uncompressed format (x, y as 32-byte big-endian)
    x = int(point[0])
    y = int(point[1])
    
    # Return as 64-byte big-endian (x || y)
    return x.to_bytes(32, 'big') + y.to_bytes(32, 'big')

def decompress_g2(compressed_bytes):
    """Decompress a G2 point from 96 bytes to 128 bytes (uncompressed)."""
    # Split into two 48-byte parts
    z1_bytes = compressed_bytes[:48]
    z2_bytes = compressed_bytes[48:]
    
    # Reverse for little-endian
    z1_le = bytes(reversed(z1_bytes))
    z2_le = bytes(reversed(z2_bytes))
    
    # Uncompress (this is more complex for G2)
    # For now, we'll use a simpler approach - just note that G2 decompression
    # requires the full compressed format handling
    
    # Actually, py_ecc's compress_G2 returns (z1, z2) where each is 48 bytes
    # We need to reconstruct the point from these
    
    # This is a placeholder - proper G2 decompression is more complex
    # For testing, you might want to use the Python script to generate
    # uncompressed points directly
    
    return compressed_bytes  # Placeholder

if __name__ == "__main__":
    # Test data from Rust/Sage
    commitment_compressed = bytes.fromhex("abf8c06464ed351a80466654d03d1f94b489a04a297a0f38c30f367cf34fef561c1e2e28969cb5e5e7fc9deee54f6dc7")
    i_tau_compressed = bytes.fromhex("9438ffa79a133d4f926871ca25433ed5841e2b58dfcbaedc01980297898dc4c33860c07c023652c07cab562655f7ba78")
    z_commit_compressed = bytes.fromhex("89935a0341bcab4e97800cc7cf78663b1d8e1a2218704189217810d32236f3c46a7d5312c80d2220bbd66da462401895")
    proof_compressed = bytes.fromhex("89380275bbc8e5dcea7dc4dd7e0550ff2ac480905396eda55062650f8d251c96eb480673937cc6d9d6a44aaa56ca66dc122915c824a0857e2ee414a3dccb23ae691ae54329781315a0c75df1c04d6d7a50a030fc866f09d516020ef82324afae")
    
    print("// Decompressed points for Solidity test")
    print("// Note: G2 decompression is complex - these are placeholders")
    print("// You may need to use the Python KZG implementation to generate uncompressed points directly")
    print()
    
    try:
        commitment_uncompressed = decompress_g1(commitment_compressed)
        print(f"bytes memory commitment = hex\"{commitment_uncompressed.hex()}\";")
    except Exception as e:
        print(f"// Error decompressing commitment: {e}")
    
    try:
        i_tau_uncompressed = decompress_g1(i_tau_compressed)
        print(f"bytes memory iTau = hex\"{i_tau_uncompressed.hex()}\";")
    except Exception as e:
        print(f"// Error decompressing iTau: {e}")
    
    try:
        z_commit_uncompressed = decompress_g1(z_commit_compressed)
        print(f"bytes memory zCommit = hex\"{z_commit_uncompressed.hex()}\";")
    except Exception as e:
        print(f"// Error decompressing zCommit: {e}")
    
    print("// G2 proof decompression requires more complex handling")
    print("// For now, use the Python script to generate uncompressed G2 points directly")

