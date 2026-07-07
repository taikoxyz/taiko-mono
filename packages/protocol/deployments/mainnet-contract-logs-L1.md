# Taiko Mainnet Contract Logs - L1

## Notes

1. Code used on mainnet must correspond to a commit on the main branch of the official repo: https://github.com/taikoxyz/taiko-mono.

## Shared

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
- impl: `0x1A06832992785766a105838C95c1E13a0045AC85`
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
  - upgraded to `0x1A06832992785766a105838C95c1E13a0045AC85` on Jun 29, 2026 @commit`b73608696` @tx`0xae7122add731c935d54d726ebe542e7d4f9f7321e3bdf4ec794309f813d981f7` (Proposal0017)

#### bridge

- ens: `bridge.based.taiko.eth`
- proxy: `0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC`
- impl: `0x1c94D798CFA08F396E5BA9F81697289c53273381`
- owner: `controller.taiko.eth`
- logs:
  - deployed on May 1, 2024 @commit`56dddf2b6`
  - admin.taiko.eth accepted the ownership @tx`0x0ed114fee6de4e3e2206cea44e6632ec0c4588f73648d98d8df5dc0183b07885`
  - upgraded from `0x91d593d34f2E1904cDCe3D5290a74563F87bCF6f` to `0x4A1091c2fb37D9C4a661c2384Ff539d94CCF853D` @commit`b90b932` @tx`0x416560cd96dc75ccffebe889e8d1ab3e08b33f814dc4a2bf7c6f9555071d1f6f`
  - upgraded from `0x4A1091c2fb37D9C4a661c2384Ff539d94CCF853D` to `0xc71CC3B0a47149878fad337fb2ca54E546A645ba` @commit`b955e0e` @tx`0x5a60c5815947a199cc84e1bc75539e01a202597b20c1f87bd9d02f8be6453abd`
  - called `selfDelegate` for Taiko Token @tx`0x740c255322873b3feb62ad1de71b51417053787328eae3aa84557c953463d55f`
  - upgraded from `0xc71CC3B0a47149878fad337fb2ca54E546A645ba` to `0x02F21B4C3d4dbfF70cE851741175a727c8D782Be` @commit`fa481c1` in @tx`0x02ed558762eae5f0a930ba4a1047a02d4a793ea48890268c32df04e882f138ff`
  - unpaused on 27 May, 2024 @tx`0x71ce1e61f1e42e34c9a51f5671ac260f2ac398e016ae645f2661f074e7f230ce`
  - upgraded from `0x02F21B4C3d4dbfF70cE851741175a727c8D782Be` to `0x71c2f41AEDe913AAEf2c62596E03702E348D6Cd0` in @tx`0x8a380a25d03a740d9535dfc3e2fc4f6960e22d49ad88b8d85f59af4013aedf87`
  - upgrade impl to `0x951B7Ae1bB26d12dB37f01748e8fB62FEf45A8B5` @commit`1bd3285` @tx`0xf21f6bf720767db3bc9b63ef69cacb20340bdedfb6589e6a4d11fe082dfa7bd6`
  - upgrade impl to `0x3c326483EBFabCf3252205f26dF632FE83d11108` @commit`3ae25fd` @tx`0xc0ba6558642b93ee892bee0705dbcfb5130c53637e6266bfa5e3a6501167d6f2`
  - upgrade impl to `0xD28f2c26aD8bA88b0691F6BB41Ff021878052561` @commit`2b483de` @tx`0x0bbf7d1258c646f41a02a92a55825b1ebfd3659577d0f2b57b462f8895e23a04`
  - upgrade impl to `0x01E7D369a619eF1B0E92563d8737F42C09789986` @commit`04d8c87` @tx`0x13f54109cb7f7507ad03562b06ea8d8b472043186e44252302583bc64acfb20b`
  - Upgrade impl to `0xAc96FF285158bceBB8573D20d853e86BB2915aF3` @commit`bb2abc5` @tx`0x7d584f0a645cad61e634f64ffaf7e1bbfb92749878eb25b39ce0e5cf698897c7`
  - Upgrade impl to `0x2705B12a971dA766A3f9321a743d61ceAD67dA2F` @commit`9345f14` @tx`0x13ea4d044a313cf667d16514465e6b96227ef7198bda7b19c70eefee44e9bccd`
  - Change owner to controller @tx`0x6348cbb8f4c907bd72ded06cb9ba587d4ca794a546dab7e7ab6f0281a9c48c2c`
  - upgraded to `0x1c94D798CFA08F396E5BA9F81697289c53273381` on Jun 29, 2026 @commit`b73608696` @tx`0xae7122add731c935d54d726ebe542e7d4f9f7321e3bdf4ec794309f813d981f7` (Proposal0017)

#### quota_manager

