# Proposal 0004

## Summary

This proposal includes the following actions on Ethereum mainnet to upgrade/change Taiko Alethia protocol's code or configurations.

### Group 1 - Enable new ZK images

- Add trusted images to SP1 (Succinct) verifier `0xbee1040D0Aab17AE19454384904525aE4A3602B9`:

  - `0x008f96447139673b3f2d29b30ad4b43fe6ccb3f31d40f6e61478ac5640201d9e`
  - `0x47cb22384e59cecf65a536612d4b43fe36659f987503db9828f158ac40201d9e`
  - `0x00a32a15ab7a74a9a79f3b97a71d1b014cd4361b37819004b9322b502b5f5be1`
  - `0x51950ad55e9d2a6973e772f471d1b01466a1b0d95e064012726456a02b5f5be1`

- Add trusted images to Risc0 verifier `0x73Ee496dA20e5C65340c040B0D8c3C891C1f74AE`:

  - `0x3d933868e2ac698df98209b45e6c34c435df2d3c97754bb6739d541d5fd312e3`
  - `0x77ff0953ded4fb48bb52b1099cc36c6b8bf603dc4ed9211608c039c7ec31b82b`

To verify the image IDs, check out the release and run ./script/publish-image.sh to build the corresponding ZK images, and the log will be like:

```
#41 550.0 risc0 elf image id: 3d933868e2ac698df98209b45e6c34c435df2d3c97754bb6739d541d5fd312e3
...
#41 551.7 risc0 elf image id: 77ff0953ded4fb48bb52b1099cc36c6b8bf603dc4ed9211608c039c7ec31b82b
```

or

```
#43 131.2 sp1 elf vk bn256 is: 0x008f96447139673b3f2d29b30ad4b43fe6ccb3f31d40f6e61478ac5640201d9e
#43 131.2 sp1 elf vk hash_bytes is: 47cb22384e59cecf65a536612d4b43fe36659f987503db9828f158ac40201d9e
...
#43 143.6 sp1 elf vk bn256 is: 0x00a32a15ab7a74a9a79f3b97a71d1b014cd4361b37819004b9322b502b5f5be1
#43 143.6 sp1 elf vk hash_bytes is: 51950ad55e9d2a6973e772f471d1b01466a1b0d95e064012726456a02b5f5be1
```

### Group 2 - upgrade code

- Upgrade Risc0 verifier `0x73Ee496dA20e5C65340c040B0D8c3C891C1f74AE` to implementation `0xDF6327caafC5FeB8910777Ac811e0B1d27dCdf36` (changes `proposeBatch` function return data) and constructor parameter values -- riscoGroth16Verifier address changed from `0x34Eda8BfFb539AeC33078819847B36D221c6641c` to [`0x7CCA385bdC790c25924333F5ADb7F4967F5d1599`](https://etherscan.io/address/0x7CCA385bdC790c25924333F5ADb7F4967F5d1599#code). [View diff](https://codediff.taiko.xyz/?addr=0x73Ee496dA20e5C65340c040B0D8c3C891C1f74AE&newimpl=0xDF6327caafC5FeB8910777Ac811e0B1d27dCdf36&chainid=1&filter=changed)

- Upgrade PreconfRouter `0xD5AA0e20e8A6e9b04F080Cf8797410fafAa9688a` to implementation `0xafCEDDe020dB8D431Fa86dF6B14C20f327382709` (adds `getConfig()` view function). [View diff](https://codediff.taiko.xyz/?addr=0xD5AA0e20e8A6e9b04F080Cf8797410fafAa9688a&newimpl=0xafCEDDe020dB8D431Fa86dF6B14C20f327382709&chainid=1&filter=changed)

### Group 3 - set new MrEnclave

MrEnclave (Measurement Register Enclave) is a cryptographic hash digest (SHA-256) of the SGX Enclave binary, acting like a "fingerprint" of the code. So once we set the MrEnclave, proof generated only by the execute binary built from our official code base can be verified. Official release's MrEnclave can be found [here](https://github.com/taikoxyz/raiko/blob/v1.12.0/RELEASE.md).

Note that SGX-RETH is built with [Gramine](https://gramineproject.io), which supports both EDMM-enabled and EDMM-disabled SGX, whereas SGX-GETH is built with [EGo](https://github.com/edgelesssys/ego), which supports only non-EDMM. That’s why SGX-RETH has two MRENCLAVEs.

- Call `setMrEnclave` on SGX-GETH attester `0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261`:

  - `0x3e6113a23bbdf9231520153253047d02db8f1dd38a9b52914ab7943278f52db0`

- Call `setMrEnclave` on SGX-RETH attester `0x8d7C954960a36a7596d7eA4945dDf891967ca8A3`.
  - `0xe5774b71990b0d5f3eca8d4d22546764dd9549c743a1a6d4d4863d97f6b8c67a`
  - `0x605ad10c1a56ed7289f198d64a39a952cd3b8a0bed3fcb19c8301c1847dc3a2f`

Too verify the MR_ENCLAVE values, check out the release and run ./script/publish-image.sh [0|1] (0 to disable edmm, 1 to enable) to build the corresponding sgx image, the logs for non-edmm mode will be like:

```
#30 0.205 2025/10/09 03:10:00 INFO EGo version=1.7.0 git_commit=3a3f54a1d1cd9318dd1ade411f9f439f53bb6694
#30 0.205 3e6113a23bbdf9231520153253047d02db8f1dd38a9b52914ab7943278f52db0
...
#48 3.653     mr_enclave: e5774b71990b0d5f3eca8d4d22546764dd9549c743a1a6d4d4863d97f6b8c67a

```

For edmm:

```
#30 0.205 2025/10/09 03:10:00 INFO EGo version=1.7.0 git_commit=3a3f54a1d1cd9318dd1ade411f9f439f53bb6694
#30 0.205 3e6113a23bbdf9231520153253047d02db8f1dd38a9b52914ab7943278f52db0
...
#48 3.653     mr_enclave: 605ad10c1a56ed7289f198d64a39a952cd3b8a0bed3fcb19c8301c1847dc3a2f
```
