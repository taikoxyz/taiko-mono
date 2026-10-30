# Source alignment review — 2026-10-29

Authority: SPEC.md and ACCEPTANCE.md at `39ebefbf33a2702b750e0fb0db7d2a40ff8e8480`. The old source is `sources/spec.md` at formal head `c9708e76159bb8da701f8bc20c07ff2e46537642`. Production specifications are unchanged.

Inventory schema 4 retains `source` and adds `acceptance_source`. Each fixed repository path has its own SHA-256, full Git commit and revision date. Runtime checks compare bytes with this reviewed inventory; neither an editor manifest nor local Git history is required. Metadata identifies provenance and is not a signature or a proof of publication. SPEC clauses retain the `EN-` prefix; acceptance clauses use `ACCEPTANCE-`. Every source row carries `path` and `source_commit`.

The parser excludes Markdown headings and standalone details/summary wrappers, preserves fenced code literally, and derives line locations from the current bytes. Clause identities still hash whitespace-normalized raw clause text. Presentation normalization was used only to produce this reviewed migration map, never by the checker: HTML b/code versus Markdown emphasis/code, Markdown escapes, table-cell padding and the renamed checklist link. There is no runtime fuzzy matching.

All 118 previously linked source identities were reviewed: 107 presentation-only correspondences and the 11 explicit changes below. Remapping an edge preserves its theorem role and exact contract; it does not prove all new sentences in a changed paragraph. The model integration must add the new nonce, total-principal and forfeiture obligations. The three existing upgrade-design pending clauses retain their status. New acceptance clauses remain deferred until linked general evidence is registered.

## Reviewed semantic changes

| Old clause / lines          | Current clause / lines      | Changed obligation                                                                                                                                                                                          |
| --------------------------- | --------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `EN-e7c90bac979e2a7a` / 56  | `EN-b88b6b1e1d0a93b8` / 59  | Clarifies that Comet evidence triggers double-sign slashing; distinct DAO forfeiture is added in 4.4.                                                                                                       |
| `EN-3d21329a724c2cf4` / 142 | `EN-fd0557c2630191c6` / 152 | Withdrawal now pays effective plus pending principal, checks owner for positive total, clears pending readiness, preserves the lifetime forfeiture flag. Existing confirmation/snapshot obligations remain. |
| `EN-ceba151e3ff10337` / 151 | `EN-1922bc4f51f2158c` / 161 | Double-sign eligibility and bounty/sink split use all remaining principal; successful slash clears effective/pending/readiness.                                                                             |
| `EN-9e1109adf3d5e673` / 156 | `EN-25553fea06dda239` / 167 | Initialization also gates forfeiture, while top-up and activation explicitly work before initialization; fixed Inbox identity checks remain.                                                                |
| `EN-21e6553a98d0e543` / 457 | `EN-d04a236579cc9990` / 487 | Rollback must preserve and increment current recoveryNonce instead of relying on DAO cancellation; restored settlement and confirmation rechecks remain.                                                    |
| `EN-de09a894490467e7` / 458 | `EN-1045f23916b48c0e` / 488 | Recovery call adds expectedRecoveryNonce and validUntil; same sorted list identities and atomic transition structure.                                                                                       |
| `EN-08865fccc26e3b38` / 460 | `EN-a291bb263ea08b0c` / 490 | Recovery exclusion deducts no principal; independent responsibility forfeiture and double-sign slashing remain available.                                                                                   |
| `EN-3919aab0d7310f2f` / 482 | `EN-8e5f0457d17b70bc` / 510 | Recovery checks initialization, nonce and expiry in addition to owner/generation/checkpoint; nonce starts at zero.                                                                                          |
| `EN-6d967458e628d3d4` / 483 | `EN-3f7463f0f1df5094` / 511 | Recovery/invalidation/rollback increment a non-wrapping current nonce; rollback cannot revive authorization. Lifetime forfeiture flag is separate.                                                          |
| `EN-ddae51c65a3dbb2b` / 484 | `EN-e3a825ec5265a857` / 512 | Recovery atomicity now explicitly coexists with independent forfeiture; reentrancy boundary includes invalidation and registry mutations.                                                                   |
| `EN-a9466cc7d5e5bdc2` / 532 | `EN-a18ead0048bf2b66` / 557 | Initialization adds recoveryNonce=0; genesis, origin, committee/config and protocol-fee initialization remain.                                                                                              |

