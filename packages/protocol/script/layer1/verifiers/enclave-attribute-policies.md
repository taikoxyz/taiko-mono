# SGX Enclave ATTRIBUTES Policies (`setEnclaveAttributePolicy`)

This is a reference for calling
[`SecureSgxVerifier.setEnclaveAttributePolicy(bytes32 _mrEnclave, bytes16 _mask, bytes16 _expected)`](../../../contracts/layer1/verifiers/SecureSgxVerifier.sol).
It lists the **canonical ATTRIBUTES profiles** (the reusable `_mask` / `_expected` pairs) you pin an
allowlisted `MRENCLAVE` to, with the exact reason each bit is set the way it is.

> [!IMPORTANT]
> **Read this first — it corrects a common misconception.** `_mask` / `_expected` are **not** unique
> per-`MRENCLAVE`. `MRENCLAVE` is the SHA‑256 measurement of one specific enclave **build** (it
> changes every release). `_mask` / `_expected` describe the enclave's **ATTRIBUTES profile** — a
> small, security-driven posture (non-debug, 64-bit, no provisioning/launch keys, …) that is
> **identical across almost every production enclave of the same framework**. So there is no list of
> "popular `MRENCLAVE`s, each with its own mask/expected". What is reusable and worth standardizing is
> the **handful of ATTRIBUTES profiles below**. You then apply the right profile to *each*
> `MRENCLAVE` you allowlist (Raiko SGX‑reth prover build N, SGX‑geth prover build M, …).

---

## 1. How the check works

During `registerInstance`, after the universal forbidden-attribute floor, `SecureSgxVerifier` runs:

```solidity
AttributePolicy memory policy = enclaveAttributePolicy[_mrEnclave];
require(policy.mask != bytes16(0), SGX_ATTRIBUTE_POLICY_NOT_SET());   // fail closed if unpinned
require(_attributes & policy.mask == policy.expected, SGX_ATTRIBUTE_MISMATCH());
```

- `_mask` — **which** ATTRIBUTES bits are checked (`1` = checked, `0` = ignored).
- `_expected` — the **required value** of the checked bits. The quote is accepted only when
  `quoteAttributes & _mask == _expected`.

`setEnclaveAttributePolicy` rejects a policy unless **all** of these hold (see
[`SecureSgxVerifier.sol:81-105`](../../../contracts/layer1/verifiers/SecureSgxVerifier.sol)):

| Rule | Meaning |
| --- | --- |
| `_mask != 0` | A zero mask is the "unconfigured / fail-closed" sentinel, so it can't be a real policy. |
| `_expected & ~_mask == 0` | `_expected` may not assert a bit the mask does not check. |
| `_mask & FORBIDDEN == FORBIDDEN` | The mask must check **every** universally-forbidden bit. |
| `_expected & FORBIDDEN == 0` | `_expected` must require all forbidden bits to be **clear** — a per-enclave pin can never re-admit a debug/provisioning/launch enclave. |

where `FORBIDDEN = SGX_FORBIDDEN_ATTRIBUTE_MASK = 0x32000000000000000000000000000000`.

---

## 2. The ATTRIBUTES field layout (why the bytes sit where they do)

The on-chain `bytes16 attributes` is the SGX `SECS.ATTRIBUTES` field copied verbatim from the quote
(raw-quote offset `HEADER_LENGTH + 48`). It is two little-endian `uint64`s:

```
byte index:  0  1  2  3  4  5  6  7 | 8  9 10 11 12 13 14 15
field:       <------ FLAGS ------>  | <------ XFRM ------->
             (little-endian u64)    | (little-endian u64)
significance: LSB ............ MSB  | LSB ............ MSB
```

Because each half is little-endian, **byte 0 (the left-most hex pair) is the least-significant FLAGS
byte**, which holds every bit that matters for trust. **Byte 8 is the least-significant XFRM byte.**

### FLAGS, low byte (byte 0) — Intel `sgx_attributes.h`

| Bit | Value | Name | Notes |
| --- | --- | --- | --- |
| 0 | `0x01` | `INIT` | Enclave has been `EINIT`-ed. A real running enclave **always** has this set. |
| 1 | `0x02` | `DEBUG` | **FORBIDDEN.** Host can read/write enclave memory → signing key is extractable. |
| 2 | `0x04` | `MODE64BIT` | 64-bit enclave. Production Raiko/SGX‑geth enclaves are 64-bit. |
| 3 | `0x08` | reserved | Must be 0. |
| 4 | `0x10` | `PROVISION_KEY` | **FORBIDDEN.** Can derive platform-identifying provisioning keys. |
| 5 | `0x20` | `EINITTOKEN_KEY` | **FORBIDDEN.** Launch-enclave-only privilege; an app enclave must never hold it. |
| 6 | `0x40` | `CET` | Control-flow Enforcement (shadow stack / IBT). Set only if the build enables CET. |
| 7 | `0x80` | `KSS` | Key Separation & Sharing. Set only if the build enables KSS (config-id identity). |

