# Changelog

## [2.2.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-client-rs-v2.1.0...taiko-alethia-client-rs-v2.2.0) (2026-07-15)


### Features

* **taiko-client-rs:** keep proposer alive on tx reverts ([#21904](https://github.com/taikoxyz/taiko-mono/issues/21904)) ([4aba77b](https://github.com/taikoxyz/taiko-mono/commit/4aba77b1986cab33ee9d54aa77f78848cf892c47))
* **taiko-client-rs:** log preconfirmation peer ticks ([#21880](https://github.com/taikoxyz/taiko-mono/issues/21880)) ([00465ea](https://github.com/taikoxyz/taiko-mono/commit/00465eaa148ff3890a0457068266747b28482ed9))
* **taiko-client,taiko-client-rs:** restore forced inclusion propose inputs ([#21936](https://github.com/taikoxyz/taiko-mono/issues/21936)) ([2d7fd1a](https://github.com/taikoxyz/taiko-mono/commit/2d7fd1a3e76505652a6adee6d24278affa6ddd9c))


### Bug Fixes

* **taiko-client-rs:** avoid forced inclusions in propose input ([#21851](https://github.com/taikoxyz/taiko-mono/issues/21851)) ([61fec74](https://github.com/taikoxyz/taiko-mono/commit/61fec74e22e8fc0ae3df3d526babc6f84009f193))
* **taiko-client-rs:** decode legacy transactions in preconfirmation tx-lists ([#21906](https://github.com/taikoxyz/taiko-mono/issues/21906)) ([033bd94](https://github.com/taikoxyz/taiko-mono/commit/033bd94be3d90617fc2a1dab00d49cfcd96348bb))
* **taiko-client-rs:** degrade undecodable derivation source blob to default payload ([#21854](https://github.com/taikoxyz/taiko-mono/issues/21854)) ([eb3bc25](https://github.com/taikoxyz/taiko-mono/commit/eb3bc250f1eac1a7b93cba66ceb8baa4d8b34a85))
* **taiko-client-rs:** enforce strict engine status checks in driver payload submission ([#21949](https://github.com/taikoxyz/taiko-mono/issues/21949)) ([a062a61](https://github.com/taikoxyz/taiko-mono/commit/a062a612fac35b5e83dedcc9367efd8ea0d48238))
* **taiko-client-rs:** keep release lockfile current ([#21780](https://github.com/taikoxyz/taiko-mono/issues/21780)) ([c4786c2](https://github.com/taikoxyz/taiko-mono/commit/c4786c2bcd898c4674d8e1a8a4bfb26b95cdeb3e))
* **taiko-client-rs:** prevent derivation panic on oversized manifest size field ([#21948](https://github.com/taikoxyz/taiko-mono/issues/21948)) ([f91132c](https://github.com/taikoxyz/taiko-mono/commit/f91132c4dcfa4f23f0a97192de465f6f3aef784c))
* **taiko-client-rs:** recover from scanner lag and reorged-out proposal logs in event sync ([#21950](https://github.com/taikoxyz/taiko-mono/issues/21950)) ([9c19514](https://github.com/taikoxyz/taiko-mono/commit/9c19514686a80ba534ebafeba8143461e4f43e5f))
* **taiko-client-rs:** report execution head in /status when unsafe counter lags it ([#21777](https://github.com/taikoxyz/taiko-mono/issues/21777)) ([e263a73](https://github.com/taikoxyz/taiko-mono/commit/e263a73597a9073fc3135c4d34e79c3a6bd12224))
* **taiko-client-rs:** survive checkpoint sync handoff and harden the catch-up loop ([#21900](https://github.com/taikoxyz/taiko-mono/issues/21900)) ([52c3e77](https://github.com/taikoxyz/taiko-mono/commit/52c3e77ed34cdd0a674911ad54bf70f930acfded))
* **taiko-client-rs:** taiko-geth wire compat, proposer manifest fixes, and bounded event-sync retries ([#21958](https://github.com/taikoxyz/taiko-mono/issues/21958)) ([4679d0d](https://github.com/taikoxyz/taiko-mono/commit/4679d0d3cb04f0c37b37cb1a8f1eb8cd443985b8))


### Chores

* **protocol:** merge taiko-alethia-protocol-v3.0.0 (v3.1.0 + hardening) back to main ([f837160](https://github.com/taikoxyz/taiko-mono/commit/f83716070331945133adc283b765083501f21e4b))
* **protocol:** record the v3.0.0 merge ancestry (take 2) ([9646f55](https://github.com/taikoxyz/taiko-mono/commit/9646f553cd89abe95fab9745c17a46273c4d4bd0))
* **protocol:** record the v3.0.0 merge ancestry (take 2) ([bc35381](https://github.com/taikoxyz/taiko-mono/commit/bc35381393888f6c3dfe81d24eb6193255c0c49a))
* **protocol:** record the v3.0.0 merge ancestry lost by squashing [#21922](https://github.com/taikoxyz/taiko-mono/issues/21922) ([#21930](https://github.com/taikoxyz/taiko-mono/issues/21930)) ([ca16fba](https://github.com/taikoxyz/taiko-mono/commit/ca16fba34ca276975b4c5179489c8eec3f25a0db))
* **taiko-client-rs:** bump execution client dependencies ([#21801](https://github.com/taikoxyz/taiko-mono/issues/21801)) ([48caa9e](https://github.com/taikoxyz/taiko-mono/commit/48caa9e385f52659deee6a85faeb1b04f81df48a))
* **taiko-client-rs:** harden whitelist preconfirmation ingress ([#21943](https://github.com/taikoxyz/taiko-mono/issues/21943)) ([f1e84ae](https://github.com/taikoxyz/taiko-mono/commit/f1e84ae5d0cae84809895260104d74cb5f19f183))
* **taiko-client-rs:** reject trailing bytes after manifest RLP ([#21911](https://github.com/taikoxyz/taiko-mono/issues/21911)) ([d23ec01](https://github.com/taikoxyz/taiko-mono/commit/d23ec013e4c28dd95abe98415c108797b2db8b40))
* **taiko-client-rs:** simplify and harden the test harness ([#21914](https://github.com/taikoxyz/taiko-mono/issues/21914)) ([3f77845](https://github.com/taikoxyz/taiko-mono/commit/3f77845e9cfbea9b3dfb71e91fbea74c65278efa))
* **taiko-client,taiko-client-rs:** bump execution client deps ([#21941](https://github.com/taikoxyz/taiko-mono/issues/21941)) ([3a99ab1](https://github.com/taikoxyz/taiko-mono/commit/3a99ab186f878a4b18c4b432740e8df8381adbe6))


### Code Refactoring

* **taiko-client-rs:** drop the `Client<P>` provider generic ([#21925](https://github.com/taikoxyz/taiko-mono/issues/21925)) ([77ede38](https://github.com/taikoxyz/taiko-mono/commit/77ede383fc790f63a6e10ee1963d5da913c98901))
* **taiko-client-rs:** move permissionless preconfirmation to its own branch ([#21908](https://github.com/taikoxyz/taiko-mono/issues/21908)) ([37f8e27](https://github.com/taikoxyz/taiko-mono/commit/37f8e270a812953ba5c26abbe1736d8f53ee0b3d))
* **taiko-client-rs:** simplify whitelist preconfirmation driver ([#21913](https://github.com/taikoxyz/taiko-mono/issues/21913)) ([081d91c](https://github.com/taikoxyz/taiko-mono/commit/081d91c975bd84cc407130038f12cd627b75425c))
* **taiko-client-rs:** sweep quick-win cleanups across crates ([#21926](https://github.com/taikoxyz/taiko-mono/issues/21926)) ([fd8b35a](https://github.com/taikoxyz/taiko-mono/commit/fd8b35a3583155377ab63e24b19522e669c62f34))


### Workflow

* **taiko-client-rs:** enable signer recovery for net builds ([#21944](https://github.com/taikoxyz/taiko-mono/issues/21944)) ([2a752ad](https://github.com/taikoxyz/taiko-mono/commit/2a752addafd6bf4fc1a67443e82513ecaf484b2d))

## [2.1.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-client-rs-v2.0.0...taiko-alethia-client-rs-v2.1.0) (2026-06-12)


### Features

* **protocol,taiko-client,taiko-client-rs:** raise Unzen derivation source block limit ([#21600](https://github.com/taikoxyz/taiko-mono/issues/21600)) ([189d6d4](https://github.com/taikoxyz/taiko-mono/commit/189d6d47e20d49f0105a56b3a0b8c9fc2aed07bb))
* **protocol:** remove MIN_ANCHOR_OFFSET from Shasta derivation ([#20967](https://github.com/taikoxyz/taiko-mono/issues/20967)) ([1423e4a](https://github.com/taikoxyz/taiko-mono/commit/1423e4a0550cbf210a74c129a47da530195d7915))
* **taiko-client-rs:** add `preconfirmation-client` SDK crate for P2P network integration ([#21018](https://github.com/taikoxyz/taiko-mono/issues/21018)) ([d0b6029](https://github.com/taikoxyz/taiko-mono/commit/d0b60299fe3292b34464deb59d4d391dbaafae3b))
* **taiko-client-rs:** add comprehensive metrics and observability instrumentation for whitelist preconfirmation driver ([#21300](https://github.com/taikoxyz/taiko-mono/issues/21300)) ([c9f18ec](https://github.com/taikoxyz/taiko-mono/commit/c9f18ec2d9d1c74b30e277414a5d7b40a955264e))
* **taiko-client-rs:** add engine mode for payload building via FCU + get_payload ([#21186](https://github.com/taikoxyz/taiko-mono/issues/21186)) ([01d7b25](https://github.com/taikoxyz/taiko-mono/commit/01d7b25528747c205f5c81dbb522bd10207792cb))
* **taiko-client-rs:** add function to decode a single blob ([#21318](https://github.com/taikoxyz/taiko-mono/issues/21318)) ([e0aeb19](https://github.com/taikoxyz/taiko-mono/commit/e0aeb1965898eb9f84600a4d7e07cb51ce416023))
* **taiko-client-rs:** add loopback delivery for local RPC publishes ([#21386](https://github.com/taikoxyz/taiko-mono/issues/21386)) ([1dcf91c](https://github.com/taikoxyz/taiko-mono/commit/1dcf91c3402a0a6bbfacab157ba7edda9a436ea1))
* **taiko-client-rs:** add preconfirmation entry logs ([#21745](https://github.com/taikoxyz/taiko-mono/issues/21745)) ([494002c](https://github.com/taikoxyz/taiko-mono/commit/494002c42a84a1db89c64f6fa4039f3220ef7a50))
* **taiko-client-rs:** add preconfirmation P2P raw identity flag ([#21723](https://github.com/taikoxyz/taiko-mono/issues/21723)) ([4986c7d](https://github.com/taikoxyz/taiko-mono/commit/4986c7d63dd9380ea2cca96cff785b29c67ec894))
* **taiko-client-rs:** add reqresp direct lookup path ([#21379](https://github.com/taikoxyz/taiko-mono/issues/21379)) ([007d635](https://github.com/taikoxyz/taiko-mono/commit/007d6356970ae4f8adf1019c2e250b731a38ce4b))
* **taiko-client-rs:** add whitelist preconf RPC server and P2P publishing ([#21312](https://github.com/taikoxyz/taiko-mono/issues/21312)) ([00bad73](https://github.com/taikoxyz/taiko-mono/commit/00bad7336046cb71c05aea8f59499b45296a92eb))
* **taiko-client-rs:** add whitelist preconfirmation driver and optimize envelope cache ([#21289](https://github.com/taikoxyz/taiko-mono/issues/21289)) ([f6faa5c](https://github.com/taikoxyz/taiko-mono/commit/f6faa5c45fd990fed540623a09fdd3f0448dd575))
* **taiko-client-rs:** adopt `tx-manager` for proposal submission ([#21513](https://github.com/taikoxyz/taiko-mono/issues/21513)) ([0a1b18a](https://github.com/taikoxyz/taiko-mono/commit/0a1b18ac2673a697c77c31056b5c7f9786de6b41))
* **taiko-client-rs:** advertise whitelist p2p enode address ([#21730](https://github.com/taikoxyz/taiko-mono/issues/21730)) ([285d457](https://github.com/taikoxyz/taiko-mono/commit/285d4576b80317d9f29030a66e1fd19cc9de7843))
* **taiko-client-rs:** allow multiple blobs to be coded into sidecar ([#20955](https://github.com/taikoxyz/taiko-mono/issues/20955)) ([85125ec](https://github.com/taikoxyz/taiko-mono/commit/85125ec7f87437f5164b0d4b26d4d631656c4e6c))
* **taiko-client-rs:** expose canShutdown on whitelist preconf /status ([#21656](https://github.com/taikoxyz/taiko-mono/issues/21656)) ([2d2745b](https://github.com/taikoxyz/taiko-mono/commit/2d2745bcffaf312d17e9a097240736e1a789aa2c))
* **taiko-client-rs:** extend `PreconfSignerResolver` trait ([#21117](https://github.com/taikoxyz/taiko-mono/issues/21117)) ([c6bdcb9](https://github.com/taikoxyz/taiko-mono/commit/c6bdcb9f41924ff9b3f900bd55c581ddeadc5f54))
* **taiko-client-rs:** fallback search for `start_tag` by inbox activation timestamp ([#20813](https://github.com/taikoxyz/taiko-mono/issues/20813)) ([41ca4aa](https://github.com/taikoxyz/taiko-mono/commit/41ca4aa8f15bdf7a960b701ced41e6ea6b43d09b))
* **taiko-client-rs:** gate net dependencies for zkvm ([#21204](https://github.com/taikoxyz/taiko-mono/issues/21204)) ([c1365d3](https://github.com/taikoxyz/taiko-mono/commit/c1365d39b6e2929c576f4f7f595015017e76a0d9))
* **taiko-client-rs:** gate ticks by preconfirmation whitelist in proposer ([#21626](https://github.com/taikoxyz/taiko-mono/issues/21626)) ([19d0e98](https://github.com/taikoxyz/taiko-mono/commit/19d0e98df125e1f40658254df92db1544984900f))
* **taiko-client-rs:** get_preconf_slot_info API for the taiko-client-rs ([#21279](https://github.com/taikoxyz/taiko-mono/issues/21279)) ([26f8c95](https://github.com/taikoxyz/taiko-mono/commit/26f8c958b33f29edeeabe4483dd084bb47aca089))
* **taiko-client-rs:** handle L1 finalized block RPC error ([#21495](https://github.com/taikoxyz/taiko-mono/issues/21495)) ([92e1c5f](https://github.com/taikoxyz/taiko-mono/commit/92e1c5f2dd572799b07a5c8f275febb7a1aeb6de))
* **taiko-client-rs:** handle L1 finalized block RPC error ([#21495](https://github.com/taikoxyz/taiko-mono/issues/21495)) ([e634165](https://github.com/taikoxyz/taiko-mono/commit/e634165995ae727f1edc63b15f6d251c41ad54d0))
* **taiko-client-rs:** import whitelist preconf blocks at genesis ([#21717](https://github.com/taikoxyz/taiko-mono/issues/21717)) ([bb272c2](https://github.com/taikoxyz/taiko-mono/commit/bb272c2ed36cdf57d4b2a50156615bf96a67716a))
* **taiko-client-rs:** introduce `LookaheadResolver` ([#20905](https://github.com/taikoxyz/taiko-mono/issues/20905)) ([23e3ea0](https://github.com/taikoxyz/taiko-mono/commit/23e3ea0b31b6c4eac980f107643fb6795877015d))
* **taiko-client-rs:** introduce preconfirmation interface ([#20871](https://github.com/taikoxyz/taiko-mono/issues/20871)) ([e30d8b5](https://github.com/taikoxyz/taiko-mono/commit/e30d8b5f01ad9ab4c7689b0329c23f0fa0bec76a))
* **taiko-client-rs:** introduce Rust driver RPC for permission-less preconfirmation ([#21132](https://github.com/taikoxyz/taiko-mono/issues/21132)) ([1f58006](https://github.com/taikoxyz/taiko-mono/commit/1f58006e1d1cbb9bbf56432b09a4ccf235f5e688))
* **taiko-client-rs:** make finalized proposal id optional in shasta derivation ([#21487](https://github.com/taikoxyz/taiko-mono/issues/21487)) ([67cfa98](https://github.com/taikoxyz/taiko-mono/commit/67cfa980789210646babd10654061579db8226ff))
* **taiko-client-rs:** metrics refactor ([#21751](https://github.com/taikoxyz/taiko-mono/issues/21751)) ([47f279e](https://github.com/taikoxyz/taiko-mono/commit/47f279e791e3179eb3da173e284845e9a73db3d8))
* **taiko-client-rs:** prevent preconfirmation reorgs of event-synced L2 history ([#21316](https://github.com/taikoxyz/taiko-mono/issues/21316)) ([3b01390](https://github.com/taikoxyz/taiko-mono/commit/3b01390f41bbbc24209f9dccadb644513468a1f3))
* **taiko-client-rs:** reconcile head L1 origin after reorg ([#21660](https://github.com/taikoxyz/taiko-mono/issues/21660)) ([13151be](https://github.com/taikoxyz/taiko-mono/commit/13151be1143be5e2930ae262ae8c22320448434d))
* **taiko-client-rs:** refactor `preconfirmation-client` into `preconfirmation-driver` with embedded driver support ([#21200](https://github.com/taikoxyz/taiko-mono/issues/21200)) ([a33b8f7](https://github.com/taikoxyz/taiko-mono/commit/a33b8f7d23a225cdb5f9774d911b84b957abd0cd))
* **taiko-client-rs:** rename RPC to REST and harden REST server ([#21326](https://github.com/taikoxyz/taiko-mono/issues/21326)) ([8db8de2](https://github.com/taikoxyz/taiko-mono/commit/8db8de2f7a0e25b3faaa592649dbbed155978118))
* **taiko-client-rs:** replace lookahead-based whitelist validation with configured sequencer allowlist ([#21329](https://github.com/taikoxyz/taiko-mono/issues/21329)) ([2b030b9](https://github.com/taikoxyz/taiko-mono/commit/2b030b9d756560f5c27888f63649c0b6314ab7e1))
* **taiko-client-rs:** rust client updates based on sequential proving ([#20921](https://github.com/taikoxyz/taiko-mono/issues/20921)) ([073b2bd](https://github.com/taikoxyz/taiko-mono/commit/073b2bdef88500d89c54db8dbad5eb3297865160))
* **taiko-client-rs:** skip orphaned proposal logs during event sync ([#21490](https://github.com/taikoxyz/taiko-mono/issues/21490)) ([ccf71eb](https://github.com/taikoxyz/taiko-mono/commit/ccf71eb9ef6051913769b1e5131a68f622ecb384))
* **taiko-client-rs:** strict inbound preconf gossipsub validation ([#21328](https://github.com/taikoxyz/taiko-mono/issues/21328)) ([1e80e32](https://github.com/taikoxyz/taiko-mono/commit/1e80e32b409f2ed7e35814ef70d74747bcecbce9))
* **taiko-client-rs:** support configurable L1 transports ([#21450](https://github.com/taikoxyz/taiko-mono/issues/21450)) ([8a07036](https://github.com/taikoxyz/taiko-mono/commit/8a070365713e0f3e8910287736dffefea69c78f9))
* **taiko-client-rs:** update for latest `alethia-reth` Uzen semantics ([#21556](https://github.com/taikoxyz/taiko-mono/issues/21556)) ([1b5f765](https://github.com/taikoxyz/taiko-mono/commit/1b5f765f964e4e140aec71b667642cdae6c32812))
* **taiko-client-rs:** update Rust contract bindings ([#20812](https://github.com/taikoxyz/taiko-mono/issues/20812)) ([c29c755](https://github.com/taikoxyz/taiko-mono/commit/c29c755b8e35237582ccb175cbb6bf8b13086891))
* **taiko-client-rs:** wire finalized Shasta proposal into forkchoice updates ([#20809](https://github.com/taikoxyz/taiko-mono/issues/20809)) ([a1a72e4](https://github.com/taikoxyz/taiko-mono/commit/a1a72e423f0e145cea9fee48b7d797f99a086108))
* **taiko-client,taiko-client-rs:** add devnet Uzen time override flag ([#21566](https://github.com/taikoxyz/taiko-mono/issues/21566)) ([f72c38d](https://github.com/taikoxyz/taiko-mono/commit/f72c38d51f09178aa897d738cc3da6846795843b))
* **taiko-client,taiko-client-rs:** align Shasta manifest validation with the latest protocol updates ([#20775](https://github.com/taikoxyz/taiko-mono/issues/20775)) ([5e18853](https://github.com/taikoxyz/taiko-mono/commit/5e18853b253d7c4e8db2d8c547870c11a3af45d9))
* **taiko-client,taiko-client-rs:** carry Uzen `header.difficulty` on preconfirmation gossip wire ([#21576](https://github.com/taikoxyz/taiko-mono/issues/21576)) ([539e986](https://github.com/taikoxyz/taiko-mono/commit/539e9867d4eeace708ef0f0e994528f540abc098))
* **taiko-client,taiko-client-rs:** changes based on protocol PR [#20986](https://github.com/taikoxyz/taiko-mono/issues/20986) ([#20990](https://github.com/taikoxyz/taiko-mono/issues/20990)) ([07ad17c](https://github.com/taikoxyz/taiko-mono/commit/07ad17c95415e113e3c8759c615a8ea21d7865c5))
* **taiko-client,taiko-client-rs:** changes based on the latest Shasta consecutive proofs submission design ([#20979](https://github.com/taikoxyz/taiko-mono/issues/20979)) ([f9e6bc4](https://github.com/taikoxyz/taiko-mono/commit/f9e6bc4ed50e787ab012606528bb6ea16891bab6))
* **taiko-client,taiko-client-rs:** client updates for moving bond processing to L1 ([#21078](https://github.com/taikoxyz/taiko-mono/issues/21078)) ([68fa85d](https://github.com/taikoxyz/taiko-mono/commit/68fa85d6c4f5386a723f86d3e9224acc8e5fb341))
* **taiko-client,taiko-client-rs:** make anchor/timestamp offsets chain-aware ([#21427](https://github.com/taikoxyz/taiko-mono/issues/21427)) ([2dc51f0](https://github.com/taikoxyz/taiko-mono/commit/2dc51f0540984db28614c1cc91882dd7e3dd8dfb))
* **taiko-client,taiko-client-rs:** only allow one block per forced inclusion ([#20778](https://github.com/taikoxyz/taiko-mono/issues/20778)) ([685445a](https://github.com/taikoxyz/taiko-mono/commit/685445abe0c753b35832a8e5064110e281c7012f))
* **taiko-client,taiko-client-rs:** remove `--propose.anchorOffset` flag ([#21053](https://github.com/taikoxyz/taiko-mono/issues/21053)) ([eb0f198](https://github.com/taikoxyz/taiko-mono/commit/eb0f198dbbe8f9b03cf40629c1277cdd5d952195))
* **taiko-client,taiko-client-rs:** remove `designatedProver` from `transition` ([#21109](https://github.com/taikoxyz/taiko-mono/issues/21109)) ([98d9135](https://github.com/taikoxyz/taiko-mono/commit/98d9135ee3ff808cbc57f5b410bdc960b0e95052))
* **taiko-client,taiko-client-rs:** rename Unzen fork ([#21599](https://github.com/taikoxyz/taiko-mono/issues/21599)) ([1252842](https://github.com/taikoxyz/taiko-mono/commit/125284295ac78e45bc2f3d742b6022eb3ebfb50a))
* **taiko-client,taiko-client-rs:** update `BLOCK_GAS_LIMIT_MAX_CHANGE` to `200` ([#21114](https://github.com/taikoxyz/taiko-mono/issues/21114)) ([56353ce](https://github.com/taikoxyz/taiko-mono/commit/56353ce2b8554036158e57f176f336e33fe0d87d))
* **taiko-client,taiko-client-rs:** update `MaxBlockGasLimit` to `45_000_000` ([#20788](https://github.com/taikoxyz/taiko-mono/issues/20788)) ([4f31233](https://github.com/taikoxyz/taiko-mono/commit/4f31233fed5e1829b84f5e5a740ac8c7a46ccccf))
* **taiko-client,taiko-client-rs:** update `Proposed` event signature ([#21052](https://github.com/taikoxyz/taiko-mono/issues/21052)) ([5b94117](https://github.com/taikoxyz/taiko-mono/commit/5b94117a56ecad2b44c9c4cee4453ead5459c450))
* **taiko-client,taiko-client-rs:** update blob offset validation for Shasta proposals ([#21148](https://github.com/taikoxyz/taiko-mono/issues/21148)) ([74194df](https://github.com/taikoxyz/taiko-mono/commit/74194df5edfd809fc70335b1211abd074292e6e5))
* **taiko-client,taiko-client-rs:** update Go / Rust contract bindings ([#21011](https://github.com/taikoxyz/taiko-mono/issues/21011)) ([fc8c3fb](https://github.com/taikoxyz/taiko-mono/commit/fc8c3fbfd3e82d6bf6d3d19ee1ab45e90d175caa))
* **taiko-client,taiko-client-rs:** update Go / Rust contract bindings ([#21019](https://github.com/taikoxyz/taiko-mono/issues/21019)) ([6fb8bb2](https://github.com/taikoxyz/taiko-mono/commit/6fb8bb22212b7bd72f66f4b17a80f993f4f0173c))
* **taiko-client,taiko-client-rs:** update Go / Rust contract bindings ([#21026](https://github.com/taikoxyz/taiko-mono/issues/21026)) ([d8741f1](https://github.com/taikoxyz/taiko-mono/commit/d8741f16b36db30c200b1592310c3d85b625a16c))
* **taiko-client,taiko-client-rs:** update Go / Rust contract bindings ([#21035](https://github.com/taikoxyz/taiko-mono/issues/21035)) ([9ee7108](https://github.com/taikoxyz/taiko-mono/commit/9ee7108bfa23a485307affbb291006732354b2e4))
* **taiko-client,taiko-client-rs:** update Go / Rust contract bindings ([#21050](https://github.com/taikoxyz/taiko-mono/issues/21050)) ([a0d76ba](https://github.com/taikoxyz/taiko-mono/commit/a0d76ba7681bb1d8ecbe72647da8726786becf14))
* **taiko-client,taiko-client-rs:** updates related to new Shasta `Proposed` event ([#21040](https://github.com/taikoxyz/taiko-mono/issues/21040)) ([d29355a](https://github.com/taikoxyz/taiko-mono/commit/d29355abbb89bdd91b98ff4b7147bf560327baba))


### Bug Fixes

* **taiko-client-rs:** add DNS support to libp2p transport configuration ([#21355](https://github.com/taikoxyz/taiko-mono/issues/21355)) ([d7840f2](https://github.com/taikoxyz/taiko-mono/commit/d7840f2b9ed4a512d2499ff8d7f974b696ae99ba))
* **taiko-client-rs:** add TTL cache for whitelist sequencer lookups ([#21299](https://github.com/taikoxyz/taiko-mono/issues/21299)) ([28ffca4](https://github.com/taikoxyz/taiko-mono/commit/28ffca468489e87f16362786e323a502f03ba755))
* **taiko-client-rs:** align /status and fee range checks with go ([#21335](https://github.com/taikoxyz/taiko-mono/issues/21335)) ([06f7ec0](https://github.com/taikoxyz/taiko-mono/commit/06f7ec032d60ba6e657107953c2992cbb5b60c1b))
* **taiko-client-rs:** better caching based on nethermind code ([#21304](https://github.com/taikoxyz/taiko-mono/issues/21304)) ([4414a7c](https://github.com/taikoxyz/taiko-mono/commit/4414a7ca1a1f46b7431ec44cf81660e2d6c690fe))
* **taiko-client-rs:** call `set_devnet_uzen_override` after `init_logs` ([#21567](https://github.com/taikoxyz/taiko-mono/issues/21567)) ([4c57323](https://github.com/taikoxyz/taiko-mono/commit/4c573235f2c1976337cdf1f86e67ca2a0792c372))
* **taiko-client-rs:** defer whitelist preconf driver timeouts instead of crashing ([#21568](https://github.com/taikoxyz/taiko-mono/issues/21568)) ([b67b175](https://github.com/taikoxyz/taiko-mono/commit/b67b17582f11d1f6fe64f880fb8bc3bb258ddbc7))
* **taiko-client-rs:** fix docker build CI ([#21140](https://github.com/taikoxyz/taiko-mono/issues/21140)) ([6088b45](https://github.com/taikoxyz/taiko-mono/commit/6088b4536af01246ea31ada33cb61a5ac759816c))
* **taiko-client-rs:** fix tx-list RLP format in whitelist preconfirmation zlib codec ([#21310](https://github.com/taikoxyz/taiko-mono/issues/21310)) ([ad01db8](https://github.com/taikoxyz/taiko-mono/commit/ad01db86ae43a3ed6ab1f271527aa88aba9a7d1b))
* **taiko-client-rs:** ignore self preconfirmation gossip ([#21726](https://github.com/taikoxyz/taiko-mono/issues/21726)) ([23cddae](https://github.com/taikoxyz/taiko-mono/commit/23cddaecdf1b566779b13ac387b902555ad7d3d6))
* **taiko-client-rs:** make Shasta event sync resilient on genesis and pre-finality startup ([#21348](https://github.com/taikoxyz/taiko-mono/issues/21348)) ([9e5b426](https://github.com/taikoxyz/taiko-mono/commit/9e5b426c33cd1b8bc73fd838122b752b9986a0d8))
* **taiko-client-rs:** preconf_tip fallback ([#21413](https://github.com/taikoxyz/taiko-mono/issues/21413)) ([6fa6bd0](https://github.com/taikoxyz/taiko-mono/commit/6fa6bd0c92386aaff294bbb7738513b736423ff6))
* **taiko-client-rs:** reconcile highestUnsafeL2PayloadBlockID to reth head after L1 reorg ([#21744](https://github.com/taikoxyz/taiko-mono/issues/21744)) ([fe5b6d2](https://github.com/taikoxyz/taiko-mono/commit/fe5b6d2f4e9a172229c4d63ca2c18589629c4f22))
* **taiko-client-rs:** remove anchor gas subtraction from engine params gas limit ([#21203](https://github.com/taikoxyz/taiko-mono/issues/21203)) ([4999719](https://github.com/taikoxyz/taiko-mono/commit/4999719d512b13584a88617faff3d32affca3a8b))
* **taiko-client-rs:** retry timed-out preconf submissions and reconnect event sync ([#21505](https://github.com/taikoxyz/taiko-mono/issues/21505)) ([ca2984d](https://github.com/taikoxyz/taiko-mono/commit/ca2984d1c736d093df4d8d90b97e03ed0999f408))
* **taiko-client-rs:** retry whitelist preconfirmation peer dials ([#21705](https://github.com/taikoxyz/taiko-mono/issues/21705)) ([795728d](https://github.com/taikoxyz/taiko-mono/commit/795728dcec307ac46039c7077041c06cc734e76b))
* **taiko-client-rs:** should use lower rpc L2 block number for resume ([#21577](https://github.com/taikoxyz/taiko-mono/issues/21577)) ([eaee3a9](https://github.com/taikoxyz/taiko-mono/commit/eaee3a939e6ba37696ab19ec2b96881a3c4666f1))
* **taiko-client-rs:** skip stale finalized hint for current proposal ([#21694](https://github.com/taikoxyz/taiko-mono/issues/21694)) ([49efe2a](https://github.com/taikoxyz/taiko-mono/commit/49efe2a1365a703b62c07689b02d77686d7a317f))
* **taiko-client-rs:** support `enode://` bootnode URLs in whitelist preconfirmation driver ([#21309](https://github.com/taikoxyz/taiko-mono/issues/21309)) ([7a9d99b](https://github.com/taikoxyz/taiko-mono/commit/7a9d99bf29988e7a015f08cd28467d15797e5b8b))
* **taiko-client-rs:** tolerate transient RPC errors in whitelist preconfirmation event handler ([#21590](https://github.com/taikoxyz/taiko-mono/issues/21590)) ([cd84769](https://github.com/taikoxyz/taiko-mono/commit/cd84769c11333ae62ada4d353ccf30d08c14574c))
* **taiko-client-rs:** use trusted resume head for event sync (checkpoint head or `head_l1_origin`) ([#21331](https://github.com/taikoxyz/taiko-mono/issues/21331)) ([c500e8a](https://github.com/taikoxyz/taiko-mono/commit/c500e8a5ece96080df8fd4ce11268b7bf94237b0))
* **taiko-client,taiko-client-rs:** default SHASTA fork path and make protocol dir configurable for bindings ([#21376](https://github.com/taikoxyz/taiko-mono/issues/21376)) ([461a0d1](https://github.com/taikoxyz/taiko-mono/commit/461a0d1cdfed9f0b9714255f4389c68fbefd961a))
* **taiko-client,taiko-client-rs:** only apply default low-bond manifests for normal proposer sources ([#20748](https://github.com/taikoxyz/taiko-mono/issues/20748)) ([aa1956a](https://github.com/taikoxyz/taiko-mono/commit/aa1956a2a65e2dccaab8c15f95844668fa2704ea))
* **taiko-client,taiko-client-rs:** update `TIMESTAMP_MAX_OFFSET` ([#20969](https://github.com/taikoxyz/taiko-mono/issues/20969)) ([4a49518](https://github.com/taikoxyz/taiko-mono/commit/4a495188afbdbddf41457d440762b89023b32d84))
* **taiko-client:** close event filter iterators ([#21374](https://github.com/taikoxyz/taiko-mono/issues/21374)) ([b4627ea](https://github.com/taikoxyz/taiko-mono/commit/b4627eaf7f4663e042005c6e23983b4e367cae98))


### Chores

* **deps:** bump the cargo group across 2 directories with 1 update ([#21518](https://github.com/taikoxyz/taiko-mono/issues/21518)) ([adf6875](https://github.com/taikoxyz/taiko-mono/commit/adf6875ed84ac3160b2a423ddcbf2f1bd042092c))
* **deps:** bump the cargo group across 5 directories with 1 update ([#21264](https://github.com/taikoxyz/taiko-mono/issues/21264)) ([75a5e00](https://github.com/taikoxyz/taiko-mono/commit/75a5e0019e12c1b9048c5837d208b4f9246624b2))
* **deps:** bump the cargo group across 5 directories with 2 updates ([#21116](https://github.com/taikoxyz/taiko-mono/issues/21116)) ([c76e37a](https://github.com/taikoxyz/taiko-mono/commit/c76e37a28d153f5b6407538f70ca28f0a93c82db))
* **deps:** migrate kona dependencies to ethereum-optimism/optimism and upgrade to v1.2.9 ([#21466](https://github.com/taikoxyz/taiko-mono/issues/21466)) ([411fffd](https://github.com/taikoxyz/taiko-mono/commit/411fffd7550abf0da4124b628130d5e4e9b17960))
* **ejector,repo,taiko-client-rs:** improve code comments clarity ([#21055](https://github.com/taikoxyz/taiko-mono/issues/21055)) ([486a6e3](https://github.com/taikoxyz/taiko-mono/commit/486a6e3b1aee009bb963d16e8482643c9a868730))
* **protocol,taiko-client,taiko-client-rs:** cherry pick pr 20762 ([#20763](https://github.com/taikoxyz/taiko-mono/issues/20763)) ([09ff83f](https://github.com/taikoxyz/taiko-mono/commit/09ff83f348c19ad11c920adc881dcc76ed62194d))
* **taiko-client-rs, taiko-client:** address ci timeout ([#21153](https://github.com/taikoxyz/taiko-mono/issues/21153)) ([3260855](https://github.com/taikoxyz/taiko-mono/commit/3260855ebba2c2bec87c06fad192dd6ef318af1a))
* **taiko-client-rs,ejector:** bump event-scanner to `v1.1.1` ([#21737](https://github.com/taikoxyz/taiko-mono/issues/21737)) ([729a43e](https://github.com/taikoxyz/taiko-mono/commit/729a43e0e0e22958c295bd7fbbb30cdde6b3ce06))
* **taiko-client-rs,preconfirmation-p2p:** enforce docs and `clippy` standards && update `AGENTS.md` ([#21333](https://github.com/taikoxyz/taiko-mono/issues/21333)) ([cf5991e](https://github.com/taikoxyz/taiko-mono/commit/cf5991e57ccfb8fa6bc4a72ab0e16784259141fa))
* **taiko-client-rs:** add more metrics for driver ([#20751](https://github.com/taikoxyz/taiko-mono/issues/20751)) ([9d10a1c](https://github.com/taikoxyz/taiko-mono/commit/9d10a1cf74dcd3ba3f6a740cfe310f2d47bb0884))
* **taiko-client-rs:** alethia reth update to 03fc0929b324aff68ee5bc26f1c0a8169b58060b ([#21458](https://github.com/taikoxyz/taiko-mono/issues/21458)) ([af0f38b](https://github.com/taikoxyz/taiko-mono/commit/af0f38b4596cafac1c10a2ec2c8ede807f72f553))
* **taiko-client-rs:** align Shasta manifest header decoding ([#21764](https://github.com/taikoxyz/taiko-mono/issues/21764)) ([d691584](https://github.com/taikoxyz/taiko-mono/commit/d691584a2c5ff30f9868e394ccc59b419e467a5b))
* **taiko-client-rs:** align Shasta parent anchor decoding with `taiko-client` ([#21532](https://github.com/taikoxyz/taiko-mono/issues/21532)) ([d7d9edb](https://github.com/taikoxyz/taiko-mono/commit/d7d9edb58c27af77ff48cad77035e245d16a9736))
* **taiko-client-rs:** build the LookaheadResolver with a scanner task ([#21295](https://github.com/taikoxyz/taiko-mono/issues/21295)) ([5d49db8](https://github.com/taikoxyz/taiko-mono/commit/5d49db858274dfa9404d2c303859ee8ea6e44120))
* **taiko-client-rs:** bump `alethia-reth` and tolerate Shasta origin lookup uncertainty ([#21227](https://github.com/taikoxyz/taiko-mono/issues/21227)) ([db069a2](https://github.com/taikoxyz/taiko-mono/commit/db069a26a40f4c1149e25c5eb3681ac47f0f42ff))
* **taiko-client-rs:** bump `alethia-reth` dependencies ([#21486](https://github.com/taikoxyz/taiko-mono/issues/21486)) ([3b5ac06](https://github.com/taikoxyz/taiko-mono/commit/3b5ac063e0ea363e978d03b7802a22496edb033f))
* **taiko-client-rs:** bump `event-scanner` to `0.8.0-alpha` ([#21024](https://github.com/taikoxyz/taiko-mono/issues/21024)) ([9961a31](https://github.com/taikoxyz/taiko-mono/commit/9961a314e8d8e041587f6984d6f6272fb7d75a96))
* **taiko-client-rs:** bump `event-scanner` to `1.0.0` ([#21174](https://github.com/taikoxyz/taiko-mono/issues/21174)) ([21ddb06](https://github.com/taikoxyz/taiko-mono/commit/21ddb0693c7188f0dd27fd3186a465a54d50b0c9))
* **taiko-client-rs:** bump `event-scanner` to `v1.0.0-rc.1` ([#21115](https://github.com/taikoxyz/taiko-mono/issues/21115)) ([07fe663](https://github.com/taikoxyz/taiko-mono/commit/07fe6630d168916b07c73cf1ee43ea4f59c10988))
* **taiko-client-rs:** bump alethia-reth dependency ([#21646](https://github.com/taikoxyz/taiko-mono/issues/21646)) ([b5e3860](https://github.com/taikoxyz/taiko-mono/commit/b5e3860e5f79389d7c7980b7e66700793bbab35d))
* **taiko-client-rs:** bump alethia-reth dependency and reuse `payload_id_taiko` ([#21183](https://github.com/taikoxyz/taiko-mono/issues/21183)) ([f8ba38d](https://github.com/taikoxyz/taiko-mono/commit/f8ba38d56a0d55e7dc918807c9e77c7ec1f10c98))
* **taiko-client-rs:** bump alethia-reth deps to latest main ([#21462](https://github.com/taikoxyz/taiko-mono/issues/21462)) ([6640f00](https://github.com/taikoxyz/taiko-mono/commit/6640f00e5fad14bd35a31b3cb820c549bded50c8))
* **taiko-client-rs:** bump dependency ver ([#21352](https://github.com/taikoxyz/taiko-mono/issues/21352)) ([087a04c](https://github.com/taikoxyz/taiko-mono/commit/087a04c1c83504dbbb01ee30e5e5b4358e3f8b29))
* **taiko-client-rs:** bump deps to `alloy 1.8` ([#21659](https://github.com/taikoxyz/taiko-mono/issues/21659)) ([9d1b842](https://github.com/taikoxyz/taiko-mono/commit/9d1b842e323811ee0fc7b3881b51bd43fd9b6444))
* **taiko-client-rs:** bump Docker build Rust toolchain ([#21398](https://github.com/taikoxyz/taiko-mono/issues/21398)) ([911679f](https://github.com/taikoxyz/taiko-mono/commit/911679f2d3c90c197549574e64162ffe6689e2ba))
* **taiko-client-rs:** disable Unzen fork on Hoodi ([#21696](https://github.com/taikoxyz/taiko-mono/issues/21696)) ([b5614df](https://github.com/taikoxyz/taiko-mono/commit/b5614dfecb720214d3b7348c5055f57ac3db8c71))
* **taiko-client-rs:** gate signer behind net feature ([#21605](https://github.com/taikoxyz/taiko-mono/issues/21605)) ([0130a6e](https://github.com/taikoxyz/taiko-mono/commit/0130a6eeae45e4f9ef5b76f9f04363abc858e2f2))
* **taiko-client-rs:** improve comments ([#21344](https://github.com/taikoxyz/taiko-mono/issues/21344)) ([748467c](https://github.com/taikoxyz/taiko-mono/commit/748467cfd0384af497715f77eba7056940c61ee9))
* **taiko-client-rs:** keep host features out of no-default build ([#21604](https://github.com/taikoxyz/taiko-mono/issues/21604)) ([3ecc25e](https://github.com/taikoxyz/taiko-mono/commit/3ecc25e612e9fae238abb33a0b81c1897e29f9c1))
* **taiko-client-rs:** make preconf server API methods public to be accessed by crate users ([#21296](https://github.com/taikoxyz/taiko-mono/issues/21296)) ([a099505](https://github.com/taikoxyz/taiko-mono/commit/a09950572696cf0ba50b6728a96ea285e5c0ddfa))
* **taiko-client-rs:** manifest decoding errors instead of None ([#21168](https://github.com/taikoxyz/taiko-mono/issues/21168)) ([18d09fe](https://github.com/taikoxyz/taiko-mono/commit/18d09fe60de0a960a0a0ca65a5acfe02f35ec7cb))
* **taiko-client-rs:** missing driver crate licence ([#21308](https://github.com/taikoxyz/taiko-mono/issues/21308)) ([dba22a9](https://github.com/taikoxyz/taiko-mono/commit/dba22a9dc35bae275ab68496b16ebe43aeea3824))
* **taiko-client-rs:** preserve lookahead error semantics for slot info RPC ([#21286](https://github.com/taikoxyz/taiko-mono/issues/21286)) ([7b50fce](https://github.com/taikoxyz/taiko-mono/commit/7b50fceea159cb5b714a5bf83372514b4ad03be1))
* **taiko-client-rs:** rename difficulty to mixHash after Uzen ([#21570](https://github.com/taikoxyz/taiko-mono/issues/21570)) ([b6e564f](https://github.com/taikoxyz/taiko-mono/commit/b6e564fca160cd6cc514b3193b26f447781c25be))
* **taiko-client-rs:** rust 1.94, dependecies update ([#21633](https://github.com/taikoxyz/taiko-mono/issues/21633)) ([6ea4287](https://github.com/taikoxyz/taiko-mono/commit/6ea4287f37497fc77bb3f9a125e78720bfeb5fe2))
* **taiko-client-rs:** several improvments for preconfirmation-driver ([#21330](https://github.com/taikoxyz/taiko-mono/issues/21330)) ([d6d67ec](https://github.com/taikoxyz/taiko-mono/commit/d6d67ecd2eee992648aaae8c5f296da700327d97))
* **taiko-client-rs:** support Masaya chain id `167011` in Shasta fork config ([#21301](https://github.com/taikoxyz/taiko-mono/issues/21301)) ([938c05d](https://github.com/taikoxyz/taiko-mono/commit/938c05d23309916ab0a8c0840b1d3494c3fd553c))
* **taiko-client-rs:** update `event-scanner` && `alethia-reth` ([#20805](https://github.com/taikoxyz/taiko-mono/issues/20805)) ([811e34d](https://github.com/taikoxyz/taiko-mono/commit/811e34d7fee38302c5e362586e7f9de7bfb398b5))
* **taiko-client-rs:** update `SHASTA_FORK_MAINNET` ([#21547](https://github.com/taikoxyz/taiko-mono/issues/21547)) ([1d1e6da](https://github.com/taikoxyz/taiko-mono/commit/1d1e6da5be399f9f74f19fb0f760d3ffcbb14f73))
* **taiko-client-rs:** update alethia reth pin ([#21708](https://github.com/taikoxyz/taiko-mono/issues/21708)) ([a2a2e66](https://github.com/taikoxyz/taiko-mono/commit/a2a2e66d981d875b21026c99ee793175b6c60c02))
* **taiko-client-rs:** update alethia reth pin ([#21712](https://github.com/taikoxyz/taiko-mono/issues/21712)) ([43d7bd2](https://github.com/taikoxyz/taiko-mono/commit/43d7bd2005b73287145f399c9b797016896ce5db))
* **taiko-client-rs:** update alethia reth pin ([#21733](https://github.com/taikoxyz/taiko-mono/issues/21733)) ([a8863d1](https://github.com/taikoxyz/taiko-mono/commit/a8863d11437b6e4789d9294ee0256ed14d8c26d3))
* **taiko-client-rs:** update alethia reth pin ([#21736](https://github.com/taikoxyz/taiko-mono/issues/21736)) ([9fe9052](https://github.com/taikoxyz/taiko-mono/commit/9fe9052b74a9c99c5f3d7aceba70b128145840d8))
* **taiko-client-rs:** update alethia reth pin ([#21747](https://github.com/taikoxyz/taiko-mono/issues/21747)) ([b153bbc](https://github.com/taikoxyz/taiko-mono/commit/b153bbcf76289e679d3853acc38278adf3edfd52))
* **taiko-client-rs:** update base image from ubuntu 22.04 to 24.04 ([#21415](https://github.com/taikoxyz/taiko-mono/issues/21415)) ([0b7e0f6](https://github.com/taikoxyz/taiko-mono/commit/0b7e0f6e7901be56ff15f1d531aee44bb12b245c))
* **taiko-client-rs:** update Shasta constants ([#21266](https://github.com/taikoxyz/taiko-mono/issues/21266)) ([cab48cc](https://github.com/taikoxyz/taiko-mono/commit/cab48cca0a8dbd0ba10015629b409604541d17db))
* **taiko-client-rs:** updated Cargo.lock security related dependencies ([#21611](https://github.com/taikoxyz/taiko-mono/issues/21611)) ([b488bdd](https://github.com/taikoxyz/taiko-mono/commit/b488bdd740e21a9de796b7581149521399878129))
* **taiko-client-rs:** use `taikoAuth` batch lookups and error handling ([#21241](https://github.com/taikoxyz/taiko-mono/issues/21241)) ([ca00003](https://github.com/taikoxyz/taiko-mono/commit/ca00003f21c6ef6a10142e14558609d934b96433))
* **taiko-client-rs:** use alethia-reth chainspec forks ([#21698](https://github.com/taikoxyz/taiko-mono/issues/21698)) ([678ae4d](https://github.com/taikoxyz/taiko-mono/commit/678ae4d767a41ca3820af906529271576a32b0bc))
* **taiko-client-rs:** validate blob server KZG data ([#21766](https://github.com/taikoxyz/taiko-mono/issues/21766)) ([4177feb](https://github.com/taikoxyz/taiko-mono/commit/4177febfd3d5b1d0617a37f2e20222daa25adb22))
* **taiko-client,taiko-client-rs:** align execution deps and Hoodi Unzen time ([#21654](https://github.com/taikoxyz/taiko-mono/issues/21654)) ([0942707](https://github.com/taikoxyz/taiko-mono/commit/09427074352023bc262f5a907d41f0c8b02cd3ea))
* **taiko-client,taiko-client-rs:** bump execution client dependencies ([#21721](https://github.com/taikoxyz/taiko-mono/issues/21721)) ([89afa8e](https://github.com/taikoxyz/taiko-mono/commit/89afa8e47ed69d095fe44aa3e50db233ae8b13a9))
* **taiko-client,taiko-client-rs:** bump execution client dependencies ([#21778](https://github.com/taikoxyz/taiko-mono/issues/21778)) ([ffce7c8](https://github.com/taikoxyz/taiko-mono/commit/ffce7c8aea3867d3dbd52a7da50d776daa5774e2))
* **taiko-client,taiko-client-rs:** bump execution client deps ([#21603](https://github.com/taikoxyz/taiko-mono/issues/21603)) ([af02afc](https://github.com/taikoxyz/taiko-mono/commit/af02afc645e6a8c352b69d5ebffe9d1c9f3fb052))
* **taiko-client,taiko-client-rs:** bump execution deps ([#21671](https://github.com/taikoxyz/taiko-mono/issues/21671)) ([cdb811a](https://github.com/taikoxyz/taiko-mono/commit/cdb811a130759010378cdd05fb16b06e9597f1c6))
* **taiko-client,taiko-client-rs:** bump Hoodi Unzen execution deps ([#21689](https://github.com/taikoxyz/taiko-mono/issues/21689)) ([fd88b22](https://github.com/taikoxyz/taiko-mono/commit/fd88b22c42eab091397d6269a9dad68464028cec))
* **taiko-client,taiko-client-rs:** bump taiko-geth and alethia-reth to latest ([#21753](https://github.com/taikoxyz/taiko-mono/issues/21753)) ([1d76df6](https://github.com/taikoxyz/taiko-mono/commit/1d76df6294b2784ddaf6b50da8ea189f0d1f3705))
* **taiko-client,taiko-client-rs:** bump taiko-geth and alethia-reth to latest ([#21755](https://github.com/taikoxyz/taiko-mono/issues/21755)) ([fb8b852](https://github.com/taikoxyz/taiko-mono/commit/fb8b852f4c91b397cfb95bfdbf0bcd0b708fb50c))
* **taiko-client,taiko-client-rs:** update Go / Rust contract bindings ([#20961](https://github.com/taikoxyz/taiko-mono/issues/20961)) ([f1118e6](https://github.com/taikoxyz/taiko-mono/commit/f1118e691b52bf22dc03c868f8db9be2368f4cfd))
* **taiko-client,taiko-client-rs:** update Go / Rust contract bindings ([#21171](https://github.com/taikoxyz/taiko-mono/issues/21171)) ([96d2f0a](https://github.com/taikoxyz/taiko-mono/commit/96d2f0afbf4be894aa3c6a4593eae7fa2d809629))
* **taiko-client,taiko-client-rs:** update Go / Rust contract bindings ([#21176](https://github.com/taikoxyz/taiko-mono/issues/21176)) ([fe6a678](https://github.com/taikoxyz/taiko-mono/commit/fe6a67842f9f9da48f6b4665f49b9a471b971417))
* **taiko-client,taiko-client-rs:** update Go / Rust contract bindings ([#21193](https://github.com/taikoxyz/taiko-mono/issues/21193)) ([34c446d](https://github.com/taikoxyz/taiko-mono/commit/34c446de200a0856863615936c8ce1e94097981f))
* **taiko-client:** improve `ResetL1Current` to set Shasta anchor number ([#20761](https://github.com/taikoxyz/taiko-mono/issues/20761)) ([14f9367](https://github.com/taikoxyz/taiko-mono/commit/14f93671c2fbea1cd747ad5779cc1507eeadda53))


### Documentation

* **taiko-client-rs:** codify cross-crate preconfirmation/event-sync guardrails and invariant references ([#21334](https://github.com/taikoxyz/taiko-mono/issues/21334)) ([8ef6d54](https://github.com/taikoxyz/taiko-mono/commit/8ef6d54707fcf1233e590979eaeb5621d1c5d7d5))


### Code Refactoring

* **taiko-client-rs, preconfirmation-p2p:** simplify codebase by consolidating single-file submodules ([#21142](https://github.com/taikoxyz/taiko-mono/issues/21142)) ([41ec2ee](https://github.com/taikoxyz/taiko-mono/commit/41ec2ee64008c9784b5365bba944774f1d740b74))
* **taiko-client-rs:** avoid cloning preconfirmation execution payload ([#21027](https://github.com/taikoxyz/taiko-mono/issues/21027)) ([2b6c078](https://github.com/taikoxyz/taiko-mono/commit/2b6c07814c1a685cf49aaa087c3da47c988933e9))
* **taiko-client-rs:** centralize `whitelist-preconfirmation-driver` error handling and harden validation paths ([#21390](https://github.com/taikoxyz/taiko-mono/issues/21390)) ([c2ca581](https://github.com/taikoxyz/taiko-mono/commit/c2ca581078c9a9e4afd98ab1da34cc50b8385bb6))
* **taiko-client-rs:** consolidate shared assembly and collapse single-impl abstractions ([#21776](https://github.com/taikoxyz/taiko-mono/issues/21776)) ([6d9b444](https://github.com/taikoxyz/taiko-mono/commit/6d9b444148a354768cb37854d2d00401f05b3fc4))
* **taiko-client-rs:** consolidate whitelist preconfirmation driver helpers ([#21771](https://github.com/taikoxyz/taiko-mono/issues/21771)) ([8e2207b](https://github.com/taikoxyz/taiko-mono/commit/8e2207b092ba3ff6a0badca2b96e6aeca96de9b1))
* **taiko-client-rs:** consume preconf receiver exactly once ([#21498](https://github.com/taikoxyz/taiko-mono/issues/21498)) ([505d55f](https://github.com/taikoxyz/taiko-mono/commit/505d55f5b948c2bfcb25123226830c06e71a8768))
* **taiko-client-rs:** introduce `DriverApiError` for driver preconf RPC errors ([#21139](https://github.com/taikoxyz/taiko-mono/issues/21139)) ([da8a475](https://github.com/taikoxyz/taiko-mono/commit/da8a4753cb462927e1273ab2032e7b3fc4133532))
* **taiko-client-rs:** refactor whitelist preconfirmation driver P2P + derive chain ID from L2 ([#21539](https://github.com/taikoxyz/taiko-mono/issues/21539)) ([a137b98](https://github.com/taikoxyz/taiko-mono/commit/a137b984fad900733cd25a0eddb04a8a6502ece4))
* **taiko-client-rs:** remove `proposal-id`/`canonical-tip` wiring and use confirmed head-state sync ([#21332](https://github.com/taikoxyz/taiko-mono/issues/21332)) ([519e9c6](https://github.com/taikoxyz/taiko-mono/commit/519e9c665c961bbae6cc2881bbb9f4b2bac32d3c))
* **taiko-client-rs:** remove some duplicated logs ([#21137](https://github.com/taikoxyz/taiko-mono/issues/21137)) ([19e2438](https://github.com/taikoxyz/taiko-mono/commit/19e24383819304f1f80aafa0c7b73c5b1dd31cce))
* **taiko-client-rs:** remove whitelist preconfirmation reqresp lookup path ([#21537](https://github.com/taikoxyz/taiko-mono/issues/21537)) ([6e28796](https://github.com/taikoxyz/taiko-mono/commit/6e28796897987712ff7732ac4f268bfb493615e0))
* **taiko-client-rs:** share fallback whitelist timeline across resolver clones, drop dead code ([#21774](https://github.com/taikoxyz/taiko-mono/issues/21774)) ([8219429](https://github.com/taikoxyz/taiko-mono/commit/8219429f2572ef65e8463e679a9897a28a227a06))
* **taiko-client-rs:** simplification sweep across all crates ([#21772](https://github.com/taikoxyz/taiko-mono/issues/21772)) ([8faa8e9](https://github.com/taikoxyz/taiko-mono/commit/8faa8e97a32e30c388287ff90d41104056d59ca4))
* **taiko-client-rs:** simplify and deduplicate across `rpc`, `driver`, and `CLI` ([#21571](https://github.com/taikoxyz/taiko-mono/issues/21571)) ([b521c27](https://github.com/taikoxyz/taiko-mono/commit/b521c2745398481b7d9fd751c9eb290be89d4084))
* **taiko-client-rs:** simplify some implementations in `whitelist-preconfirmation-driver` crate ([#21421](https://github.com/taikoxyz/taiko-mono/issues/21421)) ([3977c46](https://github.com/taikoxyz/taiko-mono/commit/3977c466fde470882a8e4f27429392e0cf40c1dd))
* **taiko-client-rs:** simplify whitelist preconf driver state and API types ([#21769](https://github.com/taikoxyz/taiko-mono/issues/21769)) ([8435b4c](https://github.com/taikoxyz/taiko-mono/commit/8435b4cb0797aeca6cecd436c7f04fe1fd39c537))
* **taiko-client-rs:** simplify whitelist preconfirmation driver ([#21768](https://github.com/taikoxyz/taiko-mono/issues/21768)) ([b6d1967](https://github.com/taikoxyz/taiko-mono/commit/b6d196703c32b07b9ab35d98a189cf7ff66aa419))
* **taiko-client-rs:** split oversized modules and simplify network / server flows ([#21389](https://github.com/taikoxyz/taiko-mono/issues/21389)) ([084f090](https://github.com/taikoxyz/taiko-mono/commit/084f090ee5564d41ff2ef704dcd95cd1b3d604b3))
* **taiko-client-rs:** split whitelist network runtime and bootstrap setup ([#21405](https://github.com/taikoxyz/taiko-mono/issues/21405)) ([43497de](https://github.com/taikoxyz/taiko-mono/commit/43497de04e81ead430ab47c61c742ced5520005f))
* **taiko-client,taiko-client-rs:** swap preconf whitelist check from coinbase to node P2P signer ([#21584](https://github.com/taikoxyz/taiko-mono/issues/21584)) ([5d62757](https://github.com/taikoxyz/taiko-mono/commit/5d6275785966683f783069f76d3982c05ccf7c7a))


### Tests

* **taiko-client-rs:** add event‑driven preconfirmation P2P integration test and pre‑dial hooks ([#21144](https://github.com/taikoxyz/taiko-mono/issues/21144)) ([85ee841](https://github.com/taikoxyz/taiko-mono/commit/85ee841f0b709c70512249603e32889e9b578c34))
* **taiko-client-rs:** comprehensive E2E tests for preconfirmation and driver flows ([#21151](https://github.com/taikoxyz/taiko-mono/issues/21151)) ([22487b7](https://github.com/taikoxyz/taiko-mono/commit/22487b7aed7ca456b28350820a3f18f9782d6b3d))
* **taiko-client-rs:** introduce new auth rpc & fix test ([#21594](https://github.com/taikoxyz/taiko-mono/issues/21594)) ([47e9878](https://github.com/taikoxyz/taiko-mono/commit/47e9878d36c92017c79ddfd75b6dcc93e7989d61))
* **taiko-client-rs:** use `test-context` to simplify tests ([#20866](https://github.com/taikoxyz/taiko-mono/issues/20866)) ([5176f13](https://github.com/taikoxyz/taiko-mono/commit/5176f13aa11118f0825ae93d48fecce110598819))
* **taiko-client-rs:** use WS endpoints for `ShastaEnv` test providers ([#21254](https://github.com/taikoxyz/taiko-mono/issues/21254)) ([d42b051](https://github.com/taikoxyz/taiko-mono/commit/d42b0518c20e3f785e840d40ce796bea4b983023))


### Workflow

* **repo:** fix taiko-client-rs test workflow  ([#21393](https://github.com/taikoxyz/taiko-mono/issues/21393)) ([6b940a3](https://github.com/taikoxyz/taiko-mono/commit/6b940a3b65c4e13ab520e5fe2205a3ca56589b7e))
* **taiko-client, taiko-client-rs:** improve ci timeout ([#21159](https://github.com/taikoxyz/taiko-mono/issues/21159)) ([3b7d6e8](https://github.com/taikoxyz/taiko-mono/commit/3b7d6e83c46bd4be2179d0319f024acf74dfb6f5))
