#!/usr/bin/env python3
"""
golden_model.py

Reference (golden) software model of SPECK32/64, per the project spec:
  - word size n = 16 bits
  - block  = (x, y), two 16-bit words
  - key    = (k3, k2, k1, k0), four 16-bit words
  - rounds T = 22
  - alpha (right rotate) = 7
  - beta  (left rotate)  = 2

Round function (i = 0 .. 21):
    x_(i+1) = ( ROTR(x_i, 7) + y_i ) XOR k_i
    y_(i+1) = ROTL(y_i, 2) XOR x_(i+1)

Key schedule:
    RK[0] = k0 ,  l[0] = k1 ,  l[1] = k2 ,  l[2] = k3
    for i = 0 .. 20:
        l[i+3]  = ( ROTR(l[i], 7) + RK[i] ) XOR i
        RK[i+1] = ROTL(RK[i], 2) XOR l[i+3]

This script:
  1. Implements the model above.
  2. Self-checks it against the mandatory official test vector.
  3. Generates N random (key, plaintext, ciphertext) triples and writes
     them to speck_test_vectors.txt, which the SystemVerilog testbench
     (tb_speck32_64.sv) reads in and checks the RTL against.
"""

import random

N_WORD = 16
WORD_MASK = (1 << N_WORD) - 1
ALPHA = 7   # right rotate amount
BETA = 2    # left rotate amount
ROUNDS = 22

OUTPUT_FILE = "speck_test_vectors.txt"
NUM_RANDOM_VECTORS = 100
RANDOM_SEED = 42  # fixed seed -> reproducible regression vectors


def rotr(val: int, r: int, n: int = N_WORD) -> int:
    val &= (1 << n) - 1
    return ((val >> r) | (val << (n - r))) & ((1 << n) - 1)


def rotl(val: int, r: int, n: int = N_WORD) -> int:
    val &= (1 << n) - 1
    return ((val << r) | (val >> (n - r))) & ((1 << n) - 1)


def speck32_64_encrypt(key: int, plaintext: int) -> int:
    """
    key:       64-bit integer, {k3,k2,k1,k0} packed MSB-first
    plaintext: 32-bit integer, {x0,y0} packed MSB-first
    returns:   32-bit integer, {x,y} packed MSB-first (ciphertext)
    """
    x = (plaintext >> 16) & WORD_MASK
    y = plaintext & WORD_MASK

    k3 = (key >> 48) & WORD_MASK
    k2 = (key >> 32) & WORD_MASK
    k1 = (key >> 16) & WORD_MASK
    k0 = key & WORD_MASK

    rk = k0                # RK[0]
    l = [k1, k2, k3]       # l[0], l[1], l[2]

    for i in range(ROUNDS):
        # --- main round function, using current round key rk = RK[i] ---
        x = (rotr(x, ALPHA) + y) & WORD_MASK
        x ^= rk
        y = rotl(y, BETA) ^ x

        # --- key schedule: prepare RK[i+1] for i = 0 .. 20 ---
        if i < ROUNDS - 1:
            l_new = (rotr(l[i], ALPHA) + rk) & WORD_MASK
            l_new ^= i
            l.append(l_new)
            rk = rotl(rk, BETA) ^ l_new

    return ((x & WORD_MASK) << 16) | (y & WORD_MASK)


def self_check() -> bool:
    """Mandatory official test vector from the project spec."""
    key = 0x1918_1110_0908_0100
    plaintext = 0x6574_694c
    expected = 0xa868_42f2

    actual = speck32_64_encrypt(key, plaintext)
    ok = (actual == expected)
    status = "PASS" if ok else "FAIL"
    print(f"[{status}] official vector: key={key:016x} pt={plaintext:08x} "
          f"expected={expected:08x} actual={actual:08x}")
    return ok


def generate_random_vectors(n: int, seed: int, path: str) -> None:
    rng = random.Random(seed)
    with open(path, "w") as f:
        for _ in range(n):
            key = rng.getrandbits(64)
            pt = rng.getrandbits(32)
            ct = speck32_64_encrypt(key, pt)
            f.write(f"{key:016x} {pt:08x} {ct:08x}\n")
    print(f"Wrote {n} random test vectors to {path}")


if __name__ == "__main__":
    if not self_check():
        raise SystemExit("Golden model failed the official test vector — fix model before generating vectors")

    generate_random_vectors(NUM_RANDOM_VECTORS, RANDOM_SEED, OUTPUT_FILE)
    print("Golden model self-check PASSED. Vector file ready for RTL testbench.")
