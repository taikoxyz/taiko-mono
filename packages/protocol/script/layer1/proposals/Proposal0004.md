# Proposal 0004

## Summary

This proposal includes the following actions on Ethereum mainnet to upgrade/change Taiko Alethia protocol's code or configurations.

- Add trusted images to SP1 (Succinct) verifier `0xbee1040D0Aab17AE19454384904525aE4A3602B9`:

  - `0x008f96447139673b3f2d29b30ad4b43fe6ccb3f31d40f6e61478ac5640201d9e`
  - `0x47cb22384e59cecf65a536612d4b43fe36659f987503db9828f158ac40201d9e`
  - `0x00a32a15ab7a74a9a79f3b97a71d1b014cd4361b37819004b9322b502b5f5be1`
  - `0x51950ad55e9d2a6973e772f471d1b01466a1b0d95e064012726456a02b5f5be1`

- Add trusted images to Risc0 verifier `0x73Ee496dA20e5C65340c040B0D8c3C891C1f74AE`:

  - `0x3d933868e2ac698df98209b45e6c34c435df2d3c97754bb6739d541d5fd312e3`
  - `0x77ff0953ded4fb48bb52b1099cc36c6b8bf603dc4ed9211608c039c7ec31b82b`

- Upgrade Risc0 verifier `0x73Ee496dA20e5C65340c040B0D8c3C891C1f74AE` to implementation `0xDF6327caafC5FeB8910777Ac811e0B1d27dCdf36` (changes `proposeBatch` function return data). [View diff](https://codediff.taiko.xyz/?addr=0x73Ee496dA20e5C65340c040B0D8c3C891C1f74AE&newimpl=0xDF6327caafC5FeB8910777Ac811e0B1d27dCdf36&chainid=1&filter=changed)

- Upgrade PreconfRouter `0xD5AA0e20e8A6e9b04F080Cf8797410fafAa9688a` to implementation `0xafCEDDe020dB8D431Fa86dF6B14C20f327382709` (adds `getConfig()` view function). [View diff](https://codediff.taiko.xyz/?addr=0xD5AA0e20e8A6e9b04F080Cf8797410fafAa9688a&newimpl=0xafCEDDe020dB8D431Fa86dF6B14C20f327382709&chainid=1&filter=changed)

- Call `setMrEnclave` on SGX-GETH attester `0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261`:

  - `0x3e6113a23bbdf9231520153253047d02db8f1dd38a9b52914ab7943278f52db0`

- Call `setMrEnclave` on SGX-RETH attester `0x8d7C954960a36a7596d7eA4945dDf891967ca8A3`:
  - `0xe5774b71990b0d5f3eca8d4d22546764dd9549c743a1a6d4d4863d97f6b8c67a`
  - `0x605ad10c1a56ed7289f198d64a39a952cd3b8a0bed3fcb19c8301c1847dc3a2f`

## TODO

- Yue: why setMrEnclave is called twice for SGX-RETH attester but once for SGX-GETH?
- Describe setMrEnclave
- Provide verification links and instructions for program IDs