`FORBIDDEN` low byte = `DEBUG | PROVISION_KEY | EINITTOKEN_KEY` = `0x02 | 0x10 | 0x20` = **`0x32`** —
exactly the contract's `SGX_FORBIDDEN_ATTRIBUTE_MASK`. FLAGS bytes 1–7 are reserved and must be 0.

### XFRM, low byte (byte 8) — same layout as `XCR0`

| Bit | Value | State | Notes |
| --- | --- | --- | --- |
| 0 | `0x01` | x87 | Always set. |
| 1 | `0x02` | SSE | Almost always set. |
| 2 | `0x04` | AVX | Set if AVX is in the XSAVE mask. |
| 5–7 | `0xE0` | AVX‑512 | opmask / ZMM_Hi256 / Hi16_ZMM. |

Common XFRM low bytes: `0x03` (x87+SSE, "legacy"), `0x07` (x87+SSE+AVX), `0xE7` (+AVX‑512). **XFRM
varies with the prover host's CPU and XSAVE configuration, not with enclave trust** — which is why
the default profiles below leave XFRM **unchecked** (see §4).

---

## 3. Canonical profiles (the reusable mask / expected values)

Pick **one** profile per allowlisted `MRENCLAVE`. Profile **A** is the recommended default and is the
exact pin exercised by `SecureSgxVerifierTest` (`STRICT_MASK` / `STRICT_EXPECTED`).

| # | Profile | `_mask` | `_expected` |
| --- | --- | --- | --- |
| **A** | **Strict FLAGS pin (default)** | `0xffffffffffffffff0000000000000000` | `0x05000000000000000000000000000000` |
| B | Strict FLAGS pin, **KSS** build | `0xffffffffffffffff0000000000000000` | `0x85000000000000000000000000000000` |
| C | Strict FLAGS pin, **CET** build | `0xffffffffffffffff0000000000000000` | `0x45000000000000000000000000000000` |
| D | Forbidden-floor only (bootstrap) | `0x32000000000000000000000000000000` | `0x00000000000000000000000000000000` |
| E | Strict FLAGS **+ exact XFRM** | `0xffffffffffffffffff00000000000000` | `0x05000000000000000700000000000000` |

### Profile A — Strict FLAGS pin *(recommended default)*

```
_mask     = 0xffffffffffffffff0000000000000000
_expected = 0x05000000000000000000000000000000   // INIT(0x01) | MODE64BIT(0x04) = 0x05
```

- **Mask:** checks all 8 FLAGS bytes (`0xffffffffffffffff…`), leaves XFRM unchecked (`…0000000000000000`).
- **Expected:** requires `INIT | MODE64BIT` (`0x05`) and requires **every other FLAGS bit to be 0** —
  including the forbidden floor (`DEBUG/PROVISION_KEY/EINITTOKEN_KEY`), `CET`, `KSS`, and all reserved
  bits 3 and 8–63.
- **Why these values:** an attested production enclave is initialized (`INIT`) and 64-bit
  (`MODE64BIT`); nothing else should be set. Pinning *all* FLAGS bytes (not just the floor) means an
  unexpected or reserved FLAGS bit — anything outside `0x05` — is rejected, which is the defense-in-depth
  the per-enclave pin exists to add on top of the global deny-mask. XFRM is left unchecked so provers on
  CPUs with different XSAVE/AVX feature sets all register against one policy.
- **Use for:** any standard Gramine-based Raiko SGX‑reth / SGX‑geth production build that does **not**
  enable KSS or CET. This is the right default for almost every `MRENCLAVE`.

### Profile B — Strict FLAGS pin, KSS-enabled build

```
_mask     = 0xffffffffffffffff0000000000000000
_expected = 0x85000000000000000000000000000000   // INIT | MODE64BIT | KSS(0x80) = 0x85
```

- Identical to A, but **also requires `KSS` (`0x80`) to be set**. Use only if the enclave was built
  with Key Separation & Sharing (its quotes will *always* carry `KSS`, so a strict pin must require it).
- All forbidden bits are still required clear (`0x85 & 0x32 == 0`).
- If you'd rather *allow but not require* KSS, clear bit 7 in the mask instead
  (`_mask = 0x7fffffffffffffff0000000000000000`, `_expected = 0x05…`).

### Profile C — Strict FLAGS pin, CET-enabled build

```
_mask     = 0xffffffffffffffff0000000000000000
_expected = 0x45000000000000000000000000000000   // INIT | MODE64BIT | CET(0x40) = 0x45
```

