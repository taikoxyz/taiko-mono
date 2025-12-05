# Taiko Mainnet Contract Logs - L1

## Notes

1. Code used on mainnet must correspond to a commit on the main branch of the official repo: https://github.com/taikoxyz/taiko-mono.

## Shared

#### shared_address_manager (sam)

- ens: `sam.based.taiko.eth`
- proxy: `0xEf9EaA1dd30a9AA1df01c36411b5F082aA65fBaa`
- impl: `0xEC1a9aa1C648F047752fe4eeDb2C21ceab0c6449`
- owner : `controller.taiko.eth`
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
  - bridged_erc20: `0x65666141a541423606365123Ed280AB16a09A2e1`
  - bridged_erc721: `0xC3310905E2BC9Cfb198695B75EF3e5B69C6A1Bf7`
  - bridged_erc1155: `0x3c90963cFBa436400B0F9C46Aa9224cB379c2c40`
  - quota_manager: `0x91f67118DD47d502B1f0C354D0611997B022f29E`
- logs:
  - deployed on May 1, 2024 @commit`56dddf2b6`
  - admin.taiko.eth accepted the ownership @tx`0x0ed114fee6de4e3e2206cea44e6632ec0c4588f73648d98d8df5dc0183b07885`
  - Upgraded from `0x9cA1Ab10c9fAc5153F8b78E67f03aAa69C9c6A15` to `0xF1cA1F1A068468E1dcF90dA6add185467de80943` @commit`b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`
  - `Init2()` called @tx`0x7311fee56f87294e336393b55939489bc1e810c402f304013475d04c90ca32a9`
  - Upgraded from `0xF1cA1F1A068468E1dcF90dA6add185467de80943` to `0x9496502d7D121B3D5eF25cA6c58d4f7593398a17` @commit`e79a367ad` @tx`0xe1ef58455de0b0331228e487d54720290ed8a73f709d2146bd43330d4a360bd3`
  - Upgraded from `0x9496502d7D121B3D5eF25cA6c58d4f7593398a17` to `0x2f7126f78365AD54EAB26fD7faEc60435008E2fD` @commit`bb2abc5` @tx`0x7d584f0a645cad61e634f64ffaf7e1bbfb92749878eb25b39ce0e5cf698897c7`
  - register `bridged_erc20` to `0x65666141a541423606365123Ed280AB16a09A2e1` @tx`0x0ad38201728e782a04d74c5984efedba4c2c0669c9ce791db2b010efe4f15b1d`
  - Upgraded from `0x2f7126f78365AD54EAB26fD7faEc60435008E2fD` to `0xEC1a9aa1C648F047752fe4eeDb2C21ceab0c6449` @commit`9345f14` @tx`0x13ea4d044a313cf667d16514465e6b96227ef7198bda7b19c70eefee44e9bccd`
  - remove `bridge_watchdog` on May 16, 2025 @tx`0x48961d6d5c2a3301f6d6b5e0a78f1ddee396bf55b3b654a5067d0768d61f978b`

#### taiko_token

- ens: `token.taiko.eth`
- proxy: `0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800`
- impl: `0x5C96Ff5B7F61b9E3436Ef04DA1377C8388dfC106`
- owner: `controller.taiko.eth`
- logs:
  - deployed on April 25, 2024 @commit`2f6d3c62e`
  - upgraded impl from `0x9ae1a067f9655dd0511390e3d70bb25933ae61eb` to `0xea53c0f4b129Cf3f3FBA896F9f23ca18246e9B3c` @commit`b90b932` and,
  - Changed owner from `labs.taiko.eth` to `admin.taiko.eth` @tx`0x7d82794932540ed9edd259e58f6ef8ae21a49beada7f0224638f888f7149c01c`
  - Accept owner @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`
  - upgraded impl from `0xea53c0f4b129Cf3f3FBA896F9f23ca18246e9B3c` to `0x55833dA2962c2330ccCF043ff8037e6D2939bCF6` @commit`2b483de` @tx`0x0bbf7d1258c646f41a02a92a55825b1ebfd3659577d0f2b57b462f8895e23a04`
  - upgraded impl from `0x55833dA2962c2330ccCF043ff8037e6D2939bCF6` to `0xcfe803378D79d1180EbF030455040EA6513869dF` @commit`d2b00ce` @tx`0xc9f468d33d8d55911e4e5b5c301ed244a5f81ab0f389d2b4f398eb5b89d417ef`
  - upgrade impl to `0x87C752b0F70cAa237Edd7571B0845470A37DE040` @commit`619af45e72b76bdbd9a71f99d32b08dec373d72a` @tx`0xdb7d5de46738ad3f676db47b61772db531f9858b7a01e8c3b5aee49fa74cac95`
  - upgrade impl to `0x5C96Ff5B7F61b9E3436Ef04DA1377C8388dfC106` @PR[19457](https://github.com/taikoxyz/taiko-mono/pull/19461) @tx`0x986fc2c7ae945cdd358b2f2ae54364b350026f965f5861ed470f78e145f12626`
  - change owner to `controller.taiko.eth` @tx`https://etherscan.io/tx/0xa4dfb66625f58d2056a180be420cd7c33f103547848c4eae848089c8808288da`

#### signal_service

