/*
 * Copyright 2024 Benjamin Edgington
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "eip4844/eip4844.h"
#include "common/alloc.h"
#include "common/ec.h"
#include "common/fr.h"
#include "common/lincomb.h"
#include "common/ret.h"
#include "common/utils.h"
#include "setup/settings.h"

#include <assert.h> /* For assert */
#include <stdlib.h> /* For NULL */
#include <string.h> /* For memcpy & strlen */

////////////////////////////////////////////////////////////////////////////////////////////////////
// Macros
////////////////////////////////////////////////////////////////////////////////////////////////////

/** Length of the domain string. */
#define DOMAIN_STR_LENGTH 16

/* Input size to the Fiat-Shamir challenge computation. */
#define CHALLENGE_INPUT_SIZE (DOMAIN_STR_LENGTH + 16 + BYTES_PER_BLOB + BYTES_PER_COMMITMENT)

////////////////////////////////////////////////////////////////////////////////////////////////////
// Constants
////////////////////////////////////////////////////////////////////////////////////////////////////

/** The domain separator for the Fiat-Shamir protocol. */
static const char *FIAT_SHAMIR_PROTOCOL_DOMAIN = "FSBLOBVERIFY_V1_";

/** The domain separator for verify_blob_kzg_proof's random challenge. */
static const char *RANDOM_CHALLENGE_DOMAIN_VERIFY_BLOB_KZG_PROOF_BATCH = "RCKZGBATCH___V1_";

////////////////////////////////////////////////////////////////////////////////////////////////////
// Helper Functions
////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Test whether the operand is zero in the finite field.
 *
 * @param[in]   fr  The field element to be checked
 *
 * @retval  true    The element is zero
 * @retval  false   The element is not zero
 */
static bool fr_is_zero(const fr_t *fr) {
    uint64_t a[4];
    blst_uint64_from_fr(a, fr);
    return a[0] == 0 && a[1] == 0 && a[2] == 0 && a[3] == 0;
}

/**
 * Montgomery batch inversion in finite field.
 *
 * @param[out]  out The inverses of `a`, length `len`
 * @param[in]   a   A vector of field elements, length `len`
 * @param[in]   len The number of field elements
 *
 * @remark This function only supports len > 0.
 * @remark This function does NOT support in-place computation.
 * @remark Return C_KZG_BADARGS if a zero is found in the input. In this case,
 *         the `out` output array has already been mutated.
 */
static C_KZG_RET fr_batch_inv(fr_t *out, const fr_t *a, int len) {
    int i;

    assert(len > 0);
    assert(a != out);

    fr_t accumulator = FR_ONE;

    for (i = 0; i < len; i++) {
        out[i] = accumulator;
        fr_mul(&accumulator, &accumulator, &a[i]);
    }

    /* Bail on any zero input */
    if (fr_is_zero(&accumulator)) {
        return C_KZG_BADARGS;
    }

    fr_inv(&accumulator, &accumulator);

    for (i = len - 1; i >= 0; i--) {
        fr_mul(&out[i], &out[i], &accumulator);
        fr_mul(&accumulator, &accumulator, &a[i]);
    }

    return C_KZG_OK;
}

/**
 * Multiply a G2 group element by a field element.
 *
 * @param[out]  out The result, `a * b`
 * @param[in]   a   The G2 group element
 * @param[in]   b   The multiplier
 */
static void g2_mul(g2_t *out, const g2_t *a, const fr_t *b) {
    blst_scalar s;
    blst_scalar_from_fr(&s, b);
    blst_p2_mult(out, a, s.b, BITS_PER_FIELD_ELEMENT);
}

/**
 * Subtraction of G2 group elements.
 *
 * @param[out]  out The result, `a - b`
 * @param[in]   a   A G2 group element
 * @param[in]   b   The G2 group element to be subtracted
 */