- Identical to A, but **also requires `CET` (`0x40`)**. Use only for builds compiled with Control-flow
  Enforcement (shadow stack / IBT). `0x45 & 0x32 == 0`, so the floor is still cleared.

### Profile D — Forbidden-floor only *(permissive bootstrap; not for production)*

```
_mask     = 0x32000000000000000000000000000000   // == SGX_FORBIDDEN_ATTRIBUTE_MASK
_expected = 0x00000000000000000000000000000000
```

- The **least restrictive policy the contract accepts**: it only re-states the universal floor
  (`DEBUG/PROVISION_KEY/EINITTOKEN_KEY` must be clear) and checks nothing else.
- It does **not** require `INIT`/`MODE64BIT` and tolerates any value of `CET`, `KSS`, reserved bits,
  and all of XFRM.
- This is the `FORBIDDEN_FLOOR` / `0` pin used in the shared test setup. Use it only to bootstrap or
  while you confirm a new build's exact ATTRIBUTES; **migrate to Profile A for production**, since D
  gives up the extra assurance the pin is meant to provide.

### Profile E — Strict FLAGS + exact XFRM *(homogeneous hardware only)*

```
_mask     = 0xffffffffffffffffff00000000000000   // 8 FLAGS bytes + low XFRM byte
_expected = 0x05000000000000000700000000000000   // FLAGS = 0x05 ; XFRM low byte = x87|SSE|AVX = 0x07
```

- Profile A **plus** a pin on the low XFRM byte to exactly `x87|SSE|AVX` (`0x07`).
- **Brittle:** it rejects any prover whose XFRM differs — e.g. an AVX‑512 host reporting `0xE7`, or a
  legacy `0x03` host. Only use it when you operate homogeneous, fixed-XSAVE prover hardware and want to
  pin the extended-state surface too. Otherwise prefer A.

> **Validity self-check** for any custom policy: `expected & ~mask == 0`,
> `mask & 0x32…00 == 0x32…00`, and `expected & 0x32…00 == 0`. Profiles A–E all satisfy these.

---

## 4. Why XFRM is unchecked by default

XFRM (the XSAVE-Feature-Request-Mask half of ATTRIBUTES) selects which extended CPU state
(AVX, AVX‑512, …) is in the enclave's scope. It is a function of the **host CPU and its XCR0/XSAVE
configuration**, not of the enclave's trustworthiness: the same `MRENCLAVE` legitimately produces
`0x03`, `0x07`, or `0xE7` on different machines. Pinning XFRM (Profile E) therefore tends to reject
honest provers on heterogeneous hardware with no security gain, because DEBUG/provisioning/launch
abuse lives entirely in **FLAGS**, which Profiles A–D already pin tightly. Pin XFRM only when you
deliberately run uniform hardware.

---

## 5. The `MRENCLAVE` values (build-specific — fetch, don't guess)

Unlike the profiles above, `MRENCLAVE` cannot be enumerated here: it is the SHA‑256 of a specific
enclave build and **changes on every Raiko / SGX‑geth release**. Taiko rotates it on upgrades — the
mainnet logs record `setMrEnclave` rotations (e.g. *"Update mrenclave & mrsign on May 28, 2024"*) but
by transaction hash, never by embedding the measurement. The application enclaves you actually pin on
this verifier are:

| Enclave (what to allowlist) | Source of the `MRENCLAVE` | Recommended profile |
| --- | --- | --- |
| **Raiko SGX‑reth prover** (`*-sgxreth`) | The release's SIGSTRUCT / reproducible build | **A** (B if the build enables KSS) |
| **SGX‑geth prover** (`*-sgxgeth`) | The release's SIGSTRUCT / reproducible build | **A** (B if KSS) |

> Intel platform enclaves (Quoting Enclave, PCE, …) are **not** pinned here — QE identity is handled
> by the Automata DCAP attestation entrypoint, not by `setEnclaveAttributePolicy`. This pin is only
> for the **application** enclave (`MRENCLAVE`) that signs Taiko proofs.

### How to obtain the real `MRENCLAVE`

- **From the enclave SIGSTRUCT** (Gramine): `gramine-sgx-sigstruct-view raiko.sig` and read the
  `mr_enclave` field; or read bytes `[960:992]` of the `.sig`.
- **From a raw DCAP quote:** the MRENCLAVE is at enclave-report offset 64 (raw-quote offset
  `HEADER_LENGTH + 64 = 112`), i.e. `bytes32(rawQuote[112:144])` — the same slice
  [`SgxVerifier.registerInstance`](../../../contracts/layer1/verifiers/SgxVerifier.sol) reads.
- **From the Raiko release** that the prover fleet runs (the reproducible build publishes its
  `MRENCLAVE`); confirm it matches the running instances' quotes before pinning.