- ens: `signals.based.taiko.eth`
- proxy: `0x9e0a24964e5397B566c1ed39258e21aB5E35C77C`
- impl: `0x42Ec977eb6B09a8D78c6D486c3b0e63569bA851c`
- owner: `controller.taiko.eth`
- logs:
  - deployed on May 1, 2024 @commit`56dddf2b6`
  - admin.taiko.eth accepted the ownership @tx`0x0ed114fee6de4e3e2206cea44e6632ec0c4588f73648d98d8df5dc0183b07885`
  - upgraded from `0xE1d91bAE44B70bD66e8b688B8421fD62dcC33c72` to `0xB11Cd7bA46a12F238b4Ad831f6F296262C1e652d` @commit`b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`
  - upgraded from `0xB11Cd7bA46a12F238b4Ad831f6F296262C1e652d` to `0x3d59c18b31A7D950EF9bd15eD285b6c182E0f0bb` @commit`a3faee0` @tx`0x13f54109cb7f7507ad03562b06ea8d8b472043186e44252302583bc64acfb20b`
  - restored from `0x3d59c18b31A7D950EF9bd15eD285b6c182E0f0bb` to `0xB11Cd7bA46a12F238b4Ad831f6F296262C1e652d` @commit`b90b932` @tx`0xdb5e926c96d112ce1389da77a927fba6c7d04a711839b9e14777530ebcf83914`
  - upgraded from `0xB11Cd7bA46a12F238b4Ad831f6F296262C1e652d` to `0xDF8642a1FBFc2014de27E8E87283D6f3eEF315DF` @commit`bb2abc5` @tx`0x7d584f0a645cad61e634f64ffaf7e1bbfb92749878eb25b39ce0e5cf698897c7`
  - Upgraded from `0xDF8642a1FBFc2014de27E8E87283D6f3eEF315DF` to `0x45fed11Ba70D4217545F18E27DDAF7D76Ff499f3` @commit`9345f14` @tx`0x13ea4d044a313cf667d16514465e6b96227ef7198bda7b19c70eefee44e9bccd`
  - Upgraded from `0x45fed11Ba70D4217545F18E27DDAF7D76Ff499f3` to `0x0783Ee019C9b0f918A741469bD488A88827b3617` @commit`cf55838` @tx`0x97789b6668d0a287b1f57bb6c8e23cce62308fb887139faeb0f06b77855995fd`
  - Upgraded from `0x0783Ee019C9b0f918A741469bD488A88827b3617` to `0x42Ec977eb6B09a8D78c6D486c3b0e63569bA851c` @commit`cf55838` @tx`0x0ae99d24b294622e3d3868c8dca911a5936231ce1f97254ec0c6a6f65f7aa81c`
  - Change owner to controller @tx`0x6348cbb8f4c907bd72ded06cb9ba587d4ca794a546dab7e7ab6f0281a9c48c2c`

#### bridge

- ens: `bridge.based.taiko.eth`
- proxy: `0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC`
- impl: `0x2705B12a971dA766A3f9321a743d61ceAD67dA2F`
- owner: `controller.taiko.eth`
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
  - Upgrade impl to `0xAc96FF285158bceBB8573D20d853e86BB2915aF3` @commit`bb2abc5` @tx`0x7d584f0a645cad61e634f64ffaf7e1bbfb92749878eb25b39ce0e5cf698897c7`
  - Upgrade impl to `0x2705B12a971dA766A3f9321a743d61ceAD67dA2F` @commit`9345f14` @tx`0x13ea4d044a313cf667d16514465e6b96227ef7198bda7b19c70eefee44e9bccd`
  - Change owner to controller @tx`0x6348cbb8f4c907bd72ded06cb9ba587d4ca794a546dab7e7ab6f0281a9c48c2c`

#### quota_manager

- proxy: `0x91f67118DD47d502B1f0C354D0611997B022f29E`
- impl: `0xdb627bfD79e81fE42138Eb875287F94FAd5BBc64`
- owner: `controller.taiko.eth`
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
  - change owner to controller @tx`0x4445a905ba77f382914a1dcbb1ddd3ce704822c1fd4512042a8195ebb816c631`

#### erc20_vault

- ens: `v20.based.taiko.eth`
- proxy: `0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab`
- impl: `0xb20C8Ffc2dD49596508d262b6E8B6817e9790E63`
- owner: `controller.taiko.eth`
- logs:
  - deployed on May 1, 2024 @commit`56dddf2b6`
  - upgraded from `0x15D9F7e12aEa18DAEF5c651fBf97567CAd4a4BEc` to `0xC722d9f3f8D60288589F7f67a9CFAd34d3B9bf8E` @commit`b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`
  - upgraded from `0xC722d9f3f8D60288589F7f67a9CFAd34d3B9bf8E` to `0x4F750D13005444407D44dAA30922128db0374ca1` @commit`fa481c1` @tx`0x02ed558762eae5f0a930ba4a1047a02d4a793ea48890268c32df04e882f138ff`
  - upgraded from `0x4F750D13005444407D44dAA30922128db0374ca1` to `0xF8bdaC4E68bA2595Be8381aaa5456917e374E737` @commit`d907359` @tx`0xdb5e926c96d112ce1389da77a927fba6c7d04a711839b9e14777530ebcf83914`
  - upgraded from `0xF8bdaC4E68bA2595Be8381aaa5456917e374E737` to `0xa303784B0557BF1F1FB8b8abEF2B18a005722689` @commit`04d8c87` @tx`0x13f54109cb7f7507ad03562b06ea8d8b472043186e44252302583bc64acfb20b`
  - upgraded from `0xa303784B0557BF1F1FB8b8abEF2B18a005722689` to `0x7ACFBb369a552C45d402448A4d64b9da54C3FF30` @commit`bb2abc5` @tx`0xee632b50626beb2f7db84c9c7f303f29366f86dfaccd24ddd831ceac714c20e5`
  - upgraded from `0x7ACFBb369a552C45d402448A4d64b9da54C3FF30` to `0xb20C8Ffc2dD49596508d262b6E8B6817e9790E63` @commit`9345f14` @tx`0x13ea4d044a313cf667d16514465e6b96227ef7198bda7b19c70eefee44e9bccd`
  - change owner to controller.taiko.eth @tx`0xc67a1ab94e6c4ccc5a357269c54a15b99f64ac9ed0c089b853d634772dbe40e0`

#### erc721_vault