The former stale-DAO-authorization finding is resolved by the current design at SPEC lines 487 and 510–512: rollback increments the current nonce, and recovery requires its exact match. The historical revival theorem has been replaced by the kernel-checked `stale_authorization_never_revives` regression and the general `consumed_authorization_never_revives` theorem. Recovery committee capture and poison resubmission are independent of nonce protection.

## Complete reviewed linked correspondence

Lines below refer to old `sources/spec.md` and current `SPEC.md`; ranges include the complete clause. Presentation-only means equality under the reviewed normalization described above.

| Old ID                | Old lines | Current ID            | Current lines | Review            |
| --------------------- | --------- | --------------------- | ------------- | ----------------- |
| `EN-99e4d64cfffe1669` | 12–12     | `EN-806e818366c6b783` | 12–12         | presentation-only |
| `EN-5ddcca2eb695cc31` | 13–13     | `EN-c36e4d0d76a728b6` | 13–13         | presentation-only |
| `EN-8f5962cb95c26837` | 15–15     | `EN-9e8e4c90054257e9` | 15–15         | presentation-only |
| `EN-9601ef7c45b9289c` | 16–16     | `EN-114c11b55a88713c` | 16–16         | presentation-only |
| `EN-47818f0976e74864` | 47–47     | `EN-ef5be856cdbb35d7` | 49–49         | presentation-only |
| `EN-e7c90bac979e2a7a` | 56–56     | `EN-b88b6b1e1d0a93b8` | 59–59         | semantic          |
| `EN-5fd310cd31b92652` | 73–73     | `EN-f5b810144f31f649` | 77–77         | presentation-only |
| `EN-a15b97cb32bd4160` | 74–74     | `EN-4d1c581f8980cdc9` | 78–78         | presentation-only |
| `EN-4c12aab2fcffa505` | 75–75     | `EN-2fc53b9651494399` | 79–79         | presentation-only |
| `EN-ef4e39dc235aa978` | 76–76     | `EN-c8ae3732c0a10efe` | 80–80         | presentation-only |
| `EN-8d4cd902040c1124` | 86–86     | `EN-db20f3f57ed32fc2` | 90–90         | presentation-only |
| `EN-c156c1876a96a126` | 97–97     | `EN-c156c1876a96a126` | 102–102       | presentation-only |
| `EN-3f15fb492bdc1523` | 99–99     | `EN-a80aee38ffc500c7` | 104–104       | presentation-only |
| `EN-d362a17243658f1b` | 100–100   | `EN-d362a17243658f1b` | 105–105       | presentation-only |
| `EN-924cf85e5baef89d` | 101–101   | `EN-92bc135177c41240` | 106–106       | presentation-only |
| `EN-d727508f040550ca` | 102–102   | `EN-50be5a3336c584b6` | 107–107       | presentation-only |
| `EN-712dec44b0e5c2b0` | 103–103   | `EN-8d1801078c3862d8` | 108–108       | presentation-only |
| `EN-97a85deb922765e1` | 104–104   | `EN-97a85deb922765e1` | 109–109       | presentation-only |
| `EN-f6b4a647a9d06f40` | 105–105   | `EN-ced8c7aa78799681` | 110–110       | presentation-only |
| `EN-f33ce83257cb2c96` | 106–106   | `EN-f33ce83257cb2c96` | 111–111       | presentation-only |
| `EN-abd6fbb64abe78cd` | 113–113   | `EN-22e9d742c1448a1f` | 118–118       | presentation-only |
| `EN-b0e1cb970c26a870` | 118–118   | `EN-b0e1cb970c26a870` | 123–123       | presentation-only |
| `EN-3ce5781807da58ba` | 128–128   | `EN-3ce5781807da58ba` | 134–134       | presentation-only |
| `EN-3a19d2ad156f3196` | 129–129   | `EN-aee6e06c2b0041ee` | 135–135       | presentation-only |
| `EN-1a152ac50dea7569` | 134–134   | `EN-6609961308fc760e` | 140–140       | presentation-only |
| `EN-a3deb213b64305aa` | 135–135   | `EN-a3deb213b64305aa` | 141–141       | presentation-only |
| `EN-471ef75c3d545157` | 139–139   | `EN-471ef75c3d545157` | 146–146       | presentation-only |
| `EN-db9efa8ce84dc6cf` | 140–140   | `EN-9d61587bb0f5f183` | 150–150       | presentation-only |
| `EN-aee1de007584a82e` | 141–141   | `EN-4651c537a506e6fd` | 151–151       | presentation-only |
| `EN-3d21329a724c2cf4` | 142–142   | `EN-fd0557c2630191c6` | 152–152       | semantic          |
| `EN-24a9c5d44aea2f2b` | 144–144   | `EN-405f21d19d6bc681` | 154–154       | presentation-only |
| `EN-b82d63337df901b4` | 149–149   | `EN-b82d63337df901b4` | 159–159       | presentation-only |
| `EN-19fba09b8e54fe5c` | 150–150   | `EN-ffb6d8f886ed245e` | 160–160       | presentation-only |
| `EN-ceba151e3ff10337` | 151–151   | `EN-1922bc4f51f2158c` | 161–161       | semantic          |
| `EN-eefdfe30db86a79e` | 152–152   | `EN-c3f51f9d72eb6ec5` | 162–162       | presentation-only |
| `EN-e11112a7ad1b77fd` | 155–155   | `EN-e11112a7ad1b77fd` | 166–166       | presentation-only |
| `EN-9e1109adf3d5e673` | 156–156   | `EN-25553fea06dda239` | 167–167       | semantic          |
| `EN-77876d927fb8f216` | 160–160   | `EN-5eddee49ec804220` | 171–171       | presentation-only |
| `EN-9ac7403cd8147312` | 167–167   | `EN-9ac7403cd8147312` | 178–178       | presentation-only |
| `EN-e836367d8d5f0ecb` | 168–168   | `EN-d7e07b7ea27ed4a3` | 179–179       | presentation-only |
| `EN-50b55b5d5db3ae2b` | 169–169   | `EN-cb365b99df0cd062` | 180–180       | presentation-only |
| `EN-ce7f6fae93ef190f` | 170–170   | `EN-ce7f6fae93ef190f` | 181–181       | presentation-only |
| `EN-91fd42e5562925bc` | 175–175   | `EN-11492348071c320c` | 186–186       | presentation-only |
| `EN-655a6b89e6664fe8` | 178–178   | `EN-8d48930c4f886712` | 190–190       | presentation-only |
| `EN-c704a0b119e2703e` | 183–183   | `EN-179bc07a1f6d0129` | 195–195       | presentation-only |
| `EN-114a4ccd5639938f` | 186–186   | `EN-29468a34f68ca4c6` | 199–199       | presentation-only |
| `EN-87e5d209cd94e1fa` | 206–206   | `EN-be2a860da03d44e4` | 228–228       | presentation-only |
| `EN-976a8c89163f509a` | 233–325   | `EN-976a8c89163f509a` | 254–346       | presentation-only |
| `EN-7d0d8b4700d5f760` | 330–330   | `EN-f6ac877eee3202a4` | 352–352       | presentation-only |
| `EN-46f0f07d9e0afae1` | 331–331   | `EN-46ab93807fe14cda` | 353–353       | presentation-only |
| `EN-b22f4a02a0ce7e37` | 332–332   | `EN-b22f4a02a0ce7e37` | 354–354       | presentation-only |
| `EN-62d2f6d3dcce3eaf` | 338–338   | `EN-e62f9ae7e42baf9a` | 360–360       | presentation-only |
| `EN-8418b9acc34860c3` | 339–339   | `EN-99e8a56e96bcba34` | 361–361       | presentation-only |
| `EN-460ed962a964fc18` | 340–340   | `EN-af33164a1858c781` | 362–362       | presentation-only |
| `EN-97fcc42389c0df07` | 342–342   | `EN-043c32870af8d13f` | 364–364       | presentation-only |
| `EN-5d5828fcdce5ab2a` | 344–344   | `EN-5d5828fcdce5ab2a` | 366–366       | presentation-only |
| `EN-71e3a569d6a31b72` | 345–345   | `EN-2474bdce909c86f9` | 367–367       | presentation-only |
| `EN-adcd3a47969dbd68` | 350–350   | `EN-adcd3a47969dbd68` | 372–372       | presentation-only |
| `EN-1a5225545d3246a1` | 361–361   | `EN-3ec993c77d0c5804` | 384–384       | presentation-only |
| `EN-8e9393526aafbf25` | 362–362   | `EN-ca11903a139fbf61` | 385–385       | presentation-only |
| `EN-2fd74d72c4859e4f` | 363–363   | `EN-0dc8e470d14aea02` | 386–386       | presentation-only |
| `EN-f7fbc5b1cd6302db` | 364–364   | `EN-cfa5bb84077a9740` | 387–387       | presentation-only |
| `EN-0606608e96fc5202` | 372–372   | `EN-b8d78ca3f1f77e84` | 396–396       | presentation-only |
| `EN-db9db165a8918b3e` | 377–377   | `EN-1f6d4e95120e0de7` | 401–401       | presentation-only |
| `EN-72cd13b8dc033831` | 380–380   | `EN-72cd13b8dc033831` | 405–405       | presentation-only |
| `EN-a1a468781512ee9a` | 390–390   | `EN-eb5074ad77d4a985` | 415–415       | presentation-only |
| `EN-08c17ce90500398a` | 395–395   | `EN-f3138a4a28d8137f` | 420–420       | presentation-only |
| `EN-2e7fa6e510a4d3cb` | 400–400   | `EN-2e7fa6e510a4d3cb` | 426–426       | presentation-only |
| `EN-a5dd62e767b21636` | 401–401   | `EN-136c3f345da4a399` | 427–427       | presentation-only |
| `EN-baef69e262e5e41e` | 402–402   | `EN-6f5b8a710969bc1c` | 428–428       | presentation-only |
| `EN-a0d7e057533c65e9` | 412–412   | `EN-a0d7e057533c65e9` | 439–439       | presentation-only |
| `EN-7412e58b89f2e1dd` | 413–413   | `EN-7412e58b89f2e1dd` | 440–440       | presentation-only |
| `EN-ece14be2916f0686` | 414–414   | `EN-ece14be2916f0686` | 441–441       | presentation-only |
| `EN-ceeb4f345d3846f7` | 415–415   | `EN-e47ed8b1032eaf71` | 442–442       | presentation-only |
| `EN-35df6a8d23742f51` | 420–420   | `EN-993cfbfb83f01331` | 447–447       | presentation-only |
| `EN-7fdd2e21c46727ee` | 423–423   | `EN-7fdd2e21c46727ee` | 451–451       | presentation-only |
| `EN-3a4063c2936a95e5` | 428–428   | `EN-3a4063c2936a95e5` | 456–456       | presentation-only |
| `EN-c59d7f222dfc1967` | 432–432   | `EN-b69a24b78429ebe4` | 461–461       | presentation-only |
| `EN-45765af3f5c8bd25` | 436–436   | `EN-1ee6db9f8ebb8410` | 465–465       | presentation-only |
| `EN-21e6553a98d0e543` | 457–457   | `EN-d04a236579cc9990` | 487–487       | semantic          |
| `EN-de09a894490467e7` | 458–458   | `EN-1045f23916b48c0e` | 488–488       | semantic          |
| `EN-08865fccc26e3b38` | 460–460   | `EN-a291bb263ea08b0c` | 490–490       | semantic          |
| `EN-e83bfb4c2586fe1b` | 461–461   | `EN-e83bfb4c2586fe1b` | 491–491       | presentation-only |
| `EN-7319b105593c8c53` | 462–462   | `EN-7319b105593c8c53` | 492–492       | presentation-only |
| `EN-6eed3016601c5cd3` | 463–463   | `EN-6eed3016601c5cd3` | 493–493       | presentation-only |
| `EN-d7f8342dc8bb8e88` | 464–464   | `EN-d7f8342dc8bb8e88` | 494–494       | presentation-only |
| `EN-3504917df70d4bf8` | 468–468   | `EN-3504917df70d4bf8` | 498–498       | presentation-only |
| `EN-27092ca41cb5a1ca` | 469–469   | `EN-975e406996f0fce2` | 499–499       | presentation-only |
| `EN-c86e58b9428a7032` | 470–470   | `EN-735768aec6f64583` | 500–500       | presentation-only |
| `EN-2cb0bccc269c967e` | 475–475   | `EN-6478ed58606b3c3b` | 505–505       | presentation-only |
| `EN-3919aab0d7310f2f` | 482–482   | `EN-8e5f0457d17b70bc` | 510–510       | semantic          |
| `EN-6d967458e628d3d4` | 483–483   | `EN-3f7463f0f1df5094` | 511–511       | semantic          |
| `EN-ddae51c65a3dbb2b` | 484–484   | `EN-e3a825ec5265a857` | 512–512       | semantic          |
| `EN-9ef4669a01e1c4e4` | 492–492   | `EN-8ae0f0fcf4c9861c` | 518–518       | presentation-only |
| `EN-00f7307cf34d8850` | 493–493   | `EN-49047e11958a696e` | 519–519       | presentation-only |
| `EN-ec6474f088a5a4d0` | 494–494   | `EN-d8189cd72ebd5832` | 520–520       | presentation-only |
| `EN-1c2849e6521d3a64` | 501–501   | `EN-5e38116b9d70c82a` | 526–526       | presentation-only |
| `EN-0ce8bcf137815f03` | 507–507   | `EN-2b238db781615e6e` | 532–532       | presentation-only |
| `EN-17a4b0ec67332806` | 529–529   | `EN-e69fc49dd2e68ad1` | 554–554       | presentation-only |
| `EN-a9466cc7d5e5bdc2` | 532–532   | `EN-a18ead0048bf2b66` | 557–557       | semantic          |
| `EN-851fa1dfa3186229` | 538–538   | `EN-3a067849123ef674` | 563–563       | presentation-only |
| `EN-3e9e8a7b15faa5d0` | 541–541   | `EN-3b11358e6372389b` | 567–567       | presentation-only |
| `EN-fac3b57a8c83d321` | 553–553   | `EN-fac3b57a8c83d321` | 579–579       | presentation-only |
| `EN-d753309e13d64470` | 561–561   | `EN-d753309e13d64470` | 586–586       | presentation-only |
| `EN-d2ad20dd8df6fea0` | 567–567   | `EN-d2ad20dd8df6fea0` | 592–592       | presentation-only |
| `EN-be2f66a1abdf1feb` | 568–568   | `EN-907dd611aa1954c4` | 593–593       | presentation-only |
| `EN-bc5dadfc224bbed1` | 569–569   | `EN-66e4688eba764b2e` | 594–594       | presentation-only |
| `EN-a758a4feadbff80b` | 570–570   | `EN-ac39c7b3da25f0b9` | 595–595       | presentation-only |
| `EN-9bb909b9f55f5f2c` | 571–571   | `EN-d3eaecaba96068b7` | 596–596       | presentation-only |
| `EN-6ba0a5a824d54ac5` | 574–574   | `EN-056492c07d9386c9` | 599–599       | presentation-only |
| `EN-c994872ae6ae1b79` | 601–601   | `EN-4856837d14522ac8` | 629–629       | presentation-only |
| `EN-2b9c5a66906403da` | 605–605   | `EN-1a99725ed7de8a3f` | 633–633       | presentation-only |
| `EN-40d009e622ee97d2` | 639–665   | `EN-40d009e622ee97d2` | 667–693       | presentation-only |
| `EN-869d67b6135d6bd0` | 667–681   | `EN-869d67b6135d6bd0` | 695–709       | presentation-only |
| `EN-5019e1af878ab082` | 739–739   | `EN-5019e1af878ab082` | 774–774       | presentation-only |
| `EN-ea1733d82f160469` | 740–740   | `EN-ea1733d82f160469` | 775–775       | presentation-only |
| `EN-302af44aa6657a87` | 753–753   | `EN-a491543db0b4b272` | 789–789       | presentation-only |
| `EN-3e51f5b4400b332c` | 765–765   | `EN-d1287f8e4a8fc17b` | 801–801       | presentation-only |

