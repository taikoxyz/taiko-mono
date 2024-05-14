# Taiko Mainnet Contract Logs

## Notes

1. Code used on mainnet must correspond to a commit on the main branch of the official repo: https://github.com/taikoxyz/taiko-mono.

## L1 Contracts

### Shared

#### shared_address_manager

- proxy: `0xEf9EaA1dd30a9AA1df01c36411b5F082aA65fBaa`
- impl: `0xF1cA1F1A068468E1dcF90dA6add185467de80943`
- owner: `admin.taiko.eth`
- names:
  - taiko_token: `0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800`
  - signal_service: `0x9e0a24964e5397B566c1ed39258e21aB5E35C77C`
  - signal_service@167000: `0x1670000000000000000000000000000000000005`
  - bridge: `0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC`
  - bridge@167000: `0x1670000000000000000000000000000000000001`
  - erc20_vault: `0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab`
  - erc20_vault@167000: `0x1670000000000000000000000000000000000002`
  - erc721_vault: `0x0b470dd3A0e1C41228856Fb319649E7c08f419Aa`
  - erc721_vault@167000: `0x1670000000000000000000000000000000000003`
  - erc1155_vault: `0xaf145913EA4a56BE22E120ED9C24589659881702`
  - erc1155_vault@167000: `0x1670000000000000000000000000000000000004`
  - bridged_erc1155: `0x3c90963cfba436400b0f9c46aa9224cb379c2c40`
  - bridged_erc721: `0xc3310905e2bc9cfb198695b75ef3e5b69c6a1bf7`
  - bridged_erc20: `0x79bc0aada00fcf6e7ab514bfeb093b5fae3653e3`
  - bridge_watchdog: `0x00000291ab79c55dc4fcd97dfba4880df4b93624`
  - quota_manager: `0x91f67118DD47d502B1f0C354D0611997B022f29Es`
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`
  - admin.taiko.eth accepted the ownership @tx`0x0ed114fee6de4e3e2206cea44e6632ec0c4588f73648d98d8df5dc0183b07885`
  - Upgraded from `0x9cA1Ab10c9fAc5153F8b78E67f03aAa69C9c6A15` to `0xF1cA1F1A068468E1dcF90dA6add185467de80943` @commit `b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`
  - `Init2()` called @tx `0x7311fee56f87294e336393b55939489bc1e810c402f304013475d04c90ca32a9`

#### taiko_token

- ens: `token.taiko.eth`
- proxy: `0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800`
- impl: `0xea53c0f4b129Cf3f3FBA896F9f23ca18246e9B3c`
- owner: `admin.taiko.eth`
- logs:
  - deployed on April 25, 2024 @commit `2f6d3c62e`
  - upgraded impl from `0x9ae1a067f9655dd0511390e3d70bb25933ae61eb` to `0xea53c0f4b129Cf3f3FBA896F9f23ca18246e9B3c` @commit `b90b932` and,
  - Changed owner from `labs.taiko.eth` to `admin.taiko.eth` @tx `0x7d82794932540ed9edd259e58f6ef8ae21a49beada7f0224638f888f7149c01c`
  - Accept owner @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`

#### signal_service

- proxy: `0x9e0a24964e5397B566c1ed39258e21aB5E35C77C`
- impl: `0xB11Cd7bA46a12F238b4Ad831f6F296262C1e652d`
- owner: `admin.taiko.eth`
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`
  - admin.taiko.eth accepted the ownership @tx`0x0ed114fee6de4e3e2206cea44e6632ec0c4588f73648d98d8df5dc0183b07885`
  - upgraded from `0xE1d91bAE44B70bD66e8b688B8421fD62dcC33c72` to `0xB11Cd7bA46a12F238b4Ad831f6F296262C1e652d` @commit `b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`

#### bridge

- proxy: `0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC`
- impl: `0x4A1091c2fb37D9C4a661c2384Ff539d94CCF853D`
- owner: `admin.taiko.eth`
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`
  - admin.taiko.eth accepted the ownership @tx`0x0ed114fee6de4e3e2206cea44e6632ec0c4588f73648d98d8df5dc0183b07885`
  - upgraded from `0x91d593d34f2E1904cDCe3D5290a74563F87bCF6f` to `0x4A1091c2fb37D9C4a661c2384Ff539d94CCF853D` @commit `b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`

#### quota_manager

- proxy: `0x91f67118DD47d502B1f0C354D0611997B022f29E`
- impl: `0x49c5e5F131314Bb24b17E249960F8B12F925ef22`
- owner: `0x56706F118e42AE069F20c5636141B844D1324AE1`
- owner: `admin.taiko.eth`
- logs:
  - deployed on May 13, 2024 at commit `b90b932`
  - admin.taiko.eth accepted the ownership @tx`0x2d6ce1781137899f65c1810e42f556c27caa4e9bd13077ba5bc7a9a0975eefcb`

#### erc20_vault

