# Taiko Mainnet Contract Logs - L1

## Notes

1. Code used on mainnet must correspond to a commit on the main branch of the official repo: https://github.com/taikoxyz/taiko-mono.

## Shared

#### shared_address_manager (sam)

- ens: `sam.based.taiko.eth`
- proxy: `0xEf9EaA1dd30a9AA1df01c36411b5F082aA65fBaa`
- impl: `0x9496502d7D121B3D5eF25cA6c58d4f7593398a17`
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
  - bridged_erc20: `0x79BC0Aada00fcF6E7AB514Bfeb093b5Fae3653e3`
  - bridged_erc721: `0xC3310905E2BC9Cfb198695B75EF3e5B69C6A1Bf7`
  - bridged_erc1155: `0x3c90963cFBa436400B0F9C46Aa9224cB379c2c40`
  - quota_manager: `0x91f67118DD47d502B1f0C354D0611997B022f29E`
  - bridge_watchdog: `0x00000291ab79c55dc4fcd97dfba4880df4b93624`
- logs:
  - deployed on May 1, 2024 @commit`56dddf2b6`
  - admin.taiko.eth accepted the ownership @tx`0x0ed114fee6de4e3e2206cea44e6632ec0c4588f73648d98d8df5dc0183b07885`
  - Upgraded from `0x9cA1Ab10c9fAc5153F8b78E67f03aAa69C9c6A15` to `0xF1cA1F1A068468E1dcF90dA6add185467de80943` @commit`b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`
  - `Init2()` called @tx`0x7311fee56f87294e336393b55939489bc1e810c402f304013475d04c90ca32a9`
  - Upgraded from `0xF1cA1F1A068468E1dcF90dA6add185467de80943` to `0x9496502d7D121B3D5eF25cA6c58d4f7593398a17` @commit`e79a367ad` @tx`0xe1ef58455de0b0331228e487d54720290ed8a73f709d2146bd43330d4a360bd3`

#### taiko_token

