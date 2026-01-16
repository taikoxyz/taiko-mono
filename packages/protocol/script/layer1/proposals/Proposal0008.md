# PROPOSAL-0008: Raiko v1.13.0 Verifier Image + SGX Attestation Update

## Executive Summary

This proposal updates trusted ZK proving keys / image IDs for the SP1 and Risc0 verifiers, and updates SGX attestation allowlists (MR_ENCLAVE) for Raiko v1.13.0 (including EDMM).

## Technical Specification

### 1. ZK Verifier Image Updates (`raiko-zk:1.13.0`)

#### 1.1 SP1 (Succinct) Verifier Updates

**Contract**: `0xbee1040D0Aab17AE19454384904525aE4A3602B9`

New trusted program VKeys to be added:

- `0x005208749e76b13f5d72368ee12957ae9de239110b51e00a77b16cbb1c2a9381` (sp1-aggregation, vk bn256)
- `0x29043a4f1dac4fd72e46d1dc12957ae96f11c8882d4780296f62d9761c2a9381` (sp1-aggregation, vk hash_bytes)
- `0x009d1daf24137c3fb08e1dd65bc517e0f66f07f2c9b2cadb870f235a99ae0905` (sp1-batch, vk bn256)
- `0x4e8ed79204df0fec11c3bacb3c517e0f33783f9626cb2b6e0e1e46b519ae0905` (sp1-batch, vk hash_bytes)
- `0x00d2c81ddd6751beb8c7656fca189b4b216c7d641afd00d36d5795e7e8a8b53b` (sp1-shasta-aggregation, vk bn256)
- `0x69640eee59d46fae18ecadf92189b4b20b63eb206bf4034d5aaf2bcf68a8b53b` (sp1-shasta-aggregation, vk hash_bytes)

#### 1.2 Risc0 Verifier Updates

**Contract**: `0x73Ee496dA20e5C65340c040B0D8c3C891C1f74AE`

New trusted image IDs to be added:

- `0x718c5f47ae60739a571681c9f02c1895c791346eece96f58b345159cc6f97c9f` (boundless-aggregation)
- `0x3c98171d6744a78a55289aed44281780bca067906e3618aca5ba657595572c25` (boundless-batch)
- `0x22e8f4b2f051e6630a90fabe99d1034b87daaedb47b62f0b41b1b8158c33dc45` (boundless-shasta-aggregation)

### 2. SGX Attestation Updates (`raiko:1.13.0` / `raiko:1.13.0-edmm`)

#### 2.1 SGX-GETH Attester

**Contract**: `0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261`

New MR_ENCLAVE value to be added:

- `0xb75d06566bf7f92fc758dd69210d785f549c57436e4529845ce785524848cb6f`

#### 2.2 SGX-RETH Attester

**Contract**: `0x8d7C954960a36a7596d7eA4945dDf891967ca8A3`

New MR_ENCLAVE values to be added:

- `0x1b1d7595fef567e1a97e4b4773e95f9fd136d602f4a40965697609d4191da030` (Non-EDMM mode)
- `0x446863e6b9cf3c658d864de1137df2c354781ddea167a9efdc7de8aab74c01ab` (EDMM-enabled mode)

#### 2.3 MR_SIGNER

MR_SIGNER is unchanged from previous releases:

- `0xca0583a715534a8c981b914589a7f0dc5d60959d9ae79fb5353299a4231673d5`

## Appendix: Build Outputs

```text
# zk:v1.13.0

## image

us-docker.pkg.dev/evmchain/images/raiko-zk:1.13.0

## risc0

boundless elf image id: 718c5f47ae60739a571681c9f02c1895c791346eece96f58b345159cc6f97c9f
"/opt/raiko/provers/risc0/guest/target/riscv32im-risc0-zkvm-elf/release/boundless-aggregation"
boundless elf image id: 3c98171d6744a78a55289aed44281780bca067906e3618aca5ba657595572c25
"/opt/raiko/provers/risc0/guest/target/riscv32im-risc0-zkvm-elf/release/boundless-batch"
boundless elf image id: 22e8f4b2f051e6630a90fabe99d1034b87daaedb47b62f0b41b1b8158c33dc45
"/opt/raiko/provers/risc0/guest/target/riscv32im-risc0-zkvm-elf/release/boundless-shasta-aggregation"

## sp1

"/opt/raiko/provers/sp1/guest/target/riscv32im-succinct-zkvm-elf/release/sp1-aggregation"
sp1 elf vk bn256 is: 0x005208749e76b13f5d72368ee12957ae9de239110b51e00a77b16cbb1c2a9381
sp1 elf vk hash_bytes is: 29043a4f1dac4fd72e46d1dc12957ae96f11c8882d4780296f62d9761c2a9381
"/opt/raiko/provers/sp1/guest/target/riscv32im-succinct-zkvm-elf/release/sp1-batch"
sp1 elf vk bn256 is: 0x009d1daf24137c3fb08e1dd65bc517e0f66f07f2c9b2cadb870f235a99ae0905
sp1 elf vk hash_bytes is: 4e8ed79204df0fec11c3bacb3c517e0f33783f9626cb2b6e0e1e46b519ae0905
"/opt/raiko/provers/sp1/guest/target/riscv32im-succinct-zkvm-elf/release/sp1-shasta-aggregation"
sp1 elf vk bn256 is: 0x00d2c81ddd6751beb8c7656fca189b4b216c7d641afd00d36d5795e7e8a8b53b
sp1 elf vk hash_bytes is: 69640eee59d46fae18ecadf92189b4b20b63eb206bf4034d5aaf2bcf68a8b53b

# v1.13.0

## image

us-docker.pkg.dev/evmchain/images/raiko:1.13.0

## gaiko

- mrenclave: b75d06566bf7f92fc758dd69210d785f549c57436e4529845ce785524848cb6f
- mrsigner: ca0583a715534a8c981b914589a7f0dc5d60959d9ae79fb5353299a4231673d5

## raiko

- mrenclave: 1b1d7595fef567e1a97e4b4773e95f9fd136d602f4a40965697609d4191da030
- mrsigner: ca0583a715534a8c981b914589a7f0dc5d60959d9ae79fb5353299a4231673d5

# v1.13.0-edmm

## image

us-docker.pkg.dev/evmchain/images/raiko:1.13.0-edmm

## gaiko

- mrenclave: b75d06566bf7f92fc758dd69210d785f549c57436e4529845ce785524848cb6f
- mrsigner: ca0583a715534a8c981b914589a7f0dc5d60959d9ae79fb5353299a4231673d5

## raiko

- mrenclave: 446863e6b9cf3c658d864de1137df2c354781ddea167a9efdc7de8aab74c01ab
- mrsigner: ca0583a715534a8c981b914589a7f0dc5d60959d9ae79fb5353299a4231673d5
```