- address: `0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC`
- owner: `admin.taiko.eth` (`0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F`)
- note: immutable (no proxy), verified `QuotaManager`; deployed with the Proposal0017 Bridge/ERC20Vault implementations as their constructor `QUOTA_MANAGER`. The live Bridge (`0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC`) and ERC20Vault (`0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab`) are its only quota consumers (`quotaManager()` on both returns this address). Replaces the previous upgradeable QuotaManager proxy `0x91f67118DD47d502B1f0C354D0611997B022f29E`.
- quota (configured maxima, read on-chain 2026-07-07):
  - Quota Period: 24 hours
  - ETH: 250 ETH
  - WETH(`0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2`): 250 WETH
  - TAIKO(`0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800`): 10,000,000
  - USDT(`0xdAC17F958D2ee523a2206206994597C13D831ec7`): 250,000
  - USDC(`0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`): 250,000
- logs:
  - deployed via the Proposal0017 recovery bundle (`DeployHackRecoveryContracts`) on Jun 25, 2026 @commit`b73608696` @tx`0xeb1b4c11afdf3c0522ab01c847fbc9bd94c6f3a9e42bb09dc0ed70bf01bee6af`

#### erc20_vault

- ens: `v20.based.taiko.eth`
- proxy: `0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab`
- impl: `0x024253C6FDC27d3161aFd43fb0241411A28dDc3c`
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
  - upgraded to `0x024253C6FDC27d3161aFd43fb0241411A28dDc3c` on Jun 29, 2026 @commit`b73608696` @tx`0xae7122add731c935d54d726ebe542e7d4f9f7321e3bdf4ec794309f813d981f7` (Proposal0017)

#### erc721_vault

- ens: `v721.based.taiko.eth`
- proxy: `0x0b470dd3A0e1C41228856Fb319649E7c08f419Aa`
- impl: `0xA4C5c20aB33C96B1c281Dca37D03E23609274C49`
- owner: `controller.taiko.eth`
- note: `addressManager()` points at the legacy shared_address_manager `0xEf9EaA1dd30a9AA1df01c36411b5F082aA65fBaa` (SAM), superseded by shared_resolver `0x8Efa01564425692d0a0838DC10E300BD310Cb43e`; the bridge and erc20_vault were migrated to it, these NFT vaults were not.
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
- note: `addressManager()` points at the legacy shared_address_manager `0xEf9EaA1dd30a9AA1df01c36411b5F082aA65fBaa` (SAM), superseded by shared_resolver `0x8Efa01564425692d0a0838DC10E300BD310Cb43e`; the bridge and erc20_vault were migrated to it, these NFT vaults were not.
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

#### shared_address_manager (sam)

- ens: `sam.based.taiko.eth`
- proxy: `0xEf9EaA1dd30a9AA1df01c36411b5F082aA65fBaa`
- impl: `0xEC1a9aa1C648F047752fe4eeDb2C21ceab0c6449`
- owner : `controller.taiko.eth`
- note: legacy shared AddressManager (pre-`DefaultResolver`). Kept because `erc721_vault` + `erc1155_vault` still resolve through it via `addressManager()` (their `resolver()` reverts) — verified on-chain: `getAddress(1,"erc721_vault")` returns the vault, `getAddress(1,"bridge")` returns the bridge. `bridge` + `erc20_vault` were migrated to shared_resolver `0x8Efa01564425692d0a0838DC10E300BD310Cb43e`.
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

## Rollup Specific

### inbox

- proxy : `0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f`
- impl : `0x64523f2580f4E7038a121D55b220a9C12C1E8f01`
- logs:
  - implementation deployed on Mar 4, 2026 @commit `3c66b0f8d` @tx `0x8a7c1e426b8fb8d7c00c7ffd9d1c41e3ce907f57f696f18fe3718abcd234a6de`
  - proxy deployed on Mar 4, 2026 @commit `3c66b0f8d` @tx `0x7576f1179250453948b37648a748aaade28c40b33e358fa0cbe21be6b0368601`
  - upgraded to `0x64523f2580f4E7038a121D55b220a9C12C1E8f01` on Jun 29, 2026 @commit`462920aae` @tx`0xae7122add731c935d54d726ebe542e7d4f9f7321e3bdf4ec794309f813d981f7` (Proposal0017)

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

#### sgx_geth_automata

- proxy : `0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261`
- impl : `0x5e46443bd131eB6d4c6Fb4849bAD29af9596dd72`
- owner : `controller.taiko.eth`
- logs:
  - deployed on May 15, 2025 @commit `cf55838` @tx `0x7486b942c054eb6641ea701f0835d23fa606accad0e96051791da26c56a10771`

### token_unlock