New property edges are deliberately narrow: rate-preservation traces link only the fixed-rate clause; lifetime-flag traces link only once-per-entry/replay clauses; the common-control bound links only the initial-committee clause, not the independent capital-target formula. The final inventory is 62 partial / 246 deferred / 3 design-pending.

## Re-pin to `b7ca989c8e343073daa628771102bdee7fe7101b` — 2026-10-30

SPEC.md moved from `90db8d05419db010512bcd6a8ae0ab01b97fe249` (bytes unchanged at
`d4d18d398936f3fb3fce43f34f0a3b3ebc917d00`) to `b7ca989c8e343073daa628771102bdee7fe7101b`, which
records two limitations; ACCEPTANCE.md did not change. In the marker-free text one clause changed
and two were added after line 625, so every `spec L…` citation above line 625 moves down by two
lines (vectors, statements and README updated; historical reports keep their original lines).

| Old clause / lines         | Current clause / lines      | Review                                                                                                                                                                                                                                |
| -------------------------- | --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `EN-114c11b55a88713c` / 16 | `EN-519f69d065c96fa9` / 16  | Semantic, one sentence: governance recovery step 3 can blank an unprovable forced-inclusion transaction but does not stop it being enqueued again (item 20), instead of "handled by step 3". The four regression links are unchanged. |
| (new)                      | `EN-95f0590cf84239d4` / 626 | Section 12 item 19: a slashed member keeps its voting power until a committee that excludes it takes effect. Linked to `current_voting_power_survives_full_slash` (regression).                                                       |
| (new)                      | `EN-0b7dc528f6439e82` / 627 | Section 12 item 20: blanking does not stop resubmission. Linked to `cleared_poison_resubmitted` (regression).                                                                                                                         |

Both new clauses stay deferred: their links are regressions, which demonstrate the limitation
and back no proof claim.
