from sage.all import *
from py_ecc.bls.g2_primitives import compress_G1, compress_G2
from py_ecc.optimized_bls12_381 import FQ, FQ2, G1, G2

# This implementation is for counter-testing for the revm precompile

# BLS12-381 curve parameters (This are public)
BLS12_381_P = 0x1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab
BLS12_381_R = 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001
# This was taken from https://github.com/bluealloy/revm/blob/8a784a733c409b3c86782eb8b7bcd907286c5069/crates/precompile/src/bls12_381_const.rs#L187
TRUSTED_SETUP_TAU_G2_BYTES = bytes.fromhex(
    "b5bfd7dd8cdeb128843bc287230af38926187075cbfbefa81009a2ce615ac53d2914e5870cb452d2afaaab24f3499f72185cbfee53492714734429b7b38608e23926c911cceceac9a36851477ba4c60b087041de621000edc98edada20c1def2"
)

# Extract BLS12-381 generators from py_ecc
G1_GEN = (G1[0].n, G1[1].n)  # G1 generator (x, y) as integers
G2_GEN = (G2[0].coeffs, G2[1].coeffs)  # G2 generator: (x_coeffs, y_coeffs) where each is (c0, c1)

class KZG:
    def __init__(self, t=128, fixed_tau_for_testing=None):
        self.Fp, self.Fr = GF(BLS12_381_P), GF(BLS12_381_R)
        self.E1 = EllipticCurve(self.Fp, [0, 4])
        self.G1 = self.E1(*G1_GEN)
        
        self.Fp2 = GF(BLS12_381_P**2, modulus=PolynomialRing(self.Fp, 'x').gen()**2 + 1, name='i')
        i = self.Fp2.gen()
        self.E2 = EllipticCurve(self.Fp2, [0, 4*(1+i)])
        self.G2 = self.E2(self.Fp2(list(G2_GEN[0])), self.Fp2(list(G2_GEN[1])))
        
        self.t = ZZ(t)
        tau = self.Fr(fixed_tau_for_testing or 1234567890123456789012345678901234567890)
        
        # Generate SRS for G1 and G2
        def gen_srs(gen, group):
            srs, power = [], self.Fr(1)
            for _ in range(self.t + 1):
                srs.append(ZZ(power) * gen)
                power *= tau
            return srs
        
        self.PP_G1, self.PP_G2 = gen_srs(self.G1, self.E1), gen_srs(self.G2, self.E2)
    
    def polynomial_ring(self, var="x"):
        return PolynomialRing(self.Fr, var).objgen()
    
    def _check_poly(self, poly):
        if poly.degree() > self.t:
            raise ValueError(f"Polynomial degree {poly.degree()} > max {self.t}")
        if poly.base_ring() != self.Fr:
            raise ValueError("Polynomial must be over scalar field Fr")
    
    def _make_commitment(self, poly, pp):
        self._check_poly(poly)
        coefs = poly.coefficients(sparse=False)
        return sum(ZZ(c) * p for c, p in zip(coefs, pp[:len(coefs)]) if c != 0) if coefs else pp[0] * 0
    
    def make_commitment(self, poly):
        return self._make_commitment(poly, self.PP_G1)
    
    def make_commitment_g2(self, poly):
        return self._make_commitment(poly, self.PP_G2)
    
    def make_multiproof(self, zs, poly):
        self._check_poly(poly)
        R, x = self.polynomial_ring()
        zs = [self.Fr(z) for z in zs]
        points = [(z, poly(z)) for z in zs]
        
        I_poly = R.lagrange_polynomial(points)
        Z_poly = prod(x - z for z, _ in points)
        q_poly, rem = (poly - I_poly).quo_rem(Z_poly)
        
        if not rem.is_zero():
            raise ValueError("Z(X) does not divide p(X) - I(X)")
        if q_poly.is_zero():
            raise ValueError(f"Quotient is zero: degree {poly.degree()} < {len(zs)} points")
        
        return points, self.make_commitment_g2(q_poly), self.make_commitment(I_poly), self.make_commitment(Z_poly)
    
    def verify_multiproof(self, *args):
        return True  # Verification done in Rust
    
    def _point_to_py_ecc(self, point, is_g2=False):
        if point.is_zero():
            return None
        if is_g2:
            x_poly, y_poly = point[0].polynomial(), point[1].polynomial()
            x_coeffs = x_poly.coefficients(sparse=False)
            y_coeffs = y_poly.coefficients(sparse=False)
            return (FQ2([int(ZZ(x_coeffs[i])) if i < len(x_coeffs) else 0 for i in range(2)]),
                    FQ2([int(ZZ(y_coeffs[i])) if i < len(y_coeffs) else 0 for i in range(2)]),
                    FQ2([1, 0]))
        return (FQ(int(ZZ(point[0]))), FQ(int(ZZ(point[1]))), FQ(1))
    
    def compress_g1(self, point):
        compressed = compress_G1(self._point_to_py_ecc(point))
        return compressed.to_bytes(48, 'big')
    
    def compress_g2(self, point):
        z1, z2 = compress_G2(self._point_to_py_ecc(point, is_g2=True))
        return z1.to_bytes(48, 'big') + z2.to_bytes(48, 'big')
    
    def scalar_to_bytes32(self, val):
        return int(ZZ(val)).to_bytes(32, 'big')