- proxy: `0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab`
- impl: `0xC722d9f3f8D60288589F7f67a9CFAd34d3B9bf8E`
- owner: `admin.taiko.eth`
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`
  - upgraded from `0x15D9F7e12aEa18DAEF5c651fBf97567CAd4a4BEc` to `0xC722d9f3f8D60288589F7f67a9CFAd34d3B9bf8E` @commit `b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`

#### erc721_vault

- proxy: `0x0b470dd3A0e1C41228856Fb319649E7c08f419Aa`
- impl: `0x41A7BDD153a5AfFb10Ed1AD3D6a4e5ad001495FA`
- owner: `admin.taiko.eth`
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`
  - upgraded from `0xEC04849E7722Fd69797a155796Db75aC8F94f692` to `0x41A7BDD153a5AfFb10Ed1AD3D6a4e5ad001495FA` @commit `b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`

#### erc1155_vault

- proxy: `0xaf145913EA4a56BE22E120ED9C24589659881702`
- impl: `0xd90b5fcf8d00d333d107E4Ab7F94c0c0A41CDcfE`
- owner: `admin.taiko.eth`
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`
  - upgraded from `0x7748dA086A2e6EDd8Db97eD236840910013c6396` to `0xd90b5fcf8d00d333d107E4Ab7F94c0c0A41CDcfE` @commit `b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`

#### bridged_erc20

- impl: `0xcc5d488073FA918cBbd73B9A523F3858C4de7372`
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`

#### bridged_erc721

- impl: `0xc4096E9ff1526Bd1840B65e9f45695135aC12De7`
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`

#### bridged_erc1155

- impl: `0x39E4C1214e733639d059979079A151911e42791d`
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`

### Rollup Specific

#### rollup_address_manager

- proxy: `0x579f40D0BE111b823962043702cabe6Aaa290780`
- impl: `0xF1cA1F1A068468E1dcF90dA6add185467de80943`
- names:
  - taiko_token: `0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800`
  - signal_service: `0x9e0a24964e5397B566c1ed39258e21aB5E35C77C`
  - bridge: `0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC`
  - taiko: `0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a`
  - tier_provider: `0x33879cDF01121dc7bCe011b461e64d791aE931F2`
  - tier_sgx: `0xb0f3186FC1963f774f52ff455DC86aEdD0b31F81`
  - guardian_prover_minority: `0x579A8d63a2Db646284CBFE31FE5082c9989E985c`
  - tier_guardian_minority: `0x579A8d63a2Db646284CBFE31FE5082c9989E985c`
  - guardian_prover: `0xE3D777143Ea25A6E031d1e921F396750885f43aC`
  - tier_guardian: `0xE3D777143Ea25A6E031d1e921F396750885f43aC`
  - automata_dcap_attestation: `0x8d7C954960a36a7596d7eA4945dDf891967ca8A3`
  - proposer_one: `0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045` vitalik.eth
  - proposer: `0x000000633b68f5d8d3a86593ebb815b4663bcbe0`
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`
  - admin.taiko.eth accepted the ownership @tx`0x0ed114fee6de4e3e2206cea44e6632ec0c4588f73648d98d8df5dc0183b07885`
  - Upgraded from `0xd912aB787624c9eb96a37e658e9596e114360440` to `0xF1cA1F1A068468E1dcF90dA6add185467de80943` @commit `b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`
  - `Init2()` called @tx `0x7311fee56f87294e336393b55939489bc1e810c402f304013475d04c90ca32a9`

#### taikoL1

- proxy: `0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a`
- impl: `0x9fBBedBBcBb753E7214BE08381efE10d89D712fE`
- owner: `admin.taiko.eth`
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`
  - Upgraded from `0x99Ba70E62cab0cB983e66F72330fBDDC11d85501` to `0x9fBBedBBcBb753E7214BE08381efE10d89D712fE` @commit `b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`
  - `Init2()` called and reset block hash to `0411D9F84A525864E0A7E8BB51667D49C6BF73820AF9E4BC76EA66ADB6BE8903` @tx `0x7311fee56f87294e336393b55939489bc1e810c402f304013475d04c90ca32a9`

#### assignment_hook

- proxy: `0x537a2f0D3a5879b41BCb5A2afE2EA5c4961796F6`
- impl: `0xe226fAd08E2f0AE68C32Eb5d8210fFeDB736Fb0d`
- owner: `admin.taiko.eth`
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`
  - Upgraded from `0x4f664222C3fF6207558A745648B568D095dDA170` to `0xe226fAd08E2f0AE68C32Eb5d8210fFeDB736Fb0d` @commit `b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`

#### tier_provider

- proxy: `0x33879cDF01121dc7bCe011b461e64d791aE931F2`
- impl: `0xf8254fd073063C35811577877f840548e77fD52E`
- owner: `admin.taiko.eth`
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`

#### tier_sgx

