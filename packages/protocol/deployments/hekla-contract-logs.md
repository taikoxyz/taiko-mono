# Taiko Hekla network Contract Logs

## Notes

1. Code used on Hekla must correspond to a commit on the main branch of the official repo: https://github.com/taikoxyz/taiko-mono.

## L1 Contracts

### shared_address_manager

- proxy: `0x7D3338FD5e654CAC5B10028088624CA1D64e74f7`
- impl: `0xAcA2a9f774e540CF592c07bBaAC9Ebae40e7C175`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 10, 2024 at commit `d5965bb`
  - transferred ownership on Jul 8, 2024
  - upgraded on Sep 20, 2024 at commit `fd1c039`
  - upgraded on Oct 29, 2024 at commit `3d12cb2`

### taiko_token

- proxy: `0x6490E12d480549D333499236fF2Ba6676C296011`
- impl: `0xD826bb700EAEdD6E83C32681f95a35Ac7F290104`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Mar 29, 2024 at commit `b341a68d5`
  - upgraded on Jun 18, 2024, added `batchTransfer` method.
  - transferred ownership on Jul 8, 2024
  - upgraded on Dec 16, 2024 at commit `ccc9500`

### signal_service

- proxy: `0x6Fc2fe9D9dd0251ec5E0727e826Afbb0Db2CBe0D`
- impl: `0xE99029aAd6606fF540763d570F5b10b169eEE121`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 10, 2024 at commit `d5965bb`
  - transferred ownership on Jul 8, 2024
  - upgraded on Mar 21, 2025 at commit `80baf41`

### bridge

- proxy: `0xA098b76a3Dd499D3F6D58D8AcCaFC8efBFd06807`
- impl: `0xE3d424D6D752dBcc6e19Dfd6755D518118f3d93b`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 10, 2024 at commit `d5965bb`
  - transferred ownership on Jul 8, 2024
  - upgraded on Sep 20, 2024 at commit `fd1c039`
  - upgraded on Oct 29, 2024 at commit `3d12cb2`

### erc20_vault

- proxy: `0x2259662ed5dE0E09943Abe701bc5f5a108eABBAa`
- impl: `0x1bf437b2f6e5959fe167210Ee2221ADa09a66846`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 10, 2024 at commit `d5965bb`
  - transferred ownership on Jul 8, 2024

### erc721_vault

- proxy: `0x046b82D9010b534c716742BE98ac3FEf3f2EC99f`
- impl: `0x06467bab46598b887240044309A6ffE261A0E2e3`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 10, 2024 at commit `d5965bb`
  - transferred ownership on Jul 8, 2024

### erc1155_vault

- proxy: `0x9Ae5945Ab34f6182F75E16B73e037421F341fEe3`
- impl: `0xBFCff65554d6e89A1aC280eE1E9f87764124B833`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 10, 2024 at commit `d5965bb`
  - transferred ownership on Jul 8, 2024

### bridged_erc20

- impl: `0xe3661857941E4A711fa6b4Fc080bC5c5948a70f1`
- logs:
  - deployed on May 10, 2024 at commit `4903bec`
  - deployed on Jul 25, 2024 at commit `3d89d24`

### bridged_erc721

- impl: `0xbD832CAf65c8a73609EFd62E2A4FCB1292e4c9C1`
- logs:
  - deployed on May 10, 2024 at commit `4903bec`

### bridged_erc1155

- impl: `0x0B5B063dc89EcfCedf8aF570d82598F72a7dfF35`
- logs:
  - deployed on May 10, 2024 at commit `4903bec`

### rollup_address_manager

- proxy: `0x1F027871F286Cf4B7F898B21298E7B3e090a8403`
- impl: `0x97Ece9dC33e8442ED6e61aA378bf3FdC7dF17213`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - upgraded on May 10, 2024 at commit `13ad99d`
  - upgraded on Jun 10, 2024 at commit `d5965bb`
  - transferred ownership on Jul 8, 2024
  - upgraded on Sep 20, 2024 at commit `fd1c039`
  - upgraded on Oct 29, 2024 at commit `3d12cb2`