- ens: `token.taiko.eth`
- proxy: `0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800`
- impl: `0xcfe803378D79d1180EbF030455040EA6513869dF`
- owner: `admin.taiko.eth`
- logs:
  - deployed on April 25, 2024 @commit`2f6d3c62e`
  - upgraded impl from `0x9ae1a067f9655dd0511390e3d70bb25933ae61eb` to `0xea53c0f4b129Cf3f3FBA896F9f23ca18246e9B3c` @commit`b90b932` and,
  - Changed owner from `labs.taiko.eth` to `admin.taiko.eth` @tx`0x7d82794932540ed9edd259e58f6ef8ae21a49beada7f0224638f888f7149c01c`
  - Accept owner @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`
  - upgraded impl from `0xea53c0f4b129Cf3f3FBA896F9f23ca18246e9B3c` to `0x55833dA2962c2330ccCF043ff8037e6D2939bCF6` @commit`2b483de` @tx`0x0bbf7d1258c646f41a02a92a55825b1ebfd3659577d0f2b57b462f8895e23a04`
  - upgraded impl from `0x55833dA2962c2330ccCF043ff8037e6D2939bCF6` to `0xcfe803378D79d1180EbF030455040EA6513869dF` @commit`d2b00ce` @tx`0xc9f468d33d8d55911e4e5b5c301ed244a5f81ab0f389d2b4f398eb5b89d417ef`

#### signal_service

- ens: `signals.based.taiko.eth`
- proxy: `0x9e0a24964e5397B566c1ed39258e21aB5E35C77C`
- impl: `0xB11Cd7bA46a12F238b4Ad831f6F296262C1e652d`
- owner: `admin.taiko.eth`
- logs:
  - deployed on May 1, 2024 @commit`56dddf2b6`
  - admin.taiko.eth accepted the ownership @tx`0x0ed114fee6de4e3e2206cea44e6632ec0c4588f73648d98d8df5dc0183b07885`
  - upgraded from `0xE1d91bAE44B70bD66e8b688B8421fD62dcC33c72` to `0xB11Cd7bA46a12F238b4Ad831f6F296262C1e652d` @commit`b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`
  - upgraded from `0xB11Cd7bA46a12F238b4Ad831f6F296262C1e652d` to `0x3d59c18b31A7D950EF9bd15eD285b6c182E0f0bb` @commit`a3faee0` @tx`eth:0x40A2aCCbd92BCA938b02010E17A5b8929b49130D`
  - restored from `0xB11Cd7bA46a12F238b4Ad831f6F296262C1e652d` to `0xB11Cd7bA46a12F238b4Ad831f6F296262C1e652d` @commit`b90b932` @tx`0xdb5e926c96d112ce1389da77a927fba6c7d04a711839b9e14777530ebcf83914`

#### bridge

- ens: `bridge.based.taiko.eth`
- proxy: `0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC`
- impl: `0x01E7D369a619eF1B0E92563d8737F42C09789986`
- owner: `admin.taiko.eth`
- logs:
  - deployed on May 1, 2024 @commit`56dddf2b6`
  - admin.taiko.eth accepted the ownership @tx`0x0ed114fee6de4e3e2206cea44e6632ec0c4588f73648d98d8df5dc0183b07885`
  - upgraded from `0x91d593d34f2E1904cDCe3D5290a74563F87bCF6f` to `0x4A1091c2fb37D9C4a661c2384Ff539d94CCF853D` @commit`b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`
  - upgraded from `0x4A1091c2fb37D9C4a661c2384Ff539d94CCF853D` to `0xc71CC3B0a47149878fad337fb2ca54E546A645ba` @commit`b955e0e` @tx`0x5a60c5815947a199cc84e1bc75539e01a202597b20c1f87bd9d02f8be6453abd`
  - called `selfDelegate` for Taiko Token @tx`0x740c255322873b3feb62ad1de71b51417053787328eae3aa84557c953463d55f`
  - upgraded from `0xc71CC3B0a47149878fad337fb2ca54E546A645ba` to `0x02F21B4C3d4dbfF70cE851741175a727c8D782Be` @commit`fa481c1` in @tx`0x02ed558762eae5f0a930ba4a1047a02d4a793ea48890268c32df04e882f138ff`
  - unpaused on 27 May, 2024 @tx`0x71ce1e61f1e42e34c9a51f5671ac260f2ac398e016ae645f2661f074e7f230ce`
  - upgraded from `0x02F21B4C3d4dbfF70cE851741175a727c8D782Be` to `0x71c2f41AEDe913AAEf2c62596E03702E348D6Cd0.` @commit`` in @tx`0x8a380a25d03a740d9535dfc3e2fc4f6960e22d49ad88b8d85f59af4013aedf87`
  - upgrade impl to `0x951B7Ae1bB26d12dB37f01748e8fB62FEf45A8B5` @commit`1bd3285` @tx`0xf21f6bf720767db3bc9b63ef69cacb20340bdedfb6589e6a4d11fe082dfa7bd6`
  - upgrade impl to `0x3c326483EBFabCf3252205f26dF632FE83d11108` @commit`3ae25fd` @tx`0xc0ba6558642b93ee892bee0705dbcfb5130c53637e6266bfa5e3a6501167d6f2`
  - upgrade impl to `0xD28f2c26aD8bA88b0691F6BB41Ff021878052561` @commit`2b483de` @tx`0x0bbf7d1258c646f41a02a92a55825b1ebfd3659577d0f2b57b462f8895e23a04`
  - upgrade impl to `0x01E7D369a619eF1B0E92563d8737F42C09789986` @commit`04d8c87` @tx`0x13f54109cb7f7507ad03562b06ea8d8b472043186e44252302583bc64acfb20b`

#### quota_manager

- proxy: `0x91f67118DD47d502B1f0C354D0611997B022f29E`
- impl: `0xdb627bfD79e81fE42138Eb875287F94FAd5BBc64`
- owner: `admin.taiko.eth`
- quota:
  - Quota Period: 24 hours
  - ETH: 1000 ETH
  - WETH(`0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2`): 1000 ETH
  - TAIKO(`0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800`): 2,000,000
  - USDT(`0xdAC17F958D2ee523a2206206994597C13D831ec7`): 4,000,000
  - USDC(`0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`): 4,000,000
- logs:
  - deployed on May 13, 2024 at commit `b90b932`
  - admin.taiko.eth accepted the ownership @tx`0x2d6ce1781137899f65c1810e42f556c27caa4e9bd13077ba5bc7a9a0975eefcb`
  - upgraded from `0x49c5e5F131314Bb24b17E249960F8B12F925ef22` to `0xdb627bfD79e81fE42138Eb875287F94FAd5BBc64` @commit`a3faee0` @tx`0x8de1631a25b337c1e702f9ce9d9ab8a3b626922441855e959b2d79dae40bd131`

#### erc20_vault

- ens: `v20.based.taiko.eth`
- proxy: `0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab`
- impl: `0xa303784B0557BF1F1FB8b8abEF2B18a005722689`
- owner: `admin.taiko.eth`
- logs:
  - deployed on May 1, 2024 @commit`56dddf2b6`
  - upgraded from `0x15D9F7e12aEa18DAEF5c651fBf97567CAd4a4BEc` to `0xC722d9f3f8D60288589F7f67a9CFAd34d3B9bf8E` @commit`b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`
  - upgraded from `0xC722d9f3f8D60288589F7f67a9CFAd34d3B9bf8E` to `0x4F750D13005444407D44dAA30922128db0374ca1` @commit`fa481c1` @tx`0x02ed558762eae5f0a930ba4a1047a02d4a793ea48890268c32df04e882f138ff`
  - upgraded from `0x4F750D13005444407D44dAA30922128db0374ca1` to `0xF8bdaC4E68bA2595Be8381aaa5456917e374E737` @commit`d907359` @tx`0xdb5e926c96d112ce1389da77a927fba6c7d04a711839b9e14777530ebcf83914`
  - upgraded from `0xF8bdaC4E68bA2595Be8381aaa5456917e374E737` to `0xa303784B0557BF1F1FB8b8abEF2B18a005722689` @commit`04d8c87` @tx`0x13f54109cb7f7507ad03562b06ea8d8b472043186e44252302583bc64acfb20b`

#### erc721_vault

- ens: `v721.based.taiko.eth`
- proxy: `0x0b470dd3A0e1C41228856Fb319649E7c08f419Aa`
- impl: `0x55B5df6B53466446221180498BfD1C59e54732c4`
- owner: `admin.taiko.eth`
- logs:
  - deployed on May 1, 2024 @commit`56dddf2b6`
  - upgraded from `0xEC04849E7722Fd69797a155796Db75aC8F94f692` to `0x41A7BDD153a5AfFb10Ed1AD3D6a4e5ad001495FA` @commit`b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`
  - upgraded from `0x41A7BDD153a5AfFb10Ed1AD3D6a4e5ad001495FA` to `0x2dfef0339009Ce10786fc118C883BB97af3163eD` @commit`fa481c1` @tx`0x02ed558762eae5f0a930ba4a1047a02d4a793ea48890268c32df04e882f138ff`
  - upgraded from `0x2dfef0339009Ce10786fc118C883BB97af3163eD` to `0x55B5df6B53466446221180498BfD1C59e54732c4` @commit`d907359` @tx`0xdb5e926c96d112ce1389da77a927fba6c7d04a711839b9e14777530ebcf83914`

#### erc1155_vault

- ens: `v1155.based.taiko.eth`
- proxy: `0xaf145913EA4a56BE22E120ED9C24589659881702`
- impl: `0xca92880829139b310B6b0CB41f66D566Db1a59C8`
- owner: `admin.taiko.eth`
- logs:
  - deployed on May 1, 2024 @commit`56dddf2b6`
  - upgraded from `0x7748dA086A2e6EDd8Db97eD236840910013c6396` to `0xd90b5fcf8d00d333d107E4Ab7F94c0c0A41CDcfE` @commit`b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`
  - upgraded from `0xd90b5fcf8d00d333d107E4Ab7F94c0c0A41CDcfE` to `0x097BBBef669AaD66030aB223195D200eF9A47dc3` @commit`fa481c1` @tx`0x02ed558762eae5f0a930ba4a1047a02d4a793ea48890268c32df04e882f138ff`
  - upgraded from `0x097BBBef669AaD66030aB223195D200eF9A47dc3` to `0xca92880829139b310B6b0CB41f66D566Db1a59C8` @commit`d907359` @tx`0xdb5e926c96d112ce1389da77a927fba6c7d04a711839b9e14777530ebcf83914`

#### bridged_erc20

- impl: `0x79BC0Aada00fcF6E7AB514Bfeb093b5Fae3653e3`
- logs:
  - deployed on May 1, 2024 @commit`56dddf2b6`

#### bridged_erc721

- impl: `0xC3310905E2BC9Cfb198695B75EF3e5B69C6A1Bf7`
- logs:
  - deployed on May 1, 2024 @commit`56dddf2b6`

#### bridged_erc1155

- impl: `0x3c90963cFBa436400B0F9C46Aa9224cB379c2c40`
- logs:
  - deployed on May 1, 2024 @commit`56dddf2b6`

## Rollup Specific

#### rollup_address_manager (ram)

- ens: `ram.based.taiko.eth`
- proxy: `0x579f40D0BE111b823962043702cabe6Aaa290780`
- impl: `0x29a88d60246C76E4F28806b9C8a42d2183154900`
- names:
  - taiko_token: `0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800`
  - signal_service: `0x9e0a24964e5397B566c1ed39258e21aB5E35C77C`
  - bridge: `0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC`
  - taiko: `0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a`
  - tier_router: `0x6e997f1f22c40ba37f633b08f3b07e10ed43155a`
  - tier_sgx: `0xb0f3186FC1963f774f52ff455DC86aEdD0b31F81`
  - tier_guardian_minority: `0x579A8d63a2Db646284CBFE31FE5082c9989E985c`
  - tier_guardian: `0xE3D777143Ea25A6E031d1e921F396750885f43aC`
  - automata_dcap_attestation: `0x8d7C954960a36a7596d7eA4945dDf891967ca8A3`
  - prover_set: `0x518845daA8870bE2C59E49620Fc262AD48953C9a`
  - proposer_one: `0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045` vitalik.eth
  - proposer: `0x000000633b68f5d8d3a86593ebb815b4663bcbe0`
  - chain_watchdog: `0xE3D777143Ea25A6E031d1e921F396750885f43aC`
- logs:
  - deployed on May 1, 2024 @commit`56dddf2b6`
  - admin.taiko.eth accepted the ownership @tx`0x0ed114fee6de4e3e2206cea44e6632ec0c4588f73648d98d8df5dc0183b07885`
  - Upgraded from `0xd912aB787624c9eb96a37e658e9596e114360440` to `0xF1cA1F1A068468E1dcF90dA6add185467de80943` @commit`b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`
  - `Init2()` called @tx`0x7311fee56f87294e336393b55939489bc1e810c402f304013475d04c90ca32a9`
  - register `chain_watchdog` on May 21 @tx`0xaed098ad0c93113e401f61358f963501f40a046c5b5b659a1610f10120a9a86b`
  - register `prover_set` to `0x34f2B21107AfE3584949c184A1E6236FFDAC4f6F` @tx`0x252cd7fcb6e02a71c0770d00f2f2476d5dd469a4fb5df622fe7bf6280d8a4100`
  - register `prover_set` to `0x500735343372Dd6c9B84dBc7a75babf4479742B9` @commit`fa481c1` @tx`0x02ed558762eae5f0a930ba4a1047a02d4a793ea48890268c32df04e882f138ff`
  - upgraded from `0xF1cA1F1A068468E1dcF90dA6add185467de80943` to `0x8Af4669E3068Bae96b92cD73603f5D86beD07a9a` @commit`e79a367ad` @tx`0xe1ef58455de0b0331228e487d54720290ed8a73f709d2146bd43330d4a360bd3`
  - register `tier_router` to `0xa8e5D3a2E2052bea7f10bE6a0386454b721d1f9F` and unregister `tier_provider` @tx`0x2c455ae888a23c232bb5c7603657eda010ffadc602a74e626332bc06eaaa3b78`
  - upgraded from `0x8Af4669E3068Bae96b92cD73603f5D86beD07a9a` to `0x8EEf314878A7E56314E8DF285d0B0D649C903aF6` @commit`a3faee0` @tx`eth:0x40A2aCCbd92BCA938b02010E17A5b8929b49130D`
  - register `prover_set` to `0xd0AEe97712a4a88B75C31E3C61DD2Ce6E514D85F` @tx`0xb23d9cec24a1cc14956482d9d6a77eee0d6ab6ccd5b77e2be191fb8368c2d107`
  - unregister `assignment_hook` @tx`0xb23d9cec24a1cc14956482d9d6a77eee0d6ab6ccd5b77e2be191fb8368c2d107`
  - register `prover_set` to `0x5D528253fA14cd7F637937de847BE8D5BE0Bf5fd` @commit`2b483de` @tx`0x0bbf7d1258c646f41a02a92a55825b1ebfd3659577d0f2b57b462f8895e23a04`
  - register `tier_router` to `0x6e997f1f22c40ba37f633b08f3b07e10ed43155a` @tx`0x13f54109cb7f7507ad03562b06ea8d8b472043186e44252302583bc64acfb20b`
  - Upgraded from `0x8EEf314878A7E56314E8DF285d0B0D649C903aF6` to `0x29a88d60246C76E4F28806b9C8a42d2183154900` @commit`57c8dc0` @tx`0x9f787086b4c5e6887eb1d27c286069bcbbcabb1d7ed9f69ab3121c4681cf4b2c`
  - register `prover_set` to `0x518845daA8870bE2C59E49620Fc262AD48953C9a` @commit`67a7a37` @tx`0xc1f91c375713f601b99cf6d2cdb80c129e036a7c9ec5f75871c4d13216dbbb5c`

#### taikoL1

- ens: `based.taiko.eth`
- proxy: `0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a`
- impl: `0xcEe590fACd976B9BDE87BC1B7620B284c5edD2C3`
- owner: `admin.taiko.eth`
- logs:
  - deployed on May 1, 2024 @commit`56dddf2b6`
  - Upgraded from `0x99Ba70E62cab0cB983e66F72330fBDDC11d85501` to `0x9fBBedBBcBb753E7214BE08381efE10d89D712fE` @commit`b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`
  - `Init2()` called and reset block hash to `0411D9F84A525864E0A7E8BB51667D49C6BF73820AF9E4BC76EA66ADB6BE8903` @tx`0x7311fee56f87294e336393b55939489bc1e810c402f304013475d04c90ca32a9`
  - Upgraded from `0x9fBBedBBcBb753E7214BE08381efE10d89D712fE` to `0xe0A5D394878723CEAEC8B993e04756DF1f4B44eF` on May 21 @commit`c817e76d9` @tx`0xaed098ad0c93113e401f61358f963501f40a046c5b5b659a1610f10120a9a86b`
  - `resetGenesisHash()` called to reset genesis block hash to `0x90bc60466882de9637e269e87abab53c9108cf9113188bc4f80bcfcb10e489b9` on May 22 @tx`0x5a60c5815947a199cc84e1bc75539e01a202597b20c1f87bd9d02f8be6453abd`
  - Upgraded from `0xe0A5D394878723CEAEC8B993e04756DF1f4B44eF` to `0xa200c2268d77737a8Fd2CA1698dA6eeab2a85CEb` on May 27 @commit`06f97d6` @tx`0x187cc99e9bcf2a94f723cf52d85b74b79bdb3872681e2a3808cadbbc3ba301e2`
  - Upgraded from `0xa200c2268d77737a8Fd2CA1698dA6eeab2a85CEb` to `0x3505a0700DB72dEc7AbFF1aF231BB5D87aBF2944` on May 28 @commit`b335b70` @tx`0xa603b6d55457e64e18ddae684bfd14948452cdd7b927dd22bf0b83045e8fd028`
  - Upgrade to `0xE84DC8E2a21e59426542Ab040D77f81d6dB881eE` @commit`3ae25fd` @tx`0x2c455ae888a23c232bb5c7603657eda010ffadc602a74e626332bc06eaaa3b78`
  - Upgrade to `0x4b2743B869b85d5F7D8020566f92664995E4f3c5` @commit`a3faee0` @tx`eth:0x40A2aCCbd92BCA938b02010E17A5b8929b49130D`
  - Upgrade to `0x0468745A07de44A9a3138adAc35875ecaf7a20D5` @commit`2b483de` @tx`0x0bbf7d1258c646f41a02a92a55825b1ebfd3659577d0f2b57b462f8895e23a04`
  - Upgrade to `0xB9E1E58bcF33B79CcfF99c298963546a6c334388` @commit`d907359` @tx`0xdb5e926c96d112ce1389da77a927fba6c7d04a711839b9e14777530ebcf83914`
  - Upgrade to `0x5fc54737ECC1de49D58AE1195d4A296257F1E31b` @commit`04d8c87` @tx`0x13f54109cb7f7507ad03562b06ea8d8b472043186e44252302583bc64acfb20b`
  - Upgrade to `0xcEe590fACd976B9BDE87BC1B7620B284c5edD2C3` @commit`2dd30ab` @tx`0xc1f91c375713f601b99cf6d2cdb80c129e036a7c9ec5f75871c4d13216dbbb5c`

#### assignment_hook

- proxy: `0x537a2f0D3a5879b41BCb5A2afE2EA5c4961796F6`
- impl: `0xf77CBFAfE15Df84E6638dF267D25d1AF8e5e53f2`
- owner: `admin.taiko.eth`
- logs:
  - deployed on May 1, 2024 @commit`56dddf2b6`
  - Upgraded from `0x4f664222C3fF6207558A745648B568D095dDA170` to `0xe226fAd08E2f0AE68C32Eb5d8210fFeDB736Fb0d` @commit`b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`
  - Upgraded from `0xe226fAd08E2f0AE68C32Eb5d8210fFeDB736Fb0d` to `0xf77CBFAfE15Df84E6638dF267D25d1AF8e5e53f2` @commit`2b483de` @tx`0x0bbf7d1258c646f41a02a92a55825b1ebfd3659577d0f2b57b462f8895e23a04`

#### tier_provider

- impl: `0x3a1A900680BaADb889202faf12915F7E47B71ddd`
- logs:
  - deployed on May 1, 2024 @commit`56dddf2b6`
  - deployed on May 15, 2024 @commit`cd5144255`
  - deployed on Jul 2, 2024 @commit`d2b00ce`

#### tier_sgx

- proxy: `0xb0f3186FC1963f774f52ff455DC86aEdD0b31F81`
- impl: `0xB0b782cf0fCEce896E0C041F8e54f86cA4cC8e9F`
- owner: `admin.taiko.eth`
- logs:
  - deployed on May 1, 2024 @commit`56dddf2b6`
  - Upgraded from `0x3f54067EF5d8B414Bdb1945cdF482BD158Aad175` to `0xf381868DD6B2aC8cca468D63B42F9040DE2257E9` @commit`b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`
  - Upgraded from `0xf381868DD6B2aC8cca468D63B42F9040DE2257E9` to `0xB0b782cf0fCEce896E0C041F8e54f86cA4cC8e9F` @commit`a3faee0` @tx`eth:0x40A2aCCbd92BCA938b02010E17A5b8929b49130D`

#### guardian_prover_minority

- ens: `guardians1.based.taiko.eth`
- proxy: `0x579A8d63a2Db646284CBFE31FE5082c9989E985c`
- impl: `0x7E717FFD6f7dD1008192bDC7193904FaB25BC8A4`
- owner: `admin.taiko.eth`
- guardianProvers:
  - `0x000012dd12a6d9dd2045f5e2594f4996b99a5d33`
  - `0x0cAC6E2Fd10e92Bf798341Ad0A57b5Cb39DA8D0D`
  - `0xd6BB974bc47626E3547426efa4CA2A8d7DFCccdf`
  - `0xd26c4e85BC2fAAc27a320987e340971cF3b47d51`
  - `0xC384B679c028787166b9B3725aC14A60da205861`
  - `0x1602958A85494cd9C3e0D6672BA0eE42b95B4200`
  - `0x5CfEb9a72256B1b49dc2C98b1b7b99d172D50B68`
  - `0x1DB8Ac9f19AbdD60A6418383BfA56A4450aa80C6`
- minGuardiansReached: `1`
- logs:
  - deployed on May 1, 2024 @commit`56dddf2b6`
  - admin.taiko.eth accepted the ownership @tx`0x0ed114fee6de4e3e2206cea44e6632ec0c4588f73648d98d8df5dc0183b07885`
  - Upgraded from `0x717DC5E3814591790BcB1fD9259eEdA7c14ce9CF` to `0x750221E951b77a2Cb4046De41Ec5F6d1aa7942D2` @commit`b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`
  - Upgraded from `0x750221E951b77a2Cb4046De41Ec5F6d1aa7942D2` to `0x253E47F2b1e91F2001d3578aeB24C0ccF464b65e` @commit`cd5144255` @tx`0x8030569e293baddbc4e8b26688a1ecf14a231d86c90e9d02dad1e919ea2f3964`
  - Upgraded from `0x253E47F2b1e91F2001d3578aeB24C0ccF464b65e` to `0x468F6A9C0ad2e9C8370687D2844A9e70fE942d5c` @commit`b955e0e` @tx`0x5a60c5815947a199cc84e1bc75539e01a202597b20c1f87bd9d02f8be6453abd`
  - Upgraded from `0x468F6A9C0ad2e9C8370687D2844A9e70fE942d5c` to `0x7E717FFD6f7dD1008192bDC7193904FaB25BC8A4.` @commit`8a27cbe` @tx`eth:0x40A2aCCbd92BCA938b02010E17A5b8929b49130D`

#### guardian_prover

- ens: `guardians.based.taiko.eth`
- proxy: `0xE3D777143Ea25A6E031d1e921F396750885f43aC`
- impl: `0x7E717FFD6f7dD1008192bDC7193904FaB25BC8A4`
- owner: `admin.taiko.eth`
- guardianProvers:
  - `0x000012dd12a6d9dd2045f5e2594f4996b99a5d33`
  - `0x0cAC6E2Fd10e92Bf798341Ad0A57b5Cb39DA8D0D`
  - `0xd6BB974bc47626E3547426efa4CA2A8d7DFCccdf`
  - `0xd26c4e85BC2fAAc27a320987e340971cF3b47d51`
  - `0xC384B679c028787166b9B3725aC14A60da205861`
  - `0x1602958A85494cd9C3e0D6672BA0eE42b95B4200`
  - `0x5CfEb9a72256B1b49dc2C98b1b7b99d172D50B68`
  - `0x1DB8Ac9f19AbdD60A6418383BfA56A4450aa80C6`
- minGuardiansReached: `6`
- logs:
  - deployed on May 1, 2024 @commit`56dddf2b6`
  - Upgraded from `0x717DC5E3814591790BcB1fD9259eEdA7c14ce9CF` to `0x750221E951b77a2Cb4046De41Ec5F6d1aa7942D2` @commit`b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`
  - Upgraded from `0x750221E951b77a2Cb4046De41Ec5F6d1aa7942D2` to `0x253E47F2b1e91F2001d3578aeB24C0ccF464b65e` @commit`cd5144255` @tx`0x8030569e293baddbc4e8b26688a1ecf14a231d86c90e9d02dad1e919ea2f3964`
  - Upgraded from `0x253E47F2b1e91F2001d3578aeB24C0ccF464b65e` to `0x468F6A9C0ad2e9C8370687D2844A9e70fE942d5c` @commit`b955e0e` @tx`0x5a60c5815947a199cc84e1bc75539e01a202597b20c1f87bd9d02f8be6453abd`
  - Upgraded from `0x468F6A9C0ad2e9C8370687D2844A9e70fE942d5c` to `0x7E717FFD6f7dD1008192bDC7193904FaB25BC8A4.` @commit`8a27cbe` @tx`eth:0x40A2aCCbd92BCA938b02010E17A5b8929b49130D`

#### p256_verifier

- impl: `0x11A9ebA17EbF92b40fcf9a640Ebbc47Db6fBeab0`
- logs:
  - deployed on May 1, 2024 @commit`56dddf2b6`

#### sig_verify_lib

- impl: `0x47bB416ee947fE4a4b655011aF7d6E3A1B80E6e9`
- logs:
  - deployed on May 1, 2024 @commit`56dddf2b6`

#### pem_cert_chain_lib

- impl: `0x02772b7B3a5Bea0141C993Dbb8D0733C19F46169`
- logs:
  - deployed on May 1, 2024 @commit`56dddf2b6`

#### automata_dcap_attestation

- proxy: `0x8d7C954960a36a7596d7eA4945dDf891967ca8A3`
- impl: `0x5f73f0AdC7dAA6134Fe751C4a78d524f9384e0B5`
- owner: `admin.taiko.eth`
- logs:
  - deployed on May 1, 2024 @commit`56dddf2b6`
  - Upgraded from `0xEE8FC1dbb8D345f5bF35dFb939C6f9EdC5fCDAFc` to `0xde1b1FBe7D721af4A56651272ef91A59B7303323` @commit`b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`
  - Called `configureTcbInfoJson` and `configureQeIdentityJson` @commit`b90b932` @tx`0x2d6ce1781137899f65c1810e42f556c27caa4e9bd13077ba5bc7a9a0975eefcb`
  - Called `configureTcbInfoJson` and `configureQeIdentityJson` @commit`cd5144255` @tx`0x8030569e293baddbc4e8b26688a1ecf14a231d86c90e9d02dad1e919ea2f3964`
  - Upgraded from `0xde1b1FBe7D721af4A56651272ef91A59B7303323` to `0x5f73f0AdC7dAA6134Fe751C4a78d524f9384e0B5` @commit`3740dc0` @tx`0x46a6d47c15505a1259c64d1e09353680e525b2706dd9e095e15019dda7c1b295`
  - Called `configureTcbInfoJson` @commit`3740dc0` @tx`0x46a6d47c15505a1259c64d1e09353680e525b2706dd9e095e15019dda7c1b295`
  - Update mrenclave & mrsign on May 28, 2024 @commit`b335b70` @tx`0x6a240314c6a48f3ab58e0a3d5bf0e915668dac5eec19c694656eeb3d66c12465`

### token_unlock

- impl: `0x035AFfC82612de31E9Db2259B9482D0Dd53B7819`
- logs:
  - deployed @commit`bca493f` @tx`0x0a4a63715257b766ca06e7e87ee25088d557c460e50120208b31666c83fc68bc`

### prover_set

- impl: `0x518845daA8870bE2C59E49620Fc262AD48953C9a`
- logs:
  - deployed @commit`bca493f` @tx`0xfacd0f26e3ec4bf1f949637373483fcfe9a960dfc427d6fa62b116907bac3373`
  - deployed @commit`2dd30ab` @tx`0xc1f91c375713f601b99cf6d2cdb80c129e036a7c9ec5f75871c4d13216dbbb5c`

### labprover.taiko.eth

- ens: `labprover.taiko.eth`
- proxy: `0x68d30f47F19c07bCCEf4Ac7FAE2Dc12FCa3e0dC9`
- impl: `0x518845daA8870bE2C59E49620Fc262AD48953C9a`
- enabled provers:
  - `0x000000629FBCf27A347d1AEbA658435230D74a5f`
  - `0x000000633b68f5d8d3a86593ebb815b4663bcbe0`
- logs:
  - deployed @commit`bca493f`@tx`0xf3b6af477112d0a8209506c8f310f4eb0713beebb1911ef5d11162d36d93c0ff`
  - enabled two provers (`0x000000629FBCf27A347d1AEbA658435230D74a5f` and `0x00000027F51a57E7FcBC4b481d15fcE5BE68b30B`) @tx`0xa0b1565473849bc753d395abd982e6899ecdd9e754014eebed67b69edadb61c5`
  - upgraded from `0x68d30f47F19c07bCCEf4Ac7FAE2Dc12FCa3e0dC9` to `0x500735343372Dd6c9B84dBc7a75babf4479742B9` @commit`fa481c1` @tx`0x02ed558762eae5f0a930ba4a1047a02d4a793ea48890268c32df04e882f138ff`
  - disable a prover (`0x00000027F51a57E7FcBC4b481d15fcE5BE68b30B`) on May 28 @commit`b335b70` @tx`0x27c84a1dbf80d88948f96f1536c244816543fb780c81a04ba485c4c156431112`
  - upgraded from `0x500735343372Dd6c9B84dBc7a75babf4479742B9` to `0xd0AEe97712a4a88B75C31E3C61DD2Ce6E514D85F` @commit`a3faee0` @tx`eth:0x40A2aCCbd92BCA938b02010E17A5b8929b49130D`
  - upgraded from `0xd0AEe97712a4a88B75C31E3C61DD2Ce6E514D85F` to `0x5D528253fA14cd7F637937de847BE8D5BE0Bf5fd` @commit`2b483de` @tx`0x0bbf7d1258c646f41a02a92a55825b1ebfd3659577d0f2b57b462f8895e23a04`
  - upgraded from `0x5D528253fA14cd7F637937de847BE8D5BE0Bf5fd` to `0xD547Ca5d6b50dC5E900a091978597eB51F18F9D1` @commit`d907359` @tx`0xb4c23d57a1f0916180d0752c57726b634e7707bb7377c93d9e95d19e3695887a`
  - enabled a prover (`0x000000633b68f5d8d3a86593ebb815b4663bcbe0`) @tx`0xb4c23d57a1f0916180d0752c57726b634e7707bb7377c93d9e95d19e3695887a`
  - upgraded from `0xD547Ca5d6b50dC5E900a091978597eB51F18F9D1` to `0x518845daA8870bE2C59E49620Fc262AD48953C9a` @commit`2dd30ab` @tx`0xc1f91c375713f601b99cf6d2cdb80c129e036a7c9ec5f75871c4d13216dbbb5c`

### labcontester.taiko.eth

- ens: `labcontester.taiko.eth`
- proxy: `0xa01d464ca3982DAa97B19fa7F8a232eB11A9DDb3`
- impl: `0x518845daA8870bE2C59E49620Fc262AD48953C9a`
- enabled provers:
  - `0x00000027F51a57E7FcBC4b481d15fcE5BE68b30B`
- logs:
  - enabled a prover (`0x00000027F51a57E7FcBC4b481d15fcE5BE68b30B`) on May 28 @commit`b335b70` @tx`0x27c84a1dbf80d88948f96f1536c244816543fb780c81a04ba485c4c156431112`
  - upgraded from `0x500735343372Dd6c9B84dBc7a75babf4479742B9` to `0xd0AEe97712a4a88B75C31E3C61DD2Ce6E514D85F` @commit`a3faee0` @tx`eth:0x40A2aCCbd92BCA938b02010E17A5b8929b49130D`
  - upgraded from `0xd0AEe97712a4a88B75C31E3C61DD2Ce6E514D85F` to `0x5D528253fA14cd7F637937de847BE8D5BE0Bf5fd` @commit`2b483de` @tx`0x0bbf7d1258c646f41a02a92a55825b1ebfd3659577d0f2b57b462f8895e23a04`
  - upgraded from `0xD547Ca5d6b50dC5E900a091978597eB51F18F9D1` to `0x518845daA8870bE2C59E49620Fc262AD48953C9a` @commit`2dd30ab` @tx`0xc1f91c375713f601b99cf6d2cdb80c129e036a7c9ec5f75871c4d13216dbbb5c`