- proxy: `0xb0f3186FC1963f774f52ff455DC86aEdD0b31F81`
- impl: `0xf381868DD6B2aC8cca468D63B42F9040DE2257E9`
- owner: `admin.taiko.eth`
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`
  - Upgraded from `0x3f54067EF5d8B414Bdb1945cdF482BD158Aad175` to `0xf381868DD6B2aC8cca468D63B42F9040DE2257E9` @commit `b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`

#### guardian_prover_minority

- proxy: `0x579A8d63a2Db646284CBFE31FE5082c9989E985c`
- impl: `0x750221E951b77a2Cb4046De41Ec5F6d1aa7942D2`
- owner: `admin.taiko.eth`
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`
  - admin.taiko.eth accepted the ownership @tx`0x0ed114fee6de4e3e2206cea44e6632ec0c4588f73648d98d8df5dc0183b07885`
  - Upgraded from `0x717DC5E3814591790BcB1fD9259eEdA7c14ce9CF` to `0x750221E951b77a2Cb4046De41Ec5F6d1aa7942D2` @commit `b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`

#### guardian_prover

- proxy: `0xE3D777143Ea25A6E031d1e921F396750885f43aC`
- impl: `0x750221E951b77a2Cb4046De41Ec5F6d1aa7942D2`
- owner: `admin.taiko.eth`
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`
  - Upgraded from `0x717DC5E3814591790BcB1fD9259eEdA7c14ce9CF` to `0x750221E951b77a2Cb4046De41Ec5F6d1aa7942D2` @commit `b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`

#### p256_verifier

- impl: `0x11A9ebA17EbF92b40fcf9a640Ebbc47Db6fBeab0`
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`

#### sig_verify_lib

- impl: `0x47bB416ee947fE4a4b655011aF7d6E3A1B80E6e9`
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`

#### pem_cert_chain_lib

- impl: `0x02772b7B3a5Bea0141C993Dbb8D0733C19F46169`
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`

#### automata_dcap_attestation

- proxy: `0x8d7C954960a36a7596d7eA4945dDf891967ca8A3`
- impl: `0xde1b1FBe7D721af4A56651272ef91A59B7303323`
- owner: `admin.taiko.eth`
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`
  - Upgraded from `0xEE8FC1dbb8D345f5bF35dFb939C6f9EdC5fCDAFc` to `0xde1b1FBe7D721af4A56651272ef91A59B7303323` @commit `b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`
  - Called `configureTcbInfoJson` and `configureQeIdentityJson` @commit `b90b932` @tx`0x2d6ce1781137899f65c1810e42f556c27caa4e9bd13077ba5bc7a9a0975eefcb`

### token_unlocking

- impl: `0x244108e321FE03b0E33FE63Ef62285F05d191a62`
- logs:
  - deployed on May 13, 2024 at commit `165e28279`

## L2 Contracts

### Shared

#### shared_address_manager

- proxy: `0x1670000000000000000000000000000000000006`
- impl: `0x0167000000000000000000000000000000000006`
- owner: `0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be`
- todo:
  - change owner to DelegateOwner
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`

#### bridge

- proxy: `0x1670000000000000000000000000000000000001`
- impl: `0x0167000000000000000000000000000000000001`
- owner: `0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be`
- todo:
  - change owner to DelegateOwner
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`

#### erc20_vault

- proxy: `0x1670000000000000000000000000000000000002`
- impl: `0x0167000000000000000000000000000000000002`
- owner: `0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be`
- todo:
  - change owner to DelegateOwner
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`

#### erc721_vault

- proxy: `0x1670000000000000000000000000000000000003`
- impl: `0x0167000000000000000000000000000000000003`
- owner: `0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be`
- todo:
  - change owner to DelegateOwner
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`

#### erc1155_vault

- proxy: `0x1670000000000000000000000000000000000004`
- impl: `0x0167000000000000000000000000000000000004`
- owner: `0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be`
- todo:
  - change owner to DelegateOwner
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`

#### signal_service

- proxy: `0x1670000000000000000000000000000000000005`
- impl: `0x0167000000000000000000000000000000000005`
- owner: `0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be`
- todo:
  - change owner to DelegateOwner
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`

### Rollup Specific

#### rollup_address_manager

- proxy: `0x1670000000000000000000000000000000010002`
- impl: `0x0167000000000000000000000000000000010002`
- owner: `0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be`
- todo:
  - change owner to DelegateOwner
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`
  - `Init2()` called @tx `0x7311fee56f87294e336393b55939489bc1e810c402f304013475d04c90ca32a9`

#### taikoL2

- proxy: `0x1670000000000000000000000000000000010001`
- impl: `0x0167000000000000000000000000000000010001`
- owner: `0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be`
- todo:
  - change owner to DelegateOwner
- logs:
  - deployed on May 1, 2024 @commit `56dddf2b6`

## Other EOAs/Contracts

- `davidcai.eth`:`0x56706F118e42AE069F20c5636141B844D1324AE1`
- `admin.taiko.eth`: `0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F`
- `labs.taiko.eth`: `0xB73b0FC4C0Cfc73cF6e034Af6f6b42Ebe6c8b49D`