### taikoInbox

- proxy: `0x79C9109b764609df928d16fC4a91e9081F7e87DB`
- impl: `0x013CDdBD3Be242337C3124834335Cd8b72c97324`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- oldFork: `0x6e15d2049480C7E339C6B398774166e1ddbCd43e` at commit `a634150`
- newFork: `0x93684C898950013850dE100b0Aed0a8E457dC825` at commit `80baf41`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 10, 2024 at [PR #17532](https://github.com/taikoxyz/taiko-mono/pull/17532)
  - upgraded on Jun 12, 2024 at commit `07b073d`
  - upgraded on Jun 12, 2024 at [PR #17553](https://github.com/taikoxyz/taiko-mono/pull/17553)
  - upgraded on Jun 14, 2024 at [PR #17553](https://github.com/taikoxyz/taiko-mono/pull/17553) @commit `baed5b5`
  - upgraded on Jun 19, 2024 at commit `b7e12e3`
  - upgraded on Jun 20, 2024 at commit `6e07ab5`
  - transferred ownership on Jul 8, 2024
  - upgraded on Jul 11, 2024 at [PR #17779](https://github.com/taikoxyz/taiko-mono/pull/17779)
  - upgraded on Jul 15, 2024 at commit `45281b8`
  - upgraded on Aug 15, 2024 at `protocol-v1.8.0` with [#17919](https://github.com/taikoxyz/taiko-mono/pull/17919)
  - upgraded on Sep 20, 2024 at commit `fd1c039`
  - upgraded on Oct 16, 2024 at commit `233806e`
  - upgraded on Oct 29, 2024 at commit `3d12cb2`
  - upgraded on Nov 3, 2024 at commit `ea0158f`
  - upgraded on Feb 1, 2025 at commit `75359cc`
  - upgraded on Feb 2, 2025 at commit `e294023`
  - upgraded on Mar 21, 2025 at commit `80baf41`

### assignmentHook

- proxy: `0x9e640a6aadf4f664CF467B795c31332f44AcBe6c`
- impl: `0xfcb5B945dbd08AfdB08e6C358193B23b0E6eFa23`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 12, 2024 at commit `04bb81e`
  - transferred ownership on Jul 8, 2024

### tierProvider

- impl: `0x9AaBba3Ae6D4aC3F5487608Da81006454e7933d3`
- logs:
  - upgraded on May 14, 2024 at commit `0ef7b8caa`
  - upgraded on Jun 14, 2024 at commit `cc10b04`
  - upgraded on Jun 19, 2024 at commit `b7e12e3`
  - upgraded on Aug 15, 2024 at commit `05d49b0`

### tierRouter

- impl: `0x426F0674a80314D8862348F1482C3F7B4a9C64A4.`
- logs:
  - deployed on Jun 10, 2024 at commit `d5965bb`
  - upgraded on Jun 14, 2024 at commit `cc10b04`
  - upgraded on Jun 19, 2024 at commit `b7e12e3`
  - upgraded on Aug 15, 2024 at commit `05d49b0`
  - upgraded on Sep 02, 2024 at commit `9dae5c8`
  - upgraded on Oct 24, 2024 at commit `78f9ac0`
  - upgraded on Oct 30, 2024 at commit `63455f9`
  - upgraded on Nov 4, 2024 at commit `90b2693`
  - upgraded on Nov 4, 2024 at commit `8e00612`
  - upgraded on Feb 17, 2025 at commit `51090ba`

### prover_set

- proxy: `0xD3f681bD6B49887A48cC9C9953720903967E9DC0`
- impl: `0x3C8D6D4F6fDda77c1d86b4C5F0712C07B150A87c.`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Jun 17, 2024 at commit `b7e12e3`
  - upgraded on Jul 11, 2024 at commit `30631a9`
  - upgraded on Sep 20, 2024 at commit `fd1c039`
  - upgraded on Oct 29, 2024 at commit `3d12cb2`
  - upgraded on Mar 21, 2025 at commit `80baf41`

### prover_set_contester

- proxy: `0x335103c4fa2F55451975082136F1478eCFeB84B9`
- impl: `0x93Df4e369fb916ccc78e94e85017d18e367ba9B5.`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Jun 21, 2024 at commit `099ce22`
  - upgraded on Jul 11, 2024 at commit `30631a9`
  - upgraded on Sep 20, 2024 at commit `fd1c039`
  - upgraded on Oct 29, 2024 at commit `3d12cb2`

### guardian_prover

- proxy: `0x92F195a8702da2104aE8E3E10779176E7C35d6BC`
- impl: `0x426A2DA100727d8f3e89252Ba125acbd0e048aDe`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 10, 2024 at commit `d5965bb`
  - transferred ownership on Jul 8, 2024
  - upgraded on Sep 20, 2024 at commit `fd1c039`
  - upgraded on Oct 29, 2024 at commit `3d12cb2`

### guardian_minority

- proxy: `0x31d4d27da5c299d4b6CE19c869B8891C0002795d`
- impl: `0x8ACaB96A6e8bf611E21A6eA332C6509c8d0b699f`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on May 20, 2024 at commit `6e56475`
  - upgraded on Jun 10, 2024 at commit `d5965bb`
  - transferred ownership on Jul 8, 2024
  - upgraded on Sep 20, 2024 at commit `fd1c039`
  - upgraded on Oct 29, 2024 at commit `3d12cb2`

### tier_sgx

- proxy : 0x532EFBf6D62720D0B2a2Bb9d11066E8588cAE6D9
- impl : 0x3c1b6b0F179dab0dE5e11C9B2a531C5c693Fd70C
- owner : 0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190
- logs:
  - upgraded on Nov 6, 2024 at commit `0706f0a`

### risc0_groth16_verifier

- addr : 0x714FD0666B0cee87bFC29A029E2AE66f40F12cE5
- logs:
  - deployed on August 14, 2024 at commit `cba2a1e`
  - upgraded on October 22, 2024 at commit `684a909`
  - upgraded on Jan 10, 2025 at commit `2802b21`

### tier_zkvm_risc0

- proxy : 0x4fEd801C5a876D4289e869cbEfA1E1A448b10714
- impl : 0xAF9F3B3f9276f24e4143e6247795cf71985C4890
- owner : 0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190
- logs:
  - deployed on August 14, 2024 at commit `cba2a1e`
  - upgraded on Nov 6, 2024 at commit `0706f0a`

### sp1_plonk_verifier

- addr : 0x7110bd8909CFC4C31204BA8597882CBFa1F77dC9
- logs:
  - deployed on September 02, 2024 at commit `16ac02e`
  - upgraded on September 15, 2024 at commit `6f26434`
  - upgraded on October 22, 2024 at commit `684a909`
  - upgraded on Nov 8, 2024 at commit `0b11101`
  - upgraded on Jan 9, 2025 at commit `de12a26`

### tier_zkvm_sp1

- proxy : 0xFbE49f777E0078b3Fa0bae6de4794c88d6EA6DDD
- impl : 0xB83b7f7fA8f4e6332769D123b8C973F485aC4bBc.
- owner : 0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190
- logs:
  - deployed on September 02, 2024 at commit `16ac02e`
  - upgraded on September 15, 2024 at commit `6f26434`
  - upgraded on Nov 6, 2024 at commit `0706f0a`

### shared_resolver

- proxy : 0xD8e341467b4a1f83B868a6c279ad7d8660ad861c
- impl : 0xA8bE5B49Bf5f1877Cd985A39E62D6899b0aaDd74
- owner : 0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190
- logs:
  - deployed on March 21, 2025 at commit `80baf41`

### rollup_address_resolver

- proxy : 0x3C82907B5895DB9713A0BB874379eF8A37aA2A68
- impl : 0xf887fA8ffFBb289860a6ec6788B787A2E0000Ed4
- owner : 0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190
- logs:
  - deployed on March 21, 2025 at commit `80baf41`

### forced_inclusion_store

- proxy : 0x54231533B8d8Ac2f4F9B05377B617EFA9be080Fd
- impl : 0xbd80216694f84dcabF342BA1A2304601d57A321a
- owner : 0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190
- logs:
  - deployed on March 21, 2025 at commit `80baf41`

### taiko_wrapper

- proxy : 0x8698690dEeDB923fA0A674D3f65896B0031BF7c9
- impl : 0x40D9cE1C32b27e65e5FbEc0ddAf69c852e9282Ae
- owner : 0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190
- logs:
  - deployed on March 21, 2025 at commit `80baf41`

### proof_verifier

- proxy : 0x9A919115127ed338C3bFBcdfBE72D4F167Fa9E1D
- impl : 0xA5B542eEaA24036E0De2Ced405CD8061E6e8DB38
- owner : 0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190
- logs:
  - deployed on March 21, 2025 at commit `80baf41`

### sgx_verifier(Pacaya)

- proxy : 0xa8cD459E3588D6edE42177193284d40332c3bcd4
- impl : 0x7EB7DCd5f7053dD270c85B2388F555FCDFd6e55f
- owner : 0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190
- logs:
  - deployed on March 21, 2025 at commit `80baf41`

### risc0_verifier(Pacaya)

- proxy : 0xCDdf353C838542834E443C3c9dE3ab3F81F27aF2
- impl : 0x06B789A83db6cB785e5c2a99eedE7A3033576024
- owner : 0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190
- logs:
  - deployed on March 21, 2025 at commit `80baf41`

### sp1_verifier(Pacaya)

- proxy : 0x1138aA994477f0880001aa1E8106D749035b6250
- impl : 0xC472632288b233fadca875821dE173b641bE9fB1
- owner : 0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190
- logs:
  - deployed on March 21, 2025 at commit `80baf41`

### pivot_verifier

- proxy : 0x4361B85093720bD50d25236693CA58FD6e1b3a53
- impl : 0x9890f2B69D5D9c217093aCb63e47B47A9070b54e
- owner : 0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190
- logs:
  - deployed on March 21, 2025 at commit `80baf41`

### pivot_automata_dcap_attestation

- proxy : 0x84af08F56AeA1f847c75bE08c96cDC4811694595
- impl : 0x9bbd836a3b1901cdc561e22f2bE0c808352BF10E
- owner : 0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190
- logs:
  - deployed on April 2, 2025 at commit `25af05a`

## L2 Contracts

### bridge

- proxy: `0x1670090000000000000000000000000000000001`
- impl: `0x50216f60163ef399E22026fa1300aEa8eebA3462`
- owner: `0x95F6077C7786a58FA070D98043b16DF2B1593D2b`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 10, 2024 at commit `d5965bb`
  - upgraded on Sep 20, 2024 at commit `fd1c039`
  - upgraded on Oct 29, 2024 at commit `3d12cb2`

### erc20_vault

- proxy: `0x1670090000000000000000000000000000000002`
- impl: `0x4A5AE0837cfb6C40c7DaF0885ac6c35e2EE644f1`
- owner: `0x95F6077C7786a58FA070D98043b16DF2B1593D2b`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 10, 2024 at commit `d5965bb`
  - upgraded on Aug 26, 2024 at commit `4e08881`

### erc721_vault

- proxy: `0x1670090000000000000000000000000000000003`
- impl: `0x2DdAad1110F2F69238Eb834851437fc05DAb62b9`
- owner: `0x95F6077C7786a58FA070D98043b16DF2B1593D2b`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 10, 2024 at commit `d5965bb`
  - upgraded on Aug 26, 2024 at commit `4e08881`

### erc1155_vault

- proxy: `0x1670090000000000000000000000000000000004`
- impl: `0x58366150b4E1B18dd0D3F043Ba45a9BECb53cd85`
- owner: `0x95F6077C7786a58FA070D98043b16DF2B1593D2b`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 10, 2024 at commit `d5965bb`
  - upgraded on Aug 26, 2024 at commit `4e08881`

### signal_service

- proxy: `0x1670090000000000000000000000000000000005`
- impl: `0x8b3b59d3e9d15f01cbB24c08140E17854dB1e66d`
- owner: `0x95F6077C7786a58FA070D98043b16DF2B1593D2b`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 10, 2024 at commit `d5965bb`
  - upgraded on Mar 21, 2025 at commit `80baf41`
  - upgraded on Apr 3, 2025 at commit `2879728`

### shared_address_manager

- proxy: `0x1670090000000000000000000000000000000006`
- impl: `0x1063F4cF9eaAA67B5dc9750d96eC0BD885D10AeE`
- owner: `0x95F6077C7786a58FA070D98043b16DF2B1593D2b`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 10, 2024 at commit `d5965bb`
  - upgraded on Sep 20, 2024 at commit `fd1c039`
  - upgraded on Oct 29, 2024 at commit `3d12cb2`

### shared_resolver
- proxy: `0xF2880d5F0dF947Ab5A08B43D0b6B2841757CB25e`
- impl: `0x823904Ab163192661e9f9e95b43351cD38319F28`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Apr 3, 2025 at commit `2879728`

### taikoAnchor

- proxy: `0x1670090000000000000000000000000000010001`
- impl: `0x9BB991379a558bB9C24Da18586275Ad09eD6a883`
- owner: `0x95F6077C7786a58FA070D98043b16DF2B1593D2b`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 10, 2024 at commit `d5965bb`
  - upgraded on Sep 20, 2024 at commit `fd1c039`
  - upgraded on Oct 29, 2024 at commit `3d12cb2`
  - upgraded on Mar 24, 2025 at commit `80baf41`
  - upgraded on Apr 3, 2025 at commit `2879728`

### rollup_address_manager

- proxy: `0x1670090000000000000000000000000000010002`
- impl: `0x1063F4cF9eaAA67B5dc9750d96eC0BD885D10AeE`
- owner: `0x95F6077C7786a58FA070D98043b16DF2B1593D2b`
- logs:
  - upgraded on May 10, 2024 at commit `4903bec`
  - upgraded on Jun 10, 2024 at commit `d5965bb`
  - upgraded on Sep 20, 2024 at commit `fd1c039`
  - upgraded on Oct 29, 2024 at commit `3d12cb2`

### rollup_resolver
- proxy: `0x4a10e91F528F1EeA44C6E5744607BB5F3904d539`
- impl: `0x76a5bfbfe60DBdDBeaB5048efeaADcfACD66f621`
- owner: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Apr 3, 2025 at commit `2879728`

### bridged_erc20

- impl: `0x1BAF1AB3686Ace2fD47E11Ac627F3Cc626aEc0FF`
- logs:
  - deployed on May 10, 2024 at commit `4903bec`
  - deployed on Jul 25, 2024 at commit `3d89d24`
  - upgraded on Oct 29, 2024 at commit `3d12cb2`

### bridged_erc721

- impl: `0x45327BDbe23c1a3F0b437C78a19E813f9b11E566`
- logs:
  - deployed on May 10, 2024 at commit `4903bec`

### bridged_erc1155

- impl: `0xb190786090Fc4308c4C40808f3bEB55c4463c152`
- logs:
  - deployed on May 10, 2024 at commit `4903bec`

### delegate_owner

- proxy: `0x95F6077C7786a58FA070D98043b16DF2B1593D2b`
- impl: `0xcdf48A1326542F647A8250356506c0a75AB34CE2`
- owner: `0x95F6077C7786a58FA070D98043b16DF2B1593D2b`
- admin: `0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190`
- logs:
  - deployed on Aug 15, 2024 at commit `46a3e00`
  - upgraded on Mar 24, 2025 at commit `80baf41`