- ens: `v721.based.taiko.eth`
- proxy: `0x0b470dd3A0e1C41228856Fb319649E7c08f419Aa`
- impl: `0xA4C5c20aB33C96B1c281Dca37D03E23609274C49`
- owner: `controller.taiko.eth`
- logs:
  - deployed on May 1, 2024 @commit`56dddf2b6`
  - upgraded from `0xEC04849E7722Fd69797a155796Db75aC8F94f692` to `0x41A7BDD153a5AfFb10Ed1AD3D6a4e5ad001495FA` @commit`b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`
  - upgraded from `0x41A7BDD153a5AfFb10Ed1AD3D6a4e5ad001495FA` to `0x2dfef0339009Ce10786fc118C883BB97af3163eD` @commit`fa481c1` @tx`0x02ed558762eae5f0a930ba4a1047a02d4a793ea48890268c32df04e882f138ff`
  - upgraded from `0x2dfef0339009Ce10786fc118C883BB97af3163eD` to `0x55B5df6B53466446221180498BfD1C59e54732c4` @commit`d907359` @tx`0xdb5e926c96d112ce1389da77a927fba6c7d04a711839b9e14777530ebcf83914`
  - upgraded from `0x55B5df6B53466446221180498BfD1C59e54732c4` to `0xD961e3Ef2D7DF58cDc67BFd9055255430E5e3fEc` @commit`bb2abc5` @tx`0x7d584f0a645cad61e634f64ffaf7e1bbfb92749878eb25b39ce0e5cf698897c7`
  - upgraded from `0xD961e3Ef2D7DF58cDc67BFd9055255430E5e3fEc` to `0xA4C5c20aB33C96B1c281Dca37D03E23609274C49` @commit`9345f14` @tx`0x13ea4d044a313cf667d16514465e6b96227ef7198bda7b19c70eefee44e9bccd`
  - change owner to controller.taiko.eth @tx`0xc67a1ab94e6c4ccc5a357269c54a15b99f64ac9ed0c089b853d634772dbe40e0`

#### erc1155_vault

- ens: `v1155.based.taiko.eth`
- proxy: `0xaf145913EA4a56BE22E120ED9C24589659881702`
- impl: `0x838ed469db456b67EB3b0B74D759Be4DA999b9c8`
- owner: `controller.taiko.eth`
- logs:
  - deployed on May 1, 2024 @commit`56dddf2b6`
  - upgraded from `0x7748dA086A2e6EDd8Db97eD236840910013c6396` to `0xd90b5fcf8d00d333d107E4Ab7F94c0c0A41CDcfE` @commit`b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`
  - upgraded from `0xd90b5fcf8d00d333d107E4Ab7F94c0c0A41CDcfE` to `0x097BBBef669AaD66030aB223195D200eF9A47dc3` @commit`fa481c1` @tx`0x02ed558762eae5f0a930ba4a1047a02d4a793ea48890268c32df04e882f138ff`
  - upgraded from `0x097BBBef669AaD66030aB223195D200eF9A47dc3` to `0xca92880829139b310B6b0CB41f66D566Db1a59C8` @commit`d907359` @tx`0xdb5e926c96d112ce1389da77a927fba6c7d04a711839b9e14777530ebcf83914`
  - upgraded from `0xca92880829139b310B6b0CB41f66D566Db1a59C8` to `0x89C68Bc7028f8b1e69A91382b0a4b1825085617b` @commit`bb2abc5` @tx`0x7d584f0a645cad61e634f64ffaf7e1bbfb92749878eb25b39ce0e5cf698897c7`
  - upgraded from `0x89C68Bc7028f8b1e69A91382b0a4b1825085617b` to `0x838ed469db456b67EB3b0B74D759Be4DA999b9c8` @commit`9345f14` @tx`0x13ea4d044a313cf667d16514465e6b96227ef7198bda7b19c70eefee44e9bccd`
  - change owner to controller.taiko.eth @tx`0xc67a1ab94e6c4ccc5a357269c54a15b99f64ac9ed0c089b853d634772dbe40e0`

#### bridged_erc20

- impl: `0x65666141a541423606365123Ed280AB16a09A2e1`
- logs:
  - deployed on May 1, 2024 @commit`56dddf2b6`
  - deployed on Jul 25, 2024 @commit`ba6bf94`

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
- impl: `0x0079a79E5d8DDA67029051d505E5A11DE279B36D`
- names:
  - bond_token: `0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800`
  - taiko_token: `0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800`
  - signal_service: `0x9e0a24964e5397B566c1ed39258e21aB5E35C77C`
  - bridge: `0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC`
  - taiko: `0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a`
  - tier_router: `0x44d307a9ec47aA55a7a30849d065686753C86Db6`
  - tier_sgx: `0xb0f3186FC1963f774f52ff455DC86aEdD0b31F81`
  - risc0_groth16_verifier: `0x48E32eFbe22e180A3FFe617f4955cD83B983dd98`
  - tier_zkvm_risc0: `0x55902b2D3DF2A65370A89C86Ae9dd71Ecd508edc`
  - sp1_remote_verifier: `0x68593ad19705E9Ce919b2E368f5Cb7BAF04f7371`
  - tier_zkvm_sp1: `0x5c44f2239925b0d86d2BFEe539f19CD0A08Af452`
  - automata_dcap_attestation: `0x8d7C954960a36a7596d7eA4945dDf891967ca8A3`
  - prover_set: `0x280eAbfd252f017B78e15b69580F249F45FB55Fa`
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
  - register `prover_set` to `0x74828E5fe803072AF9Df512B3911B4223572D652` @commit`bb2abc5` @tx`0x7d584f0a645cad61e634f64ffaf7e1bbfb92749878eb25b39ce0e5cf698897c7`
  - upgraded from `0x29a88d60246C76E4F28806b9C8a42d2183154900` to `0x4f6D5D3109C07E77035B410602996e445b18E8E9` @commit`bb2abc5` @tx`0x7d584f0a645cad61e634f64ffaf7e1bbfb92749878eb25b39ce0e5cf698897c7`
  - register `prover_set` to `0xCE5a119479337a153CA3bd1b2bF9755c78F2B15A` @commit`be34059` @tx`0x170617251f2345eda4bcbd29e316caa0b014602a44244c60b963382ac7da7748`
  - upgraded from `0x4f6D5D3109C07E77035B410602996e445b18E8E9` to `0x3202Fc255aE09F91DbbD5b000b87dA4A2E04eE37` @commit`9345f14` @tx`0x13ea4d044a313cf667d16514465e6b96227ef7198bda7b19c70eefee44e9bccd`
  - upgraded from `0x3202Fc255aE09F91DbbD5b000b87dA4A2E04eE37` to `0x190D5d50D98D2202a618f75B2fD9986e60E096be` @commit`4fd7b59` @tx`0xf26d0526aa4b8225c603720ce0dc016803188b959c50677d5446087d1f2c4e60`
  - upgraded from `0x190D5d50D98D2202a618f75B2fD9986e60E096be` to `0x6D8e6e1a061791AD17A55De5e15a111c58f6Fb3D` @commit`2625c60` @tx`0x5d46840df79d8df508880675e7ea549e9b46137f597ca520c3e0c979439441d1`
  - upgraded from `0x6D8e6e1a061791AD17A55De5e15a111c58f6Fb3D` to `0x52CA3c5566d779b3c6bb5c4f760Ea39E294Fc788` @commit`9ae9a5e` @tx`0x43353a74df973d8f6a379b5c8815ac80935a5099f8ab93a4aa204eb5ef2c663e`
  - upgraded from `0x52CA3c5566d779b3c6bb5c4f760Ea39E294Fc788` to `0x0079a79E5d8DDA67029051d505E5A11DE279B36D` @commit`06128e8` @tx`0xe66aba9f8bfcd86dc0ae32416862ca61a51c47f8ec747799e65f155ef27eeb20`
  - register `prover_set` to `0x280eAbfd252f017B78e15b69580F249F45FB55Fa` @tx`0xc0e8ec30d1479ca2414d4d28a09a543c2845247d80387f78c179d663ffe55c3c`
  - remove `chain_watchdog` on May 16, 2025 @tx`0x48961d6d5c2a3301f6d6b5e0a78f1ddee396bf55b3b654a5067d0768d61f978b`