- impl: `0x5c475bB14727833394b0704266f14157678A72b6`
- logs:
  - deployed @commit`bca493f` @tx`0x0a4a63715257b766ca06e7e87ee25088d557c460e50120208b31666c83fc68bc`
  - deployed @commit`3d89d24` @tx`0x28fdfb26c1409e420fe9ecce22063fa70efdbe56359aeacf9f65e68db8b8d34a`
  - deployed @PR[19457](https://github.com/taikoxyz/taiko-mono/pull/19457/files) @tx`0xfa94bc59c0bc52131a418598780c4e289a13407143a7bdf54c871b5cec35d0b0`

### sgx_verifier_reth

- impl : `0x9D3C595BFf6Ff7D2b2CbdEcF94aD917eB2fCFFd8`
- logs:
  - deployed on Mar 4, 2026 @commit `3c66b0f8d` @tx `0x5f76012a42f150330fd01824ce6b6c55f9695b2fb2dd3a25f6b9a1a82e90d437`
  - upgraded to `0x9D3C595BFf6Ff7D2b2CbdEcF94aD917eB2fCFFd8` on Jun 25, 2026 @commit`b73608696` @tx`0xbf692bdeb84725573c8d2fc6589e6db53db7477403900c7c24f559d769d5c6b1` (Proposal0017)

### sgx_verifier_geth

- impl : `0x41e79EB4F03aBB5DF8716B759528dc5d8f6a84Ee`
- logs:
  - deployed on Mar 4, 2026 @commit `3c66b0f8d` @tx `0x8e1982ca9273a77d9d39fedf0c17620f28469da9b79a1e6df0bd002f8a25a5fd`
  - upgraded to `0x41e79EB4F03aBB5DF8716B759528dc5d8f6a84Ee` on Jun 25, 2026 @commit`b73608696` @tx`0xfa680d3a56248a3e3802f7f1f93b63c55a19ed1330281e5c6143738c849ef31c` (Proposal0017)

### risc0_verifier

- impl : `0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b`
- logs:
  - deployed on Mar 4, 2026 @commit `3c66b0f8d` @tx `0xff70e373b4ff4f0f4a5fdd7b1709d6d3be74ea21426fa05e315d90adb81637a8`
  - reused (unchanged) by the Proposal0017 recovery MainnetVerifier `0x71808449…` — its `risc0RethVerifier()` returns this address. The active recovery verifier set is SGX-geth + SGX-reth + SP1 + RISC0.

### sp1_verifier

- impl : `0x73A0Db393ef87ce781ac7957bE10D6628432100F`
- logs:
  - deployed on Mar 4, 2026 @commit `3c66b0f8d` @tx `0xe29fb424175bfe33dc401026026bc40e03dc0ee38d833edb33b698f55c89bacb`
  - upgraded to `0x73A0Db393ef87ce781ac7957bE10D6628432100F` on Jun 27, 2026 @commit`462920aae` @tx`0xccec9c500467272fdee5b6df1b377b212e74944446f29e6df6902b07c7a63177` (Proposal0017)

### mainnet_verifier

- impl : `0x71808449A6217898d602c1a392D95b931Ac5d878`
- logs:
  - deployed on Mar 4, 2026 @commit `3c66b0f8d` @tx `0x18e0a43926b02144951bc6f0c233667f9f40651a3b86e9b575c09768f9670d13`
  - upgraded to `0x71808449A6217898d602c1a392D95b931Ac5d878` on Jun 27, 2026 @commit`462920aae` @tx`0x6f26b1ee9c0965df9dc4ec14bd5721fa6f2041e17e18bd87f7a7d04eebc0dcd9` (Proposal0017)

### preconf_whitelist

- proxy : `0xFD019460881e6EeC632258222393d5821029b2ac`
- impl : `0xDBae46E35C18719E6c78aaBF9c8869c4eC84c149`
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
  - upgraded to `0xDBae46E35C18719E6c78aaBF9c8869c4eC84c149` on Mar 31, 2026 @commit`3c66b0f8d` (Proposal0009)

### prover_whitelist

- proxy : `0xEa798547d97e345395dA071a0D7ED8144CD612Ae`
- impl : `0xebb393746A4Eee84Ad14EDFf3764c3F839D1034b`
- logs:
  - implementation deployed on Mar 4, 2026 @commit `3c66b0f8d` @tx `0x3281686f0d3ce87d69fcc0a0c1a92d87574b29fbd348cd944bf9f38fa5012153`
  - proxy deployed on Mar 4, 2026 @commit `3c66b0f8d` @tx `0x9ae9f5d95306d569099fbf42c0aa730a6b6e84e18f35e5f1a1374025597762d5`

## Taiko DAO Specific

### MainnetDAOController

- ens: `controller.taiko.eth`
- proxy: `0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a`
- Owner (Taiko DAO): `0x9CDf589C941ee81D75F34d3755671d614f7cf261`
- impl: `0x4347df63bdC82b8835fC9FF47bC5a71a12cC0f06`