static void g2_sub(g2_t *out, const g2_t *a, const g2_t *b) {
    g2_t bneg = *b;
    blst_p2_cneg(&bneg, true);
    blst_p2_add_or_double(out, a, &bneg);
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// BLS12-381 Helper Functions
////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Return the Fiat-Shamir challenge required to verify `blob` and `commitment`.
 *
 * @param[out]  eval_challenge_out  The evaluation challenge
 * @param[in]   blob                A blob
 * @param[in]   commitment          A commitment
 *
 * @remark This function should compute challenges even if `n == 0`.
 */
void compute_challenge(fr_t *eval_challenge_out, const Blob *blob, const g1_t *commitment) {
    Bytes32 eval_challenge;
    uint8_t bytes[CHALLENGE_INPUT_SIZE];

    /* Pointer tracking `bytes` for writing on top of it */
    uint8_t *offset = bytes;

    /* Copy domain separator */
    memcpy(offset, FIAT_SHAMIR_PROTOCOL_DOMAIN, DOMAIN_STR_LENGTH);
    offset += DOMAIN_STR_LENGTH;

    /* Copy polynomial degree (16-bytes, big-endian) */
    bytes_from_uint64(offset, 0);
    offset += sizeof(uint64_t);
    bytes_from_uint64(offset, FIELD_ELEMENTS_PER_BLOB);
    offset += sizeof(uint64_t);

    /* Copy blob */
    memcpy(offset, blob->bytes, BYTES_PER_BLOB);
    offset += BYTES_PER_BLOB;

    /* Copy commitment */
    bytes_from_g1((Bytes48 *)offset, commitment);
    offset += BYTES_PER_COMMITMENT;

    /* Make sure we wrote the entire buffer */
    assert(offset == bytes + CHALLENGE_INPUT_SIZE);

    /* Now let's create the challenge! */
    blst_sha256(eval_challenge.bytes, bytes, CHALLENGE_INPUT_SIZE);
    hash_to_bls_field(eval_challenge_out, &eval_challenge);
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// Polynomials Functions
////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Evaluate a polynomial in evaluation form at a given point.
 *
 * @param[out]  out     The result of the evaluation
 * @param[in]   poly    The polynomial in evaluation form
 * @param[in]   x       The point to evaluate the polynomial at
 * @param[in]   s       The trusted setup
 */
static C_KZG_RET evaluate_polynomial_in_evaluation_form(
    fr_t *out, const fr_t *poly, const fr_t *x, const KZGSettings *s
) {
    C_KZG_RET ret;
    fr_t tmp;
    fr_t *inverses_in = NULL;
    fr_t *inverses = NULL;
    uint64_t i;
    const fr_t *brp_roots_of_unity = s->brp_roots_of_unity;

    ret = new_fr_array(&inverses_in, FIELD_ELEMENTS_PER_BLOB);
    if (ret != C_KZG_OK) goto out;
    ret = new_fr_array(&inverses, FIELD_ELEMENTS_PER_BLOB);
    if (ret != C_KZG_OK) goto out;

    for (i = 0; i < FIELD_ELEMENTS_PER_BLOB; i++) {
        /*
         * If the point to evaluate at is one of the evaluation points by which the polynomial is
         * given, we can just return the result directly.  Note that special-casing this is
         * necessary, as the formula below would divide by zero otherwise.
         */
        if (fr_equal(x, &brp_roots_of_unity[i])) {
            *out = poly[i];
            ret = C_KZG_OK;
            goto out;
        }
        fr_sub(&inverses_in[i], x, &brp_roots_of_unity[i]);
    }

    ret = fr_batch_inv(inverses, inverses_in, FIELD_ELEMENTS_PER_BLOB);
    if (ret != C_KZG_OK) goto out;

    *out = FR_ZERO;
    for (i = 0; i < FIELD_ELEMENTS_PER_BLOB; i++) {
        fr_mul(&tmp, &inverses[i], &brp_roots_of_unity[i]);
        fr_mul(&tmp, &tmp, &poly[i]);
        fr_add(out, out, &tmp);
    }
    fr_from_uint64(&tmp, FIELD_ELEMENTS_PER_BLOB);
    fr_div(out, out, &tmp);
    fr_pow(&tmp, x, FIELD_ELEMENTS_PER_BLOB);
    fr_sub(&tmp, &tmp, &FR_ONE);
    fr_mul(out, out, &tmp);

out:
    c_kzg_free(inverses_in);
    c_kzg_free(inverses);
    return ret;
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// Functions for EIP-4844
////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Compute a KZG commitment from a polynomial.
 *
 * @param[out]  out     The resulting commitment
 * @param[in]   poly    The polynomial to commit to
 * @param[in]   s       The trusted setup
 */
static C_KZG_RET poly_to_kzg_commitment(g1_t *out, const fr_t *poly, const KZGSettings *s) {
    return g1_lincomb_fast(out, s->g1_values_lagrange_brp, poly, FIELD_ELEMENTS_PER_BLOB);
}

/**
 * Convert a blob to a KZG commitment.
 *
 * @param[out]  out     The resulting commitment
 * @param[in]   blob    The blob representing the polynomial to be committed to
 * @param[in]   s       The trusted setup
 */
C_KZG_RET blob_to_kzg_commitment(KZGCommitment *out, const Blob *blob, const KZGSettings *s) {
    C_KZG_RET ret;
    fr_t *poly = NULL;
    g1_t commitment;

    ret = new_fr_array(&poly, FIELD_ELEMENTS_PER_BLOB);
    if (ret != C_KZG_OK) goto out;
    ret = blob_to_polynomial(poly, blob);
    if (ret != C_KZG_OK) goto out;
    ret = poly_to_kzg_commitment(&commitment, poly, s);
    if (ret != C_KZG_OK) goto out;
    bytes_from_g1(out, &commitment);

out:
    c_kzg_free(poly);
    return ret;
}

/* Forward function declaration */
static C_KZG_RET verify_kzg_proof_impl(
    bool *ok,
    const g1_t *commitment,
    const fr_t *z,
    const fr_t *y,
    const g1_t *proof,
    const KZGSettings *s
);

/**
 * Verify a KZG proof claiming that `p(z) == y`.
 *
 * @param[out]  ok          True if the proofs are valid, otherwise false
 * @param[in]   commitment  The KZG commitment corresponding to poly p(x)
 * @param[in]   z           The evaluation point
 * @param[in]   y           The claimed evaluation result
 * @param[in]   kzg_proof   The KZG proof
 * @param[in]   s           The trusted setup
 */
C_KZG_RET verify_kzg_proof(
    bool *ok,
    const Bytes48 *commitment_bytes,
    const Bytes32 *z_bytes,
    const Bytes32 *y_bytes,
    const Bytes48 *proof_bytes,
    const KZGSettings *s
) {
    C_KZG_RET ret;
    fr_t z_fr, y_fr;
    g1_t commitment_g1, proof_g1;

    *ok = false;

    /* Convert untrusted inputs to trusted inputs */
    ret = bytes_to_kzg_commitment(&commitment_g1, commitment_bytes);
    if (ret != C_KZG_OK) return ret;
    ret = bytes_to_bls_field(&z_fr, z_bytes);
    if (ret != C_KZG_OK) return ret;
    ret = bytes_to_bls_field(&y_fr, y_bytes);
    if (ret != C_KZG_OK) return ret;
    ret = bytes_to_kzg_proof(&proof_g1, proof_bytes);
    if (ret != C_KZG_OK) return ret;

    /* Call helper to do pairings check */
    return verify_kzg_proof_impl(ok, &commitment_g1, &z_fr, &y_fr, &proof_g1, s);
}

/**
 * Helper function: Verify KZG proof claiming that `p(z) == y`.
 *
 * Given a `commitment` to a polynomial, a `proof` for `z`, and the claimed value `y` at `z`, verify
 * the claim.
 *
 * @param[out]  ok          True if the proof is valid, otherwise false
 * @param[in]   commitment  The commitment to a polynomial
 * @param[in]   z           The point at which the proof is to be opened
 * @param[in]   y           The claimed value of the polynomial at `z`
 * @param[in]   proof       A proof of the value of the polynomial at `z`
 * @param[in]   s           The trusted setup
 */
static C_KZG_RET verify_kzg_proof_impl(
    bool *ok,
    const g1_t *commitment,
    const fr_t *z,
    const fr_t *y,
    const g1_t *proof,
    const KZGSettings *s
) {
    g2_t x_g2, X_minus_z;
    g1_t y_g1, P_minus_y;

    /* Calculate: X_minus_z */
    g2_mul(&x_g2, blst_p2_generator(), z);
    g2_sub(&X_minus_z, &s->g2_values_monomial[1], &x_g2);

    /* Calculate: P_minus_y */
    g1_mul(&y_g1, blst_p1_generator(), y);
    g1_sub(&P_minus_y, commitment, &y_g1);

    /* Verify: P - y = Q * (X - z) */
    *ok = pairings_verify(&P_minus_y, blst_p2_generator(), proof, &X_minus_z);

    return C_KZG_OK;
}

/* Forward function declaration */
static C_KZG_RET compute_kzg_proof_impl(
    KZGProof *proof_out, fr_t *y_out, const fr_t *poly, const fr_t *z, const KZGSettings *s
);

/**
 * Compute KZG proof for polynomial in Lagrange form at position z.
 *
 * @param[out]  proof_out   The combined proof as a single G1 element
 * @param[out]  y_out       The evaluation of the polynomial at the evaluation point z
 * @param[in]   blob        The blob (polynomial) to generate a proof for
 * @param[in]   z           The generator z-value for the evaluation points
 * @param[in]   s           The trusted setup
 */
C_KZG_RET compute_kzg_proof(
    KZGProof *proof_out,
    Bytes32 *y_out,
    const Blob *blob,
    const Bytes32 *z_bytes,
    const KZGSettings *s
) {
    C_KZG_RET ret;
    fr_t *poly = NULL;
    fr_t frz, fry;

    ret = new_fr_array(&poly, FIELD_ELEMENTS_PER_BLOB);
    if (ret != C_KZG_OK) goto out;
    ret = blob_to_polynomial(poly, blob);
    if (ret != C_KZG_OK) goto out;
    ret = bytes_to_bls_field(&frz, z_bytes);
    if (ret != C_KZG_OK) goto out;
    ret = compute_kzg_proof_impl(proof_out, &fry, poly, &frz, s);
    if (ret != C_KZG_OK) goto out;
    bytes_from_bls_field(y_out, &fry);

out:
    c_kzg_free(poly);
    return ret;
}

/**
 * Helper function for compute_kzg_proof() and compute_blob_kzg_proof().
 *
 * @param[out]  proof_out   The combined proof as a single G1 element
 * @param[out]  y_out       The evaluation of the polynomial at the evaluation point z
 * @param[in]   poly        The polynomial in Lagrange form
 * @param[in]   z           The evaluation point
 * @param[in]   s           The trusted setup
 */
static C_KZG_RET compute_kzg_proof_impl(
    KZGProof *proof_out, fr_t *y_out, const fr_t *poly, const fr_t *z, const KZGSettings *s
) {
    C_KZG_RET ret;
    fr_t *inverses_in = NULL;
    fr_t *inverses = NULL;
    fr_t *q_poly = NULL;

    ret = evaluate_polynomial_in_evaluation_form(y_out, poly, z, s);
    if (ret != C_KZG_OK) goto out;

    fr_t tmp;
    const fr_t *brp_roots_of_unity = s->brp_roots_of_unity;
    uint64_t i;
    /* m != 0 indicates that the evaluation point z equals root_of_unity[m-1] */
    uint64_t m = 0;

    ret = new_fr_array(&inverses_in, FIELD_ELEMENTS_PER_BLOB);
    if (ret != C_KZG_OK) goto out;
    ret = new_fr_array(&inverses, FIELD_ELEMENTS_PER_BLOB);
    if (ret != C_KZG_OK) goto out;
    ret = new_fr_array(&q_poly, FIELD_ELEMENTS_PER_BLOB);
    if (ret != C_KZG_OK) goto out;

    for (i = 0; i < FIELD_ELEMENTS_PER_BLOB; i++) {
        if (fr_equal(z, &brp_roots_of_unity[i])) {
            /* We are asked to compute a KZG proof inside the domain */
            m = i + 1;
            inverses_in[i] = FR_ONE;
            continue;
        }
        // (p_i - y) / (ω_i - z)
        fr_sub(&q_poly[i], &poly[i], y_out);
        fr_sub(&inverses_in[i], &brp_roots_of_unity[i], z);
    }

    ret = fr_batch_inv(inverses, inverses_in, FIELD_ELEMENTS_PER_BLOB);
    if (ret != C_KZG_OK) goto out;

    for (i = 0; i < FIELD_ELEMENTS_PER_BLOB; i++) {
        fr_mul(&q_poly[i], &q_poly[i], &inverses[i]);
    }

    if (m != 0) { /* ω_{m-1} == z */
        q_poly[--m] = FR_ZERO;
        for (i = 0; i < FIELD_ELEMENTS_PER_BLOB; i++) {
            if (i == m) continue;
            /* Build denominator: z * (z - ω_i) */
            fr_sub(&tmp, z, &brp_roots_of_unity[i]);
            fr_mul(&inverses_in[i], &tmp, z);
        }

        ret = fr_batch_inv(inverses, inverses_in, FIELD_ELEMENTS_PER_BLOB);
        if (ret != C_KZG_OK) goto out;

        for (i = 0; i < FIELD_ELEMENTS_PER_BLOB; i++) {
            if (i == m) continue;
            /* Build numerator: ω_i * (p_i - y) */
            fr_sub(&tmp, &poly[i], y_out);
            fr_mul(&tmp, &tmp, &brp_roots_of_unity[i]);
            /* Do the division: (p_i - y) * ω_i / (z * (z - ω_i)) */
            fr_mul(&tmp, &tmp, &inverses[i]);
            fr_add(&q_poly[m], &q_poly[m], &tmp);
        }
    }

    g1_t out_g1;
    ret = g1_lincomb_fast(&out_g1, s->g1_values_lagrange_brp, q_poly, FIELD_ELEMENTS_PER_BLOB);
    if (ret != C_KZG_OK) goto out;

    bytes_from_g1(proof_out, &out_g1);

out:
    c_kzg_free(inverses_in);
    c_kzg_free(inverses);
    c_kzg_free(q_poly);
    return ret;
}

/**
 * Given a blob and a commitment, return the KZG proof that is used to verify it against the
 * commitment. This function does not verify that the commitment is correct with respect to the
 * blob.
 *
 * @param[out]  out                 The resulting proof
 * @param[in]   blob                A blob
 * @param[in]   commitment_bytes    Commitment to verify
 * @param[in]   s                   The trusted setup
 */
C_KZG_RET compute_blob_kzg_proof(
    KZGProof *out, const Blob *blob, const Bytes48 *commitment_bytes, const KZGSettings *s
) {
    C_KZG_RET ret;
    fr_t *poly = NULL;
    g1_t commitment_g1;
    fr_t evaluation_challenge_fr;
    fr_t y;

    /* Allocate space for our polynomial */
    ret = new_fr_array(&poly, FIELD_ELEMENTS_PER_BLOB);
    if (ret != C_KZG_OK) goto out;

    /* Do conversions first to fail fast, compute_challenge is expensive */
    ret = bytes_to_kzg_commitment(&commitment_g1, commitment_bytes);
    if (ret != C_KZG_OK) goto out;
    ret = blob_to_polynomial(poly, blob);
    if (ret != C_KZG_OK) goto out;

    /* Compute the challenge for the given blob/commitment */
    compute_challenge(&evaluation_challenge_fr, blob, &commitment_g1);

    /* Call helper function to compute proof and y */
    ret = compute_kzg_proof_impl(out, &y, poly, &evaluation_challenge_fr, s);
    if (ret != C_KZG_OK) goto out;

out:
    c_kzg_free(poly);
    return ret;
}

/**
 * Given a blob and its proof, verify that it corresponds to the provided commitment.
 *
 * @param[out]  ok                  True if the proofs are valid, otherwise false
 * @param[in]   blob                Blob to verify
 * @param[in]   commitment_bytes    Commitment to verify
 * @param[in]   proof_bytes         Proof used for verification
 * @param[in]   s                   The trusted setup
 */
C_KZG_RET verify_blob_kzg_proof(
    bool *ok,
    const Blob *blob,
    const Bytes48 *commitment_bytes,
    const Bytes48 *proof_bytes,
    const KZGSettings *s
) {
    C_KZG_RET ret;
    fr_t *poly = NULL;
    fr_t evaluation_challenge_fr, y_fr;
    g1_t commitment_g1, proof_g1;

    *ok = false;

    /* Allocate space for our polynomial */
    ret = new_fr_array(&poly, FIELD_ELEMENTS_PER_BLOB);
    if (ret != C_KZG_OK) goto out;

    /* Do conversions first to fail fast, compute_challenge is expensive */
    ret = bytes_to_kzg_commitment(&commitment_g1, commitment_bytes);
    if (ret != C_KZG_OK) goto out;
    ret = blob_to_polynomial(poly, blob);
    if (ret != C_KZG_OK) goto out;
    ret = bytes_to_kzg_proof(&proof_g1, proof_bytes);
    if (ret != C_KZG_OK) goto out;

    /* Compute challenge for the blob/commitment */
    compute_challenge(&evaluation_challenge_fr, blob, &commitment_g1);

    /* Evaluate challenge to get y */
    ret = evaluate_polynomial_in_evaluation_form(&y_fr, poly, &evaluation_challenge_fr, s);
    if (ret != C_KZG_OK) goto out;

    /* Call helper to do pairings check */
    ret = verify_kzg_proof_impl(ok, &commitment_g1, &evaluation_challenge_fr, &y_fr, &proof_g1, s);
    if (ret != C_KZG_OK) goto out;

out:
    c_kzg_free(poly);
    return ret;
}

/**
 * Compute random linear combination challenge scalars for batch verification.
 *
 * @param[out]  r_powers_out    The output challenges
 * @param[in]   commitments_g1  The input commitments
 * @param[in]   zs_fr           The input evaluation points
 * @param[in]   ys_fr           The input evaluation results
 * @param[in]   proofs_g1       The input proofs
 */
static C_KZG_RET compute_r_powers_for_verify_kzg_proof_batch(
    fr_t *r_powers_out,
    const g1_t *commitments_g1,
    const fr_t *zs_fr,
    const fr_t *ys_fr,
    const g1_t *proofs_g1,
    size_t n
) {
    C_KZG_RET ret;
    uint8_t *bytes = NULL;
    blst_p1_affine *commitments_affine = NULL;
    blst_p1_affine *proofs_affine = NULL;
    Bytes32 r_bytes;
    fr_t r;

    size_t input_size = DOMAIN_STR_LENGTH + sizeof(uint64_t) + sizeof(uint64_t) +
                        (n *
                         (BYTES_PER_COMMITMENT + 2 * BYTES_PER_FIELD_ELEMENT + BYTES_PER_PROOF));
    ret = c_kzg_malloc((void **)&bytes, input_size);
    if (ret != C_KZG_OK) goto out;

    /* Allocate space for affine commitments and proofs */
    ret = c_kzg_malloc((void **)&commitments_affine, n * sizeof(blst_p1_affine));
    if (ret != C_KZG_OK) goto out;
    ret = c_kzg_malloc((void **)&proofs_affine, n * sizeof(blst_p1_affine));
    if (ret != C_KZG_OK) goto out;

    /* Batch convert commitments and proofs to affine */
    const blst_p1 *commitments_arg[2] = {commitments_g1, NULL};
    blst_p1s_to_affine(commitments_affine, commitments_arg, n);
    const blst_p1 *proofs_arg[2] = {proofs_g1, NULL};
    blst_p1s_to_affine(proofs_affine, proofs_arg, n);

    /* Pointer tracking `bytes` for writing on top of it */
    uint8_t *offset = bytes;

    /* Ensure that the domain string is the correct length */
    assert(strlen(RANDOM_CHALLENGE_DOMAIN_VERIFY_BLOB_KZG_PROOF_BATCH) == DOMAIN_STR_LENGTH);

    /* Copy domain separator */
    memcpy(offset, RANDOM_CHALLENGE_DOMAIN_VERIFY_BLOB_KZG_PROOF_BATCH, DOMAIN_STR_LENGTH);
    offset += DOMAIN_STR_LENGTH;

    /* Copy degree of the polynomial */
    bytes_from_uint64(offset, FIELD_ELEMENTS_PER_BLOB);
    offset += sizeof(uint64_t);

    /* Copy number of commitments */
    bytes_from_uint64(offset, n);
    offset += sizeof(uint64_t);

    for (size_t i = 0; i < n; i++) {
        /* Copy commitment */
        blst_p1_affine_compress(offset, &commitments_affine[i]);
        offset += BYTES_PER_COMMITMENT;

        /* Copy z */
        bytes_from_bls_field((Bytes32 *)offset, &zs_fr[i]);
        offset += BYTES_PER_FIELD_ELEMENT;

        /* Copy y */
        bytes_from_bls_field((Bytes32 *)offset, &ys_fr[i]);
        offset += BYTES_PER_FIELD_ELEMENT;

        /* Copy proof */
        blst_p1_affine_compress(offset, &proofs_affine[i]);
        offset += BYTES_PER_PROOF;
    }

    /* Now let's create the challenge! */
    blst_sha256(r_bytes.bytes, bytes, input_size);
    hash_to_bls_field(&r, &r_bytes);

    compute_powers(r_powers_out, &r, n);

    /* Make sure we wrote the entire buffer */
    assert(offset == bytes + input_size);

out:
    c_kzg_free(bytes);
    c_kzg_free(commitments_affine);
    c_kzg_free(proofs_affine);
    return ret;
}

/**
 * Helper function for verify_blob_kzg_proof_batch(): actually perform the verification.
 *
 * @param[out]  ok              True if the proofs are valid, otherwise false
 * @param[in]   commitments_g1  Array of commitments to verify
 * @param[in]   zs_fr           Array of evaluation points for the KZG proofs
 * @param[in]   ys_fr           Array of evaluation results for the KZG proofs
 * @param[in]   proofs_g1       Array of proofs used for verification
 * @param[in]   n               The number of blobs/commitments/proofs
 * @param[in]   s               The trusted setup
 *
 * @remark This function only works for `n > 0`.
 * @remark This function assumes that `n` is trusted and that all input arrays contain `n` elements.
 * `n` should be the actual size of the arrays and not read off a length field in the protocol.
 */
static C_KZG_RET verify_kzg_proof_batch(
    bool *ok,
    const g1_t *commitments_g1,
    const fr_t *zs_fr,
    const fr_t *ys_fr,
    const g1_t *proofs_g1,
    size_t n,
    const KZGSettings *s
) {
    C_KZG_RET ret;
    g1_t proof_lincomb, proof_z_lincomb, C_minus_y_lincomb, rhs_g1;
    fr_t *r_powers = NULL;
    g1_t *C_minus_y = NULL;
    fr_t *r_times_z = NULL;

    assert(n > 0);

    *ok = false;

    /* First let's allocate our arrays */
    ret = new_fr_array(&r_powers, n);
    if (ret != C_KZG_OK) goto out;
    ret = new_g1_array(&C_minus_y, n);
    if (ret != C_KZG_OK) goto out;
    ret = new_fr_array(&r_times_z, n);
    if (ret != C_KZG_OK) goto out;

    /* Compute the random lincomb challenges */
    ret = compute_r_powers_for_verify_kzg_proof_batch(
        r_powers, commitments_g1, zs_fr, ys_fr, proofs_g1, n
    );
    if (ret != C_KZG_OK) goto out;

    /* Compute \sum r^i * Proof_i */
    g1_lincomb_naive(&proof_lincomb, proofs_g1, r_powers, n);

    for (size_t i = 0; i < n; i++) {
        g1_t ys_encrypted;
        /* Get [y_i] */
        g1_mul(&ys_encrypted, blst_p1_generator(), &ys_fr[i]);
        /* Get C_i - [y_i] */
        g1_sub(&C_minus_y[i], &commitments_g1[i], &ys_encrypted);
        /* Get r^i * z_i */
        fr_mul(&r_times_z[i], &r_powers[i], &zs_fr[i]);
    }

    /* Get \sum r^i z_i Proof_i */
    g1_lincomb_naive(&proof_z_lincomb, proofs_g1, r_times_z, n);
    /* Get \sum r^i (C_i - [y_i]) */
    g1_lincomb_naive(&C_minus_y_lincomb, C_minus_y, r_powers, n);
    /* Get C_minus_y_lincomb + proof_z_lincomb */
    g1_add(&rhs_g1, &C_minus_y_lincomb, &proof_z_lincomb);

    /* Do the pairing check! */
    *ok = pairings_verify(&proof_lincomb, &s->g2_values_monomial[1], &rhs_g1, blst_p2_generator());

out:
    c_kzg_free(r_powers);
    c_kzg_free(C_minus_y);
    c_kzg_free(r_times_z);
    return ret;
}

/**
 * Given a list of blobs and blob KZG proofs, verify that they correspond to the provided
 * commitments.
 *
 * @param[out]  ok                  True if the proofs are valid, otherwise false
 * @param[in]   blobs               Array of blobs to verify
 * @param[in]   commitments_bytes   Array of commitments to verify
 * @param[in]   proofs_bytes        Array of proofs used for verification
 * @param[in]   n                   The number of blobs/commitments/proofs
 * @param[in]   s                   The trusted setup
 *
 * @remark This function accepts if called with `n==0`.
 * @remark This function assumes that `n` is trusted and that all input arrays contain `n` elements.
 * `n` should be the actual size of the arrays and not read off a length field in the protocol.
 */
C_KZG_RET verify_blob_kzg_proof_batch(
    bool *ok,
    const Blob *blobs,
    const Bytes48 *commitments_bytes,
    const Bytes48 *proofs_bytes,
    uint64_t n,
    const KZGSettings *s
) {
    C_KZG_RET ret;
    g1_t *commitments_g1 = NULL;
    g1_t *proofs_g1 = NULL;
    fr_t *evaluation_challenges_fr = NULL;
    fr_t *ys_fr = NULL;
    fr_t *poly = NULL;

    /* Exit early if we are given zero blobs */
    if (n == 0) {
        *ok = true;
        return C_KZG_OK;
    }

    /* For a single blob, just do a regular single verification */
    if (n == 1) {
        return verify_blob_kzg_proof(ok, &blobs[0], &commitments_bytes[0], &proofs_bytes[0], s);
    }

    /* We will need a bunch of arrays to store our objects... */
    ret = new_g1_array(&commitments_g1, n);
    if (ret != C_KZG_OK) goto out;
    ret = new_g1_array(&proofs_g1, n);
    if (ret != C_KZG_OK) goto out;
    ret = new_fr_array(&evaluation_challenges_fr, n);
    if (ret != C_KZG_OK) goto out;
    ret = new_fr_array(&ys_fr, n);
    if (ret != C_KZG_OK) goto out;
    ret = new_fr_array(&poly, FIELD_ELEMENTS_PER_BLOB);
    if (ret != C_KZG_OK) goto out;

    for (size_t i = 0; i < n; i++) {
        /* Convert each commitment to a g1 point */
        ret = bytes_to_kzg_commitment(&commitments_g1[i], &commitments_bytes[i]);
        if (ret != C_KZG_OK) goto out;

        /* Convert each blob from bytes to a poly */
        ret = blob_to_polynomial(poly, &blobs[i]);
        if (ret != C_KZG_OK) goto out;

        compute_challenge(&evaluation_challenges_fr[i], &blobs[i], &commitments_g1[i]);

        ret = evaluate_polynomial_in_evaluation_form(
            &ys_fr[i], poly, &evaluation_challenges_fr[i], s
        );
        if (ret != C_KZG_OK) goto out;

        ret = bytes_to_kzg_proof(&proofs_g1[i], &proofs_bytes[i]);
        if (ret != C_KZG_OK) goto out;
    }

    ret = verify_kzg_proof_batch(
        ok, commitments_g1, evaluation_challenges_fr, ys_fr, proofs_g1, n, s
    );

out:
    c_kzg_free(commitments_g1);
    c_kzg_free(proofs_g1);
    c_kzg_free(evaluation_challenges_fr);
    c_kzg_free(ys_fr);
    c_kzg_free(poly);
    return ret;
}