#### Inbox

- ens: `inbox_based.taiko.eth`
- proxy: `0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a`
- impl: `0xB0600e011e02eD35A142B45B506B16A35493c3F5`
- owner : `controller.taiko.eth`
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
  - Upgrade to `0xBA1d90BCfA74163bFE09e8eF609b346507D83231` @commit`bb2abc5` @tx`0x7d584f0a645cad61e634f64ffaf7e1bbfb92749878eb25b39ce0e5cf698897c7`
  - Upgrade to `0xf0E6d34937701622cA887a75c150cC23d4FFDf2F` @commit`b4f8547` @tx`0x8778064404816273804d74c97b051f3865bc03062cfa4b0e9567f4556ad31981`
  - Upgrade to `0x4229d14F520848aa83760Cf748abEB8A69cdaB2d` @commit`9345f14` @tx`0x13ea4d044a313cf667d16514465e6b96227ef7198bda7b19c70eefee44e9bccd`
  - Upgrade to `0xA3E75eDA1Be2114816f388A5cF53EbA142DCDB17` @commit`ea0158f` @tx`0x78ca7c7d9c7e5aa9c5e6ab80e0229289a8d3bc8df2c2b9ba6baa74a0f60a0703`
  - Upgrade to `0xe7c4B445D3C7C8E4D68afb85A068F9fAa18e9A5B` @commit`ea0158f` with new `RollupAddressManagerCache` @commit `9ae9a5e` @tx`0x5eb57ab352b3e3c1ddbc3fe468d582901b88c6a137ce49b0d70857d5218d626d`
  - Upgrade to `0xb74A66b6CF50AD63E29669F0BDE4354E11758162` @commit`06128e8` @tx`0xe66aba9f8bfcd86dc0ae32416862ca61a51c47f8ec747799e65f155ef27eeb20`
  - Upgrade to `0xd4896d4537c6425aC5d89B9f122d4E4ac4D65e1c` @commit`ea0158f` with new `RollupAddressManagerCache` @commit `7394458` @tx`0x9c2f36af40c0004110041fc45d980b73b0c8dde8064713a55aeb6f69fca77a99`
  - Upgrade to `0xe7c4B445D3C7C8E4D68afb85A068F9fAa18e9A5B` @commit`ea0158f` with new `RollupAddressManagerCache` @commit `9ae9a5e` @tx`0x5eb57ab352b3e3c1ddbc3fe468d582901b88c6a137ce49b0d70857d5218d626d`
  - Upgrade to `0x2784423f7c61Bc7B75dB6CdA26959946f437588D` @commit`9d2aac8` @tx`0xc0e8ec30d1479ca2414d4d28a09a543c2845247d80387f78c179d663ffe55c3c`
  - Upgrade to `0x5110634593Ccb8072d161A7d260A409A7E74D7Ca` @commit`9a89166` @tx`0x6368890b9aa2f87c6a6b727efdd8af0ea357a11460b546d8a7f3e19e38a34e41`
  - Upgrade to `0x4e030b19135869F6fd926614754B7F9c184E2B83` @commit`cf55838` @tx`0x78f766ae83ce94ef2293c9c7d81ae514e8fa0a79fbce1530c3c68d7624708795`
  - Upgrade to `0xde813DD3b89702E5Eb186FeE6FBC5dCf02aE6319` @commit`3328024` @tx`0xffedb70a513e71486c3a47079508d3ba87ae5362e7efb3300febac1be69276bc`
  - Upgrade to `0xb4530aBee1Dd239C02266e73ca83Fe6617e77F2F` @commit`c2a941e` @tx`0x9e26e018d5dc07349ea34f907728a43cd47a8a62058467c30cf21df975e59090`
  - Upgrade to `0xB0600e011e02eD35A142B45B506B16A35493c3F5` @commit`` @tx``

#### tier_router