- **From history on-chain:** decode the `setMrEnclave(bytes32,bool)` calldata of the rotation txs in
  [`mainnet-contract-logs-L1.md`](../../../deployments/mainnet-contract-logs-L1.md).

Pin the **same** `MRENCLAVE` on both the allowlist (`setMrEnclave`) and the attribute policy
(`setEnclaveAttributePolicy`): the verifier requires both, and an `MRENCLAVE` with no attribute
policy **fails closed**.

---

## 6. Summary table (for building transactions)

`setEnclaveAttributePolicy(bytes32 _mrEnclave, bytes16 _mask, bytes16 _expected)` — `onlyOwner` on
`SecureSgxVerifier`. `_mrEnclave` is build-specific (fetch per release, §5); `_mask` / `_expected`
come from the profile you pick:

| Profile | `_mask` | `_expected` | When to use / why |
| --- | --- | --- | --- |
| **A — Strict FLAGS (default)** | `0xffffffffffffffff0000000000000000` | `0x05000000000000000000000000000000` | Standard production prover build. Requires `INIT(0x01) \| MODE64BIT(0x04)`; forces all other FLAGS bits (forbidden floor, CET, KSS, reserved) to 0; XFRM unchecked. Matches the repo's tested pin. |
| **B — Strict FLAGS + KSS** | `0xffffffffffffffff0000000000000000` | `0x85000000000000000000000000000000` | Same as A, but the build enables KSS → also requires `KSS(0x80)`. |
| **C — Strict FLAGS + CET** | `0xffffffffffffffff0000000000000000` | `0x45000000000000000000000000000000` | Same as A, but the build enables CET → also requires `CET(0x40)`. |
| **D — Forbidden-floor only** | `0x32000000000000000000000000000000` | `0x00000000000000000000000000000000` | Permissive bootstrap only. Re-states the floor (DEBUG/PROVISION/EINITTOKEN clear); checks nothing else. Not for production. |
| **E — Strict FLAGS + exact XFRM** | `0xffffffffffffffffff00000000000000` | `0x05000000000000000700000000000000` | A + pins XFRM low byte to `x87 \| SSE \| AVX (0x07)`. Homogeneous hardware only (brittle across CPUs). |

Per-enclave rows to fill in (use Profile A unless the build enables KSS/CET):

| `_mrEnclave` | Enclave | `_mask` | `_expected` |
| --- | --- | --- | --- |
| `0x<RAIKO_SGXRETH_MRENCLAVE>` | Raiko SGX‑reth prover | `0xffffffffffffffff0000000000000000` | `0x05000000000000000000000000000000` |
| `0x<SGXGETH_MRENCLAVE>` | SGX‑geth prover | `0xffffffffffffffff0000000000000000` | `0x05000000000000000000000000000000` |

Pin the **same** `MRENCLAVE` on the allowlist too (`setMrEnclave`) — an `MRENCLAVE` with no attribute
policy **fails closed**.

To retire a build's pin (registration for it then fails closed) use
`removeEnclaveAttributePolicy(bytes32)`, callable by the owner or the `registrar`.

> [!NOTE]
> Removing a pin only blocks **future** registrations; already-registered instances of that
> `MRENCLAVE` keep verifying until they expire (`INSTANCE_EXPIRY`, 90 days). To revoke them
> immediately, also call `deleteInstances(uint256[])`. See the verifier's Daybreak audit note.

---

## 7. Sources

- Intel SGX FLAGS bit values — `sgx_attributes.h`:
  [intel/linux-sgx](https://github.com/intel/linux-sgx/blob/main/common/inc/sgx_attributes.h)
- XFRM / `SGX_XFRM_LEGACY` (`0x03`), `SGX_XFRM_AVX` (`0x06`), `SGX_XFRM_AVX512` (`0xE6`) — same header.
- Gramine SIGSTRUCT mask handling:
  [gramineproject/gramine#44](https://github.com/gramineproject/gramine/pull/44)
- Raiko (Taiko's multi-prover): [taikoxyz/raiko](https://github.com/taikoxyz/raiko) ·
  [Introducing Raiko](https://taiko.mirror.xyz/qmw6Or2T8OnadFpqULXDZaIzsBKRVvavB-AEUvp6fxM)
- In-repo: [`SecureSgxVerifier.sol`](../../../contracts/layer1/verifiers/SecureSgxVerifier.sol) ·
  [`SgxVerifier.sol`](../../../contracts/layer1/verifiers/SgxVerifier.sol) ·
  [`SgxVerifier.t.sol`](../../../test/layer1/verifiers/SgxVerifier.t.sol) (`STRICT_MASK`/`STRICT_EXPECTED`)
```