- impl: `0x44d307a9ec47aA55a7a30849d065686753C86Db6`
- logs:
  - deployed on Oct 24, 2024 @commit`7334b1d`
  - deployed on Nov 1, 2024 @commit`f4f4796`
  - deployed on Nov 2, 2024 @commit`9182fba`
  - deployed on Nov 8, 2024 @commit`1fee7bb` without changes in [PR #18371](https://github.com/taikoxyz/taiko-mono/pull/18371)
  - deployed on Nov 10, 2024 @commit`f24a908` without changes in [PR #18371](https://github.com/taikoxyz/taiko-mono/pull/18371)
  - deployed on Dec 20, 2024 @commit`06128e8` without changes in [PR #18371](https://github.com/taikoxyz/taiko-mono/pull/18371)
  - deployed on Feb 25, 2024 @commit`9a89166`

#### tier_sgx

- proxy: `0xb0f3186FC1963f774f52ff455DC86aEdD0b31F81`
- impl: `0x81DFEA931500cdcf0460e9EC45FA283A6B7f0838`
- owner : `controller.taiko.eth`
- logs:
  - deployed on May 1, 2024 @commit`56dddf2b6`
  - Upgraded from `0x3f54067EF5d8B414Bdb1945cdF482BD158Aad175` to `0xf381868DD6B2aC8cca468D63B42F9040DE2257E9` @commit`b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`
  - Upgraded from `0xf381868DD6B2aC8cca468D63B42F9040DE2257E9` to `0xB0b782cf0fCEce896E0C041F8e54f86cA4cC8e9F` @commit`a3faee0` @tx`eth:0x40A2aCCbd92BCA938b02010E17A5b8929b49130D`
  - Upgraded from `0xB0b782cf0fCEce896E0C041F8e54f86cA4cC8e9F` to `0xEE5F6648307319263FFBaE91f68ac700b188fF24` @commit`be34059` @tx`0x170617251f2345eda4bcbd29e316caa0b014602a44244c60b963382ac7da7748`
  - Upgraded from `0xEE5F6648307319263FFBaE91f68ac700b188fF24` to `0x7EE4CEF8a945639e09DDf3032e9d95c8d90f07f3` @commit`dd09223` @tx`0x2e246e4b4637c4bf13dccea873a30e35e704bafa7f02e30c877ecec7d786e662`
  - Upgraded from `0x7EE4CEF8a945639e09DDf3032e9d95c8d90f07f3` to `0x81DFEA931500cdcf0460e9EC45FA283A6B7f0838` @commit`9345f14` @tx`0x13ea4d044a313cf667d16514465e6b96227ef7198bda7b19c70eefee44e9bccd`

#### tier_risc0

- proxy: `0x55902b2D3DF2A65370A89C86Ae9dd71Ecd508edc`
- impl: `0xefe30A0D56a5804F695f971010597262CAd9A2c3`
- logs:
  - deployed on Nov 6, 2024 @commit`bfb0386`

#### tier_sp1

- proxy: `0x5c44f2239925b0d86d2BFEe539f19CD0A08Af452`
- impl: `0x5f5b83Ca87E2fBc513B800FeD6cCD626536d7219`
- logs:
  - deployed on Nov 8, 2024 @commit`0b11101`

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
- owner : `controller.taiko.eth`
- logs:
  - deployed on May 1, 2024 @commit`56dddf2b6`
  - Upgraded from `0xEE8FC1dbb8D345f5bF35dFb939C6f9EdC5fCDAFc` to `0xde1b1FBe7D721af4A56651272ef91A59B7303323` @commit`b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`
  - Called `configureTcbInfoJson` and `configureQeIdentityJson` @commit`b90b932` @tx`0x2d6ce1781137899f65c1810e42f556c27caa4e9bd13077ba5bc7a9a0975eefcb`
  - Called `configureTcbInfoJson` and `configureQeIdentityJson` @commit`cd5144255` @tx`0x8030569e293baddbc4e8b26688a1ecf14a231d86c90e9d02dad1e919ea2f3964`
  - Upgraded from `0xde1b1FBe7D721af4A56651272ef91A59B7303323` to `0x5f73f0AdC7dAA6134Fe751C4a78d524f9384e0B5` @commit`3740dc0` @tx`0x46a6d47c15505a1259c64d1e09353680e525b2706dd9e095e15019dda7c1b295`
  - Called `configureTcbInfoJson` @commit`3740dc0` @tx`0x46a6d47c15505a1259c64d1e09353680e525b2706dd9e095e15019dda7c1b295`
  - Update mrenclave & mrsign on May 28, 2024 @commit`b335b70` @tx`0x6a240314c6a48f3ab58e0a3d5bf0e915668dac5eec19c694656eeb3d66c12465`
  - Called `setMrEnclave` @commit`9d06958` @tx`0x0aa35e03c521f8e4b4d03662a6ecc6de5dd3e336f63e6ea00eff7b4184eae9be`
  - Called `setMrEnclave` @commit`9a89166` @tx`0x6368890b9aa2f87c6a6b727efdd8af0ea357a11460b546d8a7f3e19e38a34e41`

### token_unlock

- impl: `0x5c475bB14727833394b0704266f14157678A72b6`
- logs:
  - deployed @commit`bca493f` @tx`0x0a4a63715257b766ca06e7e87ee25088d557c460e50120208b31666c83fc68bc`
  - deployed @commit`3d89d24` @tx`0x28fdfb26c1409e420fe9ecce22063fa70efdbe56359aeacf9f65e68db8b8d34a`
  - deployed @PR[19457](https://github.com/taikoxyz/taiko-mono/pull/19457/files) @tx`0xfa94bc59c0bc52131a418598780c4e289a13407143a7bdf54c871b5cec35d0b0`

### prover_set

- impl: `0xB8826B144eB895eFE2923b61b3b117B1298A9526`
- logs:
  - deployed @commit`bca493f` @tx`0xfacd0f26e3ec4bf1f949637373483fcfe9a960dfc427d6fa62b116907bac3373`
  - deployed @commit`2dd30ab` @tx`0xc1f91c375713f601b99cf6d2cdb80c129e036a7c9ec5f75871c4d13216dbbb5c`
  - deployed @commit`9d2aac8` @tx`0xc0e8ec30d1479ca2414d4d28a09a543c2845247d80387f78c179d663ffe55c3c`
  - deployed @commit`cf55838` @tx`0xa1bcdef460676d387d7c652ee459b7a64081846f42dc30414a6e137be543cd6a`

### labprover.taiko.eth

- ens: `labprover.taiko.eth`
- proxy: `0x68d30f47F19c07bCCEf4Ac7FAE2Dc12FCa3e0dC9`
- impl: `0xB8826B144eB895eFE2923b61b3b117B1298A9526`
- enabled provers:
  - `0x7A853a6480F4D7dB79AE91c16c960dBbB6710d25`
  - `0xa5cb34B75bD72f15290ef37A01F06183E8036875`
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
  - upgraded from `0x518845daA8870bE2C59E49620Fc262AD48953C9a` to `0x74828E5fe803072AF9Df512B3911B4223572D652` @commit`bb2abc5` @tx`0xc1f91c375713f601b99cf6d2cdb80c129e036a7c9ec5f75871c4d13216dbbb5c`
  - upgraded from `0x74828E5fe803072AF9Df512B3911B4223572D652` to `0xCE5a119479337a153CA3bd1b2bF9755c78F2B15A` @commit`be34059` @tx`0x170617251f2345eda4bcbd29e316caa0b014602a44244c60b963382ac7da7748`
  - upgraded from `0xCE5a119479337a153CA3bd1b2bF9755c78F2B15A` to `0x3022Ed0346CCE0c08268c8ad081458AfD95E8763` @commit`9345f14` @tx`0x13ea4d044a313cf667d16514465e6b96227ef7198bda7b19c70eefee44e9bccd`
  - upgraded from `0x3022Ed0346CCE0c08268c8ad081458AfD95E8763` to `0xd0d3f025D83D7122de7eC43e86331C57c8A4F30B` @commit`06128e8` @tx`0xe66aba9f8bfcd86dc0ae32416862ca61a51c47f8ec747799e65f155ef27eeb20`
  - upgraded from `0xd0d3f025D83D7122de7eC43e86331C57c8A4F30B` to `0x280eAbfd252f017B78e15b69580F249F45FB55Fa` @commit`9d2aac8` @tx`0xc0e8ec30d1479ca2414d4d28a09a543c2845247d80387f78c179d663ffe55c3c`
  - upgraded from `0x280eAbfd252f017B78e15b69580F249F45FB55Fa` to `0xB8826B144eB895eFE2923b61b3b117B1298A9526` @commit`cf55838` @tx`0x97789b6668d0a287b1f57bb6c8e23cce62308fb887139faeb0f06b77855995fd`
  - disable a prover (`0x000000629FBCf27A347d1AEbA658435230D74a5f`) on May 30 @commit`f71fff7` @tx`0x1a29861868ad0c466e1db8c95b3373bbe882cd24ec04031fa16083339d1f80cf`
  - disable a prover (`0x000000633b68f5d8d3a86593ebb815b4663bcbe0`) on May 30 @commit`f71fff7` @tx`0x1a29861868ad0c466e1db8c95b3373bbe882cd24ec04031fa16083339d1f80cf`
  - enable a prover (`0x7A853a6480F4D7dB79AE91c16c960dBbB6710d25`) on May 30 @commit`f71fff7` @tx`0x1a29861868ad0c466e1db8c95b3373bbe882cd24ec04031fa16083339d1f80cf`
  - enable a prover (`0xa5cb34B75bD72f15290ef37A01F06183E8036875`) on May 30 @commit`f71fff7` @tx`0x1a29861868ad0c466e1db8c95b3373bbe882cd24ec04031fa16083339d1f80cf`

### labcontester.taiko.eth

- ens: `labcontester.taiko.eth`
- proxy: `0xa01d464ca3982DAa97B19fa7F8a232eB11A9DDb3`
- impl: `0x280eAbfd252f017B78e15b69580F249F45FB55Fa`
- enabled provers:
  - ``
- logs:
  - enabled a prover (`0x00000027F51a57E7FcBC4b481d15fcE5BE68b30B`) on May 28 @commit`b335b70` @tx`0x27c84a1dbf80d88948f96f1536c244816543fb780c81a04ba485c4c156431112`
  - upgraded from `0x500735343372Dd6c9B84dBc7a75babf4479742B9` to `0xd0AEe97712a4a88B75C31E3C61DD2Ce6E514D85F` @commit`a3faee0` @tx`eth:0x40A2aCCbd92BCA938b02010E17A5b8929b49130D`
  - upgraded from `0xd0AEe97712a4a88B75C31E3C61DD2Ce6E514D85F` to `0x5D528253fA14cd7F637937de847BE8D5BE0Bf5fd` @commit`2b483de` @tx`0x0bbf7d1258c646f41a02a92a55825b1ebfd3659577d0f2b57b462f8895e23a04`
  - upgraded from `0xD547Ca5d6b50dC5E900a091978597eB51F18F9D1` to `0x518845daA8870bE2C59E49620Fc262AD48953C9a` @commit`2dd30ab` @tx`0xc1f91c375713f601b99cf6d2cdb80c129e036a7c9ec5f75871c4d13216dbbb5c`
  - upgraded from `0x518845daA8870bE2C59E49620Fc262AD48953C9a` to `0x74828E5fe803072AF9Df512B3911B4223572D652` @commit`bb2abc5` @tx`0xc1f91c375713f601b99cf6d2cdb80c129e036a7c9ec5f75871c4d13216dbbb5c`
  - upgraded from `0x74828E5fe803072AF9Df512B3911B4223572D652` to `0xCE5a119479337a153CA3bd1b2bF9755c78F2B15A` @commit`be34059` @tx`0x170617251f2345eda4bcbd29e316caa0b014602a44244c60b963382ac7da7748`
  - upgraded from `0xCE5a119479337a153CA3bd1b2bF9755c78F2B15A` to `0x3022Ed0346CCE0c08268c8ad081458AfD95E8763` @commit`9345f14` @tx`0x13ea4d044a313cf667d16514465e6b96227ef7198bda7b19c70eefee44e9bccd`
  - upgraded from `0x3022Ed0346CCE0c08268c8ad081458AfD95E8763` to `0xd0d3f025D83D7122de7eC43e86331C57c8A4F30B` @commit`06128e8` @tx`0xe66aba9f8bfcd86dc0ae32416862ca61a51c47f8ec747799e65f155ef27eeb20`
  - upgraded from `0xd0d3f025D83D7122de7eC43e86331C57c8A4F30B` to `0x280eAbfd252f017B78e15b69580F249F45FB55Fa` @commit`9d2aac8` @tx`0xc0e8ec30d1479ca2414d4d28a09a543c2845247d80387f78c179d663ffe55c3c`
  - disable a prover (`0x00000027F51a57E7FcBC4b481d15fcE5BE68b30B`) on May 30 @commit`f71fff7` @tx`0x1a29861868ad0c466e1db8c95b3373bbe882cd24ec04031fa16083339d1f80cf`

## Pacaya Contracts

#### shared_resolver

- proxy: `0x8Efa01564425692d0a0838DC10E300BD310Cb43e`
- impl: `0xFca4F0Ab7B95EEf2e3A60EF2Bc0c42DdAA62E66D`
- owner : `controller.taiko.eth`
- names:
  - taiko_token: `0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800`
  - bond_token: `0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800`
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
  - bridged_erc20: `0x65666141a541423606365123Ed280AB16a09A2e1`
  - bridged_erc721: `0xC3310905E2BC9Cfb198695B75EF3e5B69C6A1Bf7`
  - bridged_erc1155: `0x3c90963cFBa436400B0F9C46Aa9224cB379c2c40`
- logs:
  - deployed on May 15, 2025 @commit`cf55838b2` @tx `0x0a48a276897935e7406b4cc8f17a9b1480c56cb866d6504fd28184ac8e79e8a0`
  - remove `bridge_watchdog` on May 16, 2025 @tx`0x48961d6d5c2a3301f6d6b5e0a78f1ddee396bf55b3b654a5067d0768d61f978b`

#### rollup_address_resolver

- proxy: `0x5A982Fb1818c22744f5d7D36D0C4c9f61937b33a`
- impl: `0xE78659fbF234c84C909Cf317D84edc2f6C0D8413`
- owner : `controller.taiko.eth`
- names:
  - bond_token: `0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800`
  - taiko_token: `0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800`
  - signal_service: `0x9e0a24964e5397B566c1ed39258e21aB5E35C77C`
  - bridge: `0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC`
  - taiko: `0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a`
  - automata_dcap_attestation: `0x8d7C954960a36a7596d7eA4945dDf891967ca8A3`
  - prover_set: `0xB8826B144eB895eFE2923b61b3b117B1298A9526`
  - sgx_geth_automata: `0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261`
  - sgx_geth_verifier: `0x7e6409e9b6c5e2064064a6cC994f9a2e95680782`
  - sgx_reth_verifier: `0x9e322fC59b8f4A29e6b25c3a166ac1892AA30136`
  - risc0_reth_verifier: `0x73Ee496dA20e5C65340c040B0D8c3C891C1f74AE`
  - sp1_reth_verifier: `0xbee1040D0Aab17AE19454384904525aE4A3602B9`
  - preconf_whitelist: `0xFD019460881e6EeC632258222393d5821029b2ac`
  - preconf_router: `0xD5AA0e20e8A6e9b04F080Cf8797410fafAa9688a`
- logs:
  - deployed on May 15, 2025 @commit`cf55838b2` @tx `0x479a582b4bb2a262e395c94e009c996781cb5ef5c55478be6dd2f322b12ba156`

### forced_inclusion_store

- proxy : `0x05d88855361808fA1d7fc28084Ef3fCa191c4e03`
- impl : `0xcdb25e201Ad3fdcFe16730A6CA2cC0B1Ce2137a2`
- owner : `controller.taiko.eth`
- logs:
  - deployed on May 15, 2025 @commit `cf55838` @tx `0x042beff750bfb1b1167a5acc32f68c4565a6e698c162ecff445eaac9fca66fdf`

### taiko_wrapper

- proxy : `0x9F9D2fC7abe74C79f86F0D1212107692430eef72`
- impl : `0xa2D216dD9c84cb2e738240aac0956BE98293be61`
- owner : `controller.taiko.eth`
- logs:
  - deployed on May 15, 2025 @commit `cf55838` @tx `0xe0c52c898ce19785fb139e822a9b5a088b374692820bc402eb31e7a6086664e7`
  - upgraded to `0xa2D216dD9c84cb2e738240aac0956BE98293be61` @commit`31094a6` @tx`0x9e26e018d5dc07349ea34f907728a43cd47a8a62058467c30cf21df975e59090`

### preconf_whitelist

- proxy : `0xFD019460881e6EeC632258222393d5821029b2ac`
- impl : `0x44eC275996BD69361EF062ed488882a58256CF11`
- owner : `controller.taiko.eth`
- enabled operators:
  - taiko proposer `0x5F62d006C10C009ff50C878Cd6157aC861C99990`(sequencer `0x5F62d006C10C009ff50C878Cd6157aC861C99990`)
  - gattaca proposer `0xe2dA8aC2E550cd141198a117520D4EDc8692AB74`(sequencer `0xe2dA8aC2E550cd141198a117520D4EDc8692AB74`)
  - nethermind proposer `0xCbeB5d484b54498d3893A0c3Eb790331962e9e9d`(sequencer `0x2ABD9afD6D41d0c37b8d55df11BFc73B53c3ac61`)
  - chainbound proposer `0x000cb000E880A92a8f383D69dA2142a969B93DE7`(sequencer `0x000cb000E880A92a8f383D69dA2142a969B93DE7`)
- ejectors:
  - `0x45D4403351Bc34283CE6450D91c099f40D06dA4e`
  - `0x0F026a3efE44E0Fe34B87375EFe69b16c05D0438`
- logs:
  - deployed on Jul 23, 2025 @commit `c2a941e` @tx `0x797256dc575734f2af55c2c2138aaf72aaed91e0909b6cd03d637b54b0c99bba`
  - upgraded to `0x44eC275996BD69361EF062ed488882a58256CF11` @commit`31094a6` @tx`0xbfd772cb4571eb6275f23d4fd8c7eb1502462b55821ee59dae0d15ab3325fc22`
  - added proposer `0x5F62d006C10C009ff50C878Cd6157aC861C99990` @tx`0xbfd772cb4571eb6275f23d4fd8c7eb1502462b55821ee59dae0d15ab3325fc22`
  - added proposer `0x000cb000E880A92a8f383D69dA2142a969B93DE7` @tx`0xbfd772cb4571eb6275f23d4fd8c7eb1502462b55821ee59dae0d15ab3325fc22`
  - added proposer `0xe2dA8aC2E550cd141198a117520D4EDc8692AB74` @tx`0xb714b8a82f04f73f9c0581fe59fd1887abf3e3cd51e71ff5d5ba4bd13ac77e70`
  - added proposer `0xCbeB5d484b54498d3893A0c3Eb790331962e9e9d` @tx`0x8e5968f459f817b986153d607fd44c279b613447557d51be390331135bccfafd`
  - removed proposer `0x000cb000E880A92a8f383D69dA2142a969B93DE7` @tx`0xa11e6650c33072f4229773e6cbaac404ad66595485c3aed747a47de00d5dfc28`
  - added proposer `0x000cb000E880A92a8f383D69dA2142a969B93DE7` @tx`0x2c03bd01a944dc1ecfc254946a62c8f652df5730facc79f965742acd7319b4c4`

### preconf_router

- proxy : `0xD5AA0e20e8A6e9b04F080Cf8797410fafAa9688a`
- impl : `0xf571E2626E2CE68127852123A2cC6AA522C586A0`
- owner : `controller.taiko.eth`
- logs:
  - deployed on Jul 23, 2025 @commit `c2a941e` @tx `0x5a309fa38d79de894c96e5082356b0e52e9653726b1400b1d8d72e181b50d5d8`
  - upgraded to `0xf571E2626E2CE68127852123A2cC6AA522C586A0` @commit`31094a6` @tx`0xbfd772cb4571eb6275f23d4fd8c7eb1502462b55821ee59dae0d15ab3325fc22`

### proof_verifier

- proxy : `0xB16931e78d0cE3c9298bbEEf3b5e2276D34b8da1`
- impl : `0x8C520BB75590deaBC30c4fcaFD8778A43E5481b9`
- owner : `controller.taiko.eth`
- logs:
  - deployed on May 15, 2025 @commit `cf55838` @tx `0x67b886b503de0cf84155cfcfe08f841808178bc40101d2dea2155db069121e08`

### sgx_reth_verifier(Pacaya)

- proxy : `0x9e322fC59b8f4A29e6b25c3a166ac1892AA30136`
- impl : `0x8ADDcf5d4CD7BD9dA1CE62eF84AeE22c9E2BfbA5`
- owner : `controller.taiko.eth`
- logs:
  - deployed on May 15, 2025 @commit `cf55838` @tx `0x89e2ab8f03ee8042c48afb3577a840f9b63be9d88907b7171a590374e6f8e5d3`

### risc0_reth_verifier(Pacaya)

- proxy : `0x73Ee496dA20e5C65340c040B0D8c3C891C1f74AE`
- impl : `0xDF6327caafC5FeB8910777Ac811e0B1d27dCdf36`
- owner : `controller.taiko.eth`
- logs:
  - deployed on May 15, 2025 @commit `cf55838` @tx `0x8480ac4bcdf12dedf9c79bed7407bd290670d9fe9c867c5354e574c56c5ff48b`
  - upgraded on Jun 11, 2025 at commit `9dfb5b9` @tx `0x2b9250ebdcf10b1a1ec658e5cc9e7fd9aa19dd32573e6ab5bc036499682dea3a`
  - upgraded on Jul 21, 2025 at commit `92ad14e` @tx `0x95d0cfffe42dc984ce8b24104a28d1083100ab638bb4fe396d1a145c17460db9`
  - upgraded on Sep 30, 2025 at commit `c459c0d` @tx `` //TODO(@yue): fill the tx hash

### sp1_reth_verifier(Pacaya)

- proxy : `0xbee1040D0Aab17AE19454384904525aE4A3602B9`
- impl : `0x2e17ac86cafc1db939c9942e478f92bf0e548ee7`
- owner : `controller.taiko.eth`
- logs:
  - deployed on May 15, 2025 @commit `cf55838` @tx `0x88351319725a8f90fcbd22eaaee3b627b21d83fddb86db0014f7d3e194016d4a`
  - upgraded on Jun 3, 2025 at commit `52bc719` @tx `0xbdc86ada3808a5987cd1f4bbc49ecd2d7e577bf90642956442a3d14cffa827ec`

### sgx_geth_verifier

- proxy : `0x7e6409e9b6c5e2064064a6cC994f9a2e95680782`
- impl : `0xDb7AEe4fA967C2aB0eC28f63C8675224E59340A5`
- owner : `controller.taiko.eth`
- logs:
  - deployed on May 15, 2025 @commit `cf55838` @tx `0x4bfe3199637c49162ce8bdd928a06e2318cd7bfadb9c0ca02ed7304d1599e3e8`

### sgx_geth_automata

- proxy : `0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261`
- impl : `0x5e46443bd131eB6d4c6Fb4849bAD29af9596dd72`
- owner : `controller.taiko.eth`
- logs:
  - deployed on May 15, 2025 @commit `cf55838` @tx `0x7486b942c054eb6641ea701f0835d23fa606accad0e96051791da26c56a10771`

## Taiko DAO Specific

### MainnetDAOController

- ens: `controller.taiko.eth`
- proxy: `0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a`
- Owner (Taiko DAO): `0x9CDf589C941ee81D75F34d3755671d614f7cf261`
- impl: `0x4347df63bdC82b8835fC9FF47bC5a71a12cC0f06`
