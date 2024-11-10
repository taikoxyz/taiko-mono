---
sponsor: "Taiko"
slug: "2024-03-taiko"
date: "2024-04-26"
title: "Taiko"
findings: "https://github.com/code-423n4/2024-03-taiko-findings/issues"
contest: 343
---

# Overview

## About C4

Code4rena (C4) is an open organization consisting of security researchers, auditors, developers, and individuals with domain expertise in smart contracts.

A C4 audit is an event in which community participants, referred to as Wardens, review, audit, or analyze smart contract logic in exchange for a bounty provided by sponsoring projects.

During the audit outlined in this document, C4 conducted an analysis of the Taiko smart contract system written in Solidity. The audit took place between March 6—March 27 2024.

## Wardens

74 Wardens contributed reports to Taiko:

1. [monrel](https://code4rena.com/@monrel)
2. [Shield](https://code4rena.com/@Shield) ([Viraz](https://code4rena.com/@Viraz), [0xA5DF](https://code4rena.com/@0xA5DF), [Dravee](https://code4rena.com/@Dravee), and [Udsen](https://code4rena.com/@Udsen))
3. [t0x1c](https://code4rena.com/@t0x1c)
4. [zzebra83](https://code4rena.com/@zzebra83)
5. [MrPotatoMagic](https://code4rena.com/@MrPotatoMagic)
6. [ladboy233](https://code4rena.com/@ladboy233)
7. [joaovwfreire](https://code4rena.com/@joaovwfreire)
8. [alexfilippov314](https://code4rena.com/@alexfilippov314)
9. [Tendency](https://code4rena.com/@Tendency)
10. [Aymen0909](https://code4rena.com/@Aymen0909)
11. [pa6kuda](https://code4rena.com/@pa6kuda)
12. [t4sk](https://code4rena.com/@t4sk)
13. [mojito_auditor](https://code4rena.com/@mojito_auditor)
14. [lightoasis](https://code4rena.com/@lightoasis)
15. [0xleadwizard](https://code4rena.com/@0xleadwizard)
16. [wangxx2026](https://code4rena.com/@wangxx2026)
17. [josephdara](https://code4rena.com/@josephdara)
18. [blockdev](https://code4rena.com/@blockdev)
19. [Sathish9098](https://code4rena.com/@Sathish9098)
20. [Mahi_Vasisth](https://code4rena.com/@Mahi_Vasisth)
21. [imare](https://code4rena.com/@imare)
22. [Limbooo](https://code4rena.com/@Limbooo)
23. [kaveyjoe](https://code4rena.com/@kaveyjoe)
24. [Myd](https://code4rena.com/@Myd)
25. [yongskiws](https://code4rena.com/@yongskiws)
26. [fouzantanveer](https://code4rena.com/@fouzantanveer)
27. [0xepley](https://code4rena.com/@0xepley)
28. [hassanshakeel13](https://code4rena.com/@hassanshakeel13)
29. [popeye](https://code4rena.com/@popeye)
30. [aariiif](https://code4rena.com/@aariiif)
31. [roguereggiant](https://code4rena.com/@roguereggiant)
32. [Fassi_Security](https://code4rena.com/@Fassi_Security) ([bronze_pickaxe](https://code4rena.com/@bronze_pickaxe) and [mxuse](https://code4rena.com/@mxuse))
33. [albahaca](https://code4rena.com/@albahaca)
34. [DadeKuma](https://code4rena.com/@DadeKuma)
35. [hunter_w3b](https://code4rena.com/@hunter_w3b)
36. [zabihullahazadzoi](https://code4rena.com/@zabihullahazadzoi)
37. [0x11singh99](https://code4rena.com/@0x11singh99)
38. [slvDev](https://code4rena.com/@slvDev)
39. [pfapostol](https://code4rena.com/@pfapostol)
40. [hihen](https://code4rena.com/@hihen)
41. [grearlake](https://code4rena.com/@grearlake)
42. [dharma09](https://code4rena.com/@dharma09)
43. [0xAnah](https://code4rena.com/@0xAnah)
44. [IllIllI](https://code4rena.com/@IllIllI)
45. [iamandreiski](https://code4rena.com/@iamandreiski)
46. [lanrebayode77](https://code4rena.com/@lanrebayode77)
47. [cheatc0d3](https://code4rena.com/@cheatc0d3)
48. [clara](https://code4rena.com/@clara)
49. [JCK](https://code4rena.com/@JCK)
50. [foxb868](https://code4rena.com/@foxb868)
51. [pavankv](https://code4rena.com/@pavankv)
52. [rjs](https://code4rena.com/@rjs)
53. [sxima](https://code4rena.com/@sxima)
54. [Pechenite](https://code4rena.com/@Pechenite) ([Bozho](https://code4rena.com/@Bozho) and [radev_sw](https://code4rena.com/@radev_sw))
55. [oualidpro](https://code4rena.com/@oualidpro)
56. [LinKenji](https://code4rena.com/@LinKenji)
57. [0xbrett8571](https://code4rena.com/@0xbrett8571)
58. [emerald7017](https://code4rena.com/@emerald7017)
59. [Masamune](https://code4rena.com/@Masamune)
60. [Kalyan-Singh](https://code4rena.com/@Kalyan-Singh)
61. [n1punp](https://code4rena.com/@n1punp)
62. [Auditor2947](https://code4rena.com/@Auditor2947)
63. [SAQ](https://code4rena.com/@SAQ)
64. [SY_S](https://code4rena.com/@SY_S)
65. [SM3_SS](https://code4rena.com/@SM3_SS)
66. [unique](https://code4rena.com/@unique)
67. [0xhacksmithh](https://code4rena.com/@0xhacksmithh)
68. [K42](https://code4rena.com/@K42)
69. [caglankaan](https://code4rena.com/@caglankaan)

This audit was judged by [0xean](https://code4rena.com/@0xean).

Final report assembled by PaperParachute.

# Summary

The C4 analysis yielded an aggregated total of 19 unique vulnerabilities. Of these vulnerabilities, 5 received a risk rating in the category of HIGH severity and 14 received a risk rating in the category of MEDIUM severity.

Additionally, C4 analysis included 33 reports detailing issues with a risk rating of LOW severity or non-critical. There were also 28 reports recommending gas optimizations.

All of the issues presented here are linked back to their original finding.

# Scope

The code under review can be found within the [C4 Taiko repository](https://github.com/code-423n4/2024-03-taiko), and is composed of 80 smart contracts written in the Solidity programming language and includes 7442 lines of Solidity code.

# Severity Criteria

C4 assesses the severity of disclosed vulnerabilities based on three primary risk categories: high, medium, and low/non-critical.

High-level considerations for vulnerabilities span the following key areas when conducting assessments:

- Malicious Input Handling
- Escalation of privileges
- Arithmetic
- Gas use

For more information regarding the severity criteria referenced throughout the submission review process, please refer to the documentation provided on [the C4 website](https://code4rena.com), specifically our section on [Severity Categorization](https://docs.code4rena.com/awarding/judging-criteria/severity-categorization).

# High Risk Findings (5)

## [[H-01] Gas issuance is inflated and will halt the chain or lead to incorrect base fee](https://github.com/code-423n4/2024-03-taiko-findings/issues/276)

_Submitted by [monrel](https://github.com/code-423n4/2024-03-taiko-findings/issues/276)_

<https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L140-L143>

<https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L262-L293>

<https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L145-L152>

<https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L140-L143>

The base fee calculation in the `anchor()` function is incorrect. Issuance is over inflated and will either lead to the chain halting or a severely deflated base fee.

### Proof of Concept

We calculate the 1559 base fee and compare it to `block.basefee` <br><https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L140-L143>

```solidity
        (basefee, gasExcess) = _calc1559BaseFee(config, _l1BlockId, _parentGasUsed);
        if (!skipFeeCheck() && block.basefee != basefee) {
            revert L2_BASEFEE_MISMATCH();

```

But the calculation is incorrect:

<https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L262-L293>

```solidity
        if (gasExcess > 0) {
            // We always add the gas used by parent block to the gas excess
            // value as this has already happened
            uint256 excess = uint256(gasExcess) + _parentGasUsed;

            // Calculate how much more gas to issue to offset gas excess.
            // after each L1 block time, config.gasTarget more gas is issued,
            // the gas excess will be reduced accordingly.
            // Note that when lastSyncedBlock is zero, we skip this step
            // because that means this is the first time calculating the basefee
            // and the difference between the L1 height would be extremely big,
            // reverting the initial gas excess value back to 0.
            uint256 numL1Blocks;
            if (lastSyncedBlock > 0 && _l1BlockId > lastSyncedBlock) {
                numL1Blocks = _l1BlockId - lastSyncedBlock;
            }

            if (numL1Blocks > 0) {
                uint256 issuance = numL1Blocks * _config.gasTargetPerL1Block;
                excess = excess > issuance ? excess - issuance : 1;
            }

            gasExcess_ = uint64(excess.min(type(uint64).max));

            // The base fee per gas used by this block is the spot price at the
            // bonding curve, regardless the actual amount of gas used by this
            // block, however, this block's gas used will affect the next
            // block's base fee.
            basefee_ = Lib1559Math.basefee(
                gasExcess_, uint256(_config.basefeeAdjustmentQuotient) * _config.gasTargetPerL1Block
            );
        }
```

Instead of issuing `_config.gasTargetPerL1Block` for each L1 block we end up issuing `uint256 issuance = (_l1BlockOd - lastSyncedBlock) * _config.gasTargetPerL1Block`.

`lastSyncedBlock` is only updated every 5 blocks.

<https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L145-L152>

```solidity
        if (_l1BlockId > lastSyncedBlock + BLOCK_SYNC_THRESHOLD) {
            // Store the L1's state root as a signal to the local signal service to
            // allow for multi-hop bridging.
            ISignalService(resolve("signal_service", false)).syncChainData(
                ownerChainId, LibSignals.STATE_ROOT, _l1BlockId, _l1StateRoot
            );
            lastSyncedBlock = _l1BlockId;
        }
```

If `anchor()` is called on 5 consecutive blocks we end up issuing
in total `15 * _config.gasTargetPerL1Block` instead of `5 * _config.gasTargetPerL1Block`.

When the calculated base fee is compared to the `block.basefee` the following happens:

- If `block.basefee`reports the correct base fee this will end up halting the chain since they will not match.

- If `block.basefee` is using the same flawed calculation the chain continues but with a severely reduced and incorrect base fee.

Here is a simple POC showing the actual issuance compared to the expected issuance. Paste the code into TaikoL1LibProvingWithTiers.t.sol and run `forge test --match-test testIssuance -vv`.

<details>

```solidity
    struct Config {
        uint32 gasTargetPerL1Block;
        uint8 basefeeAdjustmentQuotient;
    }

    function getConfig() public view virtual returns (Config memory config_) {
        config_.gasTargetPerL1Block = 15 * 1e6 * 4;
        config_.basefeeAdjustmentQuotient = 8;
    }

    uint256 lastSyncedBlock = 1;
    uint256 gasExcess = 10;
    function _calc1559BaseFee(
        Config memory _config,
        uint64 _l1BlockId,
        uint32 _parentGasUsed
    )
        private
        view
        returns (uint256 issuance, uint64 gasExcess_)
    {
        if (gasExcess > 0) {
            uint256 excess = uint256(gasExcess) + _parentGasUsed;

            uint256 numL1Blocks;
            if (lastSyncedBlock > 0 && _l1BlockId > lastSyncedBlock) {
                numL1Blocks = _l1BlockId - lastSyncedBlock;
            }

            if (numL1Blocks > 0) {
                issuance = numL1Blocks * _config.gasTargetPerL1Block;
                excess = excess > issuance ? excess - issuance : 1;
            }
			// I have commented out the below basefee calculation
			// and return issuance instead to show the actual
			// accumulated issuance over 5 L1 blocks.
			// nothing else is changed

            //gasExcess_ = uint64(excess.min(type(uint64).max));

            //basefee_ = Lib1559Math.basefee(
            //    gasExcess_, uint256(_config.basefeeAdjustmentQuotient) * _config.gasTargetPerL1Block
            //);
        }

        //if (basefee_ == 0) basefee_ = 1;
    }

    function testIssuance() external {
        uint256 issuance;
        uint256 issuanceAdded;
        Config memory config = getConfig();
        for (uint64 x=2; x <= 6 ;x++){

            (issuanceAdded ,) = _calc1559BaseFee(config, x, 0);
            issuance += issuanceAdded;
            console2.log("added", issuanceAdded);
        }

        uint256 expectedIssuance = config.gasTargetPerL1Block*5;
        console2.log("Issuance", issuance);
        console2.log("Expected Issuance", expectedIssuance);

        assertEq(expectedIssuance*3, issuance);

```

</details>

### Tools Used

Foundry, VScode

### Recommended Mitigation Steps

Issue exactly `config.gasTargetPerL1Block` for each L1 block.

**[dantaik (Taiko) confirmed and commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/276#issuecomment-2031033625):**

> This is a valid bug report. Fixed in this PR: https://github.com/taikoxyz/taiko-mono/pull/16543

**[0xean (Judge) commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/276#issuecomment-2045139998):**

> I don't see a direct loss of funds here and believe M is the correct severity.
>
> > 2 — Med: Assets not at direct risk, but the function of the protocol or its availability could be impacted, or leak value with a hypothetical attack path with stated assumptions, but external requirements.
>
> > 3 — High: Assets can be stolen/lost/compromised directly (or indirectly if there is a valid attack path that does not have hand-wavy hypotheticals).

**[0xmonrel (Warden) commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/276#issuecomment-2049465072):**

> A halted chain leads to frozen funds. The chain will progress for a minimum of 2 blocks since the calculation is correct when `lastSyncedBlock =0` and when `_l1BlockID-lastSyncedBlock=1`
>
> After the second block the base fee will still be correct as long as `excess < issuance` for both the inflated and correct calculating since both result in `excess=1` > https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L279-L282
>
> ```solidity
>             if (numL1Blocks > 0) {
>                 uint256 issuance = numL1Blocks * _config.gasTargetPerL1Block;
>                 excess = excess > issuance ? excess - issuance : 1;
>             }
> ```
>
> At the block where the base fee is incorrect the chain is halted and funds are locked since the anchor now reverts in perpetuity.
>
> In practice Taiko can easily release all funds by upgrading the contracts but I believe such an intervention should not be considered when evaluating the severity of an issue. From [C4 Supreme Court session, Fall 2023](https://docs.code4rena.com/awarding/judging-criteria/supreme-court-decisions-fall-2023)
>
> > Contract upgradability should never be used as a severity mitigation, i.e. we assume contracts are non-upgradable.
>
> I therefore believe a High is fair here.

**[0xean (Judge) commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/276#issuecomment-2049679633):**

> I don't entirely agree since the chain would be halted so soon in its existence, that being said, some amount of funds, albeit small, would likely be lost. @dantaik / @adaki2004 any last comments before leaving as H severity?

**[adaki2004 (Taiko) commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/276#issuecomment-2049949706):**

> Agreed, can do!

**[0xean (Judge) commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/276#issuecomment-2051543094):**

> Awarding as H, final decision.

---

## [[H-02] Validity and contests bond ca be incorrectly burned for the correct and ultimately verified transition](https://github.com/code-423n4/2024-03-taiko-findings/issues/266)

_Submitted by [monrel](https://github.com/code-423n4/2024-03-taiko-findings/issues/266), also found by [t0x1c](https://github.com/code-423n4/2024-03-taiko-findings/issues/227)_

<https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L387-L392>

<https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L189-L199>

<https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L178-L189>

Both validity and contests bonds can be wrongfully slashed even if the transition ends up being the correct and verified one.

The issue comes from the fact that the history of the final verified transition is not taken into account.

Example 1: Validity bond is wrongfully burned:

1.  Bob Proves transition T1 for parent P1
2.  Alice contests and proves T2 for parent P1 with higher tier proof.
3.  Guardians steps in to correctly prove T1 for parent P2.

At step 2 Bob loses his bond and is permanentley written out of the history of P1 <br><https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L387-L392>

```solidity
    _ts.validityBond = _tier.validityBond;
    _ts.contestBond = 1;
    _ts.contester = address(0);
    _ts.prover = msg.sender;
    _ts.tier = _proof.tier;
```

Example 2: Contest bond wrongfully slashed:

1.  Alice proves T1 for parent P1 with SGX
2.  Bob contests T1 for parent P1
3.  Alice proves T1 with SGX_ZK parent P1
4.  Guardian steps in to correctly disprove T1 with T2 for parent P1

Bob was correct and T1 was ultimately proven false. Bob still loses his contest bond.

When the guardian overrides the proof they can not pay back Bob's validity or contesting bond. They are only able to pay back a liveness bond <br><https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L189-L199>

```solidity
if (isTopTier) {
	// A special return value from the top tier prover can signal this
	// contract to return all liveness bond.
	bool returnLivenessBond = blk.livenessBond > 0 && _proof.data.length == 32
		&& bytes32(_proof.data) == RETURN_LIVENESS_BOND;

	if (returnLivenessBond) {
		tko.transfer(blk.assignedProver, blk.livenessBond);
		blk.livenessBond = 0;
	}
}
```

These funds are now frozen since they are sent to the Guardian contract which has no ability to recover them.

<https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L178-L189>

```solidity
                uint256 bondToReturn = uint256(ts.validityBond) + blk.livenessBond;

                if (ts.prover != blk.assignedProver) {
                    bondToReturn -= blk.livenessBond >> 1;
                }

                IERC20 tko = IERC20(_resolver.resolve("taiko_token", false));
                tko.transfer(ts.prover, bondToReturn)
```

`ts.prover` will be the Guardian since they are the last to prove the block

### Proof of Concept

POC for example 1. Paste the below code into the `TaikoL1LibProvingWithTiers.t` file and run `forge test --match-test testProverLoss -vv`

<details>

```solidity

    function testProverLoss() external{
        giveEthAndTko(Alice, 1e7 ether, 1000 ether);
        giveEthAndTko(Carol, 1e7 ether, 1000 ether);
        giveEthAndTko(Bob, 1e6 ether, 100 ether);
        console2.log("Bob balance:", tko.balanceOf(Bob));
        uint256 bobBalanceBefore = tko.balanceOf(Bob);
        vm.prank(Bob, Bob);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint256 blockId = 1;

        (TaikoData.BlockMetadata memory meta,) = proposeBlock(Alice, Bob, 1_000_000, 1024);

        console2.log("Bob balance After propose:", tko.balanceOf(Bob));
        mine(1);

        bytes32 blockHash = bytes32(1e10 + blockId);
        bytes32 stateRoot = bytes32(1e9 + blockId);

        (, TaikoData.SlotB memory b) = L1.getStateVariables();
        uint64 lastVerifiedBlockBefore = b.lastVerifiedBlockId;

        // Bob proves transition T1 for parent P1
        proveBlock(Bob, Bob, meta, parentHash, blockHash, stateRoot, meta.minTier, "");
        console2.log("Bob balance After proof:", tko.balanceOf(Bob));

        uint16 minTier = meta.minTier;

        // Higher Tier contests by proving transition T2 for same parent P1
        proveHigherTierProof(meta, parentHash, bytes32(uint256(1)), bytes32(uint256(1)), minTier);

        // Guardian steps in to prove T1 is correct transition for parent P1
        proveBlock(
            David, David, meta, parentHash, blockHash, stateRoot, LibTiers.TIER_GUARDIAN, ""
        );

        vm.roll(block.number + 15 * 12);

        vm.warp(
            block.timestamp + tierProvider().getTier(LibTiers.TIER_GUARDIAN).cooldownWindow * 60
                + 1
        );

        vm.roll(block.number + 15 * 12);
        vm.warp(
            block.timestamp + tierProvider().getTier(LibTiers.TIER_GUARDIAN).cooldownWindow * 60
                + 1
        );

        // When the correct transition T1 is verified Bob does permantley loses his validitybond
        // even though it is the correct transition for the verified parent P1.
        verifyBlock(Carol, 1);
        parentHash = blockHash;

        (, b) = L1.getStateVariables();
        uint64 lastVerifiedBlockAfter = b.lastVerifiedBlockId;
        assertEq(lastVerifiedBlockAfter, lastVerifiedBlockBefore + 1 ); // Verification completed

        uint256 bobBalanceAfter = tko.balanceOf(Bob);
        assertLt(bobBalanceAfter, bobBalanceBefore);

        console2.log("Bob Loss:", bobBalanceBefore - bobBalanceAfter);
        console2.log("Bob Loss without couting livenessbond:", bobBalanceBefore - bobBalanceAfter - 1e18); // Liveness bond is 1 ETH in tests
    }

```

</details>

### Tools Used

Foundry, VScode

### Recommended Mitigation Steps

The simplest solution is to allow the guardian to pay back validity and contest bonds in the same manner as for liveness bonds. This keeps the simple design while allowing bonds to be recovered if a prover or contesters action is ultimately proven correct.

Guardian will pass in data in `_proof.data` that specifies the address, tiers and bond type that should be refunded. Given that Guardians already can verify any proof this does not increase centralization.

We also need to not to not recover any reward when we prove with Guardian and `_overrideWithHigherProof()` is called. If the `ts.validityBond` reward is sent to the Guardian it will be locked. Instead we need to keep it in TaikoL1 such that it can be recovered as described above

```diff
+if (_tier.contestBond != 0){
	unchecked {
		if (reward > _tier.validityBond) {
			_tko.transfer(msg.sender, reward - _tier.validityBond);
		} else {
			_tko.transferFrom(msg.sender, address(this), _tier.validityBond - reward);
		}
	}
+}
```

**[dantaik (Taiko) commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/266#issuecomment-2033385962):**

> This is a valid report but we knew this "flaw" and the current behavior is by design.
>
> - The odd that a valid transition is proven, then contested and overwritten by another proof, then proven again with even a higher tier should be rare, if this happens even once, we should know the second prover is buggy and shall change the tier configuration to remove it.
> - For provers who suffer a loss due to such prover bugs, Taiko foundation may send them compensation to cover there loss. We do not want to handle cover-your-loss payment in the protocol.

**[adaki2004 (Taiko) confirmed, but disagreed with severity and commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/266#issuecomment-2033985576):**

> This is an attack on the tier system, right ? But the economical disincentives doing so shall be granted by the bonds - not to challenge proofs which we do know are correct, just to make someone lose money as there is no advantage. The challenger would lose even more money - and the correct prover would be refunded by Taiko Foundation.
>
> Severity: medium, (just as: https://github.com/code-423n4/2024-03-taiko-findings/issues/227)

**[0xean (Judge) commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/266#issuecomment-2045155377):**

> I am going to leave as H, I think there is a direct loss of funds here.
>
> This comment:
>
> > The challenger would lose even more money
>
> Makes me second guess that slightly, but still think H is correct.

---

## [[H-03] Users will never be able to withdraw their claimed airdrop fully in ERC20Airdrop2.sol contract](https://github.com/code-423n4/2024-03-taiko-findings/issues/245)

_Submitted by [MrPotatoMagic](https://github.com/code-423n4/2024-03-taiko-findings/issues/245), also found by [Aymen0909](https://github.com/code-423n4/2024-03-taiko-findings/issues/241), [alexfilippov314](https://github.com/code-423n4/2024-03-taiko-findings/issues/203), [pa6kuda](https://github.com/code-423n4/2024-03-taiko-findings/issues/149), and [t4sk](https://github.com/code-423n4/2024-03-taiko-findings/issues/51)_

**Context:**
The ERC20Airdrop2.sol contract is for managing Taiko token airdrop for eligible users, but the withdrawal is not immediate and is subject to a withdrawal window.

Users can claim their tokens within claimStart and claimEnd. Once the claim window is over at claimEnd, they can withdraw their tokens between claimEnd and claimEnd + withdrawalWindow. During this withdrawal period, the tokens unlock linearly i.e. the tokens only become fully withdrawable at claimEnd + withdrawalWindow.

**Issue:**
The issue is that once the tokens for a user are fully unlocked, the [withdraw()](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol#L88) function cannot be called anymore due to the [ongoingWithdrawals modifier](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol#L39) having a strict `claimEnd + withdrawalWindow < block.timestamp` check in its second condition.

**Impact:**
Although the tokens become fully unlocked when block.timestamp = claimEnd + withdrawalWindow, it is extremely difficult or close to impossible for normal users to time this to get their full allocated claim amount. This means that users are always bound to lose certain amount of their eligible claim amount. This lost amount can be small for users who claim closer to claimEnd + withdrawalWindow and higher for those who partially claimed initially or did not claim at all thinking that they would claim once their tokens are fully unlocked.

### Coded POC

How to use this POC:

- Add the POC to `test/team/airdrop/ERC20Airdrop2.t.sol`
- Run the POC using `forge test --match-test testAirdropIssue -vvv`
- The POC demonstrates how alice was only able to claim half her tokens out of her total 100 tokens claimable amount.

```solidity
      function testAirdropIssue() public {
        vm.warp(uint64(block.timestamp + 11));

        vm.prank(Alice, Alice);
        airdrop2.claim(Alice, 100, merkleProof);

        // Roll 5 days after
        vm.roll(block.number + 200);
        vm.warp(claimEnd + 5 days);

        airdrop2.withdraw(Alice);

        console.log("Alice balance:", token.balanceOf(Alice));

        // Roll 6 days after
        vm.roll(block.number + 200);
        vm.warp(claimEnd + 11 days);

        vm.expectRevert(ERC20Airdrop2.WITHDRAWALS_NOT_ONGOING.selector);
        airdrop2.withdraw(Alice);
    }
```

### Logs

```solidity
Logs:
  > MockERC20Airdrop @ 0x0000000000000000000000000000000000000000
    proxy      : 0xF62849F9A0B5Bf2913b396098F7c7019b51A820a
    impl       : 0x2e234DAe75C793f67A35089C9d99245E1C58470b
    owner      : 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496
    msg.sender : 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
    this       : 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496
  Alice balance: 50
```

### Recommended Mitigation Steps

In the [modifier ongoingWithdrawals()](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol#L39), consider adding a buffer window in the second condition that gives users enough time to claim the fully unlocked tokens.

```solidity
    uint256 constant bufferWindow = X mins/hours/days;

    modifier ongoingWithdrawals() {
        if (claimEnd > block.timestamp || claimEnd + withdrawalWindow < block.timestamp + bufferWindow) {
            revert WITHDRAWALS_NOT_ONGOING();
        }
        _;
    }
```

**[dantaik (Taiko) commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/245#issuecomment-2033388656):**

> Fixed in https://github.com/taikoxyz/taiko-mono/pull/16596

**[adaki2004 (Taiko) confirmed and commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/245#issuecomment-2037149300):**

> It is indeed a bug in the flow, while we removed Airdrop2, it is still a confirmed finding on the repo for auditing.

---

## [[H-04] Taiko L1 - Proposer can maliciously cause loss of funds by forcing someone else to pay prover's fee](https://github.com/code-423n4/2024-03-taiko-findings/issues/163)

_Submitted by [zzebra83](https://github.com/code-423n4/2024-03-taiko-findings/issues/163), also found by [MrPotatoMagic](https://github.com/code-423n4/2024-03-taiko-findings/issues/351), [monrel](https://github.com/code-423n4/2024-03-taiko-findings/issues/270), [mojito_auditor](https://github.com/code-423n4/2024-03-taiko-findings/issues/250), and [ladboy233](https://github.com/code-423n4/2024-03-taiko-findings/issues/191)_

<https://github.com/code-423n4/2024-03-taiko/blob/0d081a40e0b9637eddf8e760fabbecc250f23599/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L113-L116>

<https://github.com/code-423n4/2024-03-taiko/blob/0d081a40e0b9637eddf8e760fabbecc250f23599/packages/protocol/contracts/L1/libs/LibProposing.sol#L85-L87>

<https://github.com/code-423n4/2024-03-taiko/blob/0d081a40e0b9637eddf8e760fabbecc250f23599/packages/protocol/contracts/L1/libs/LibProposing.sol#L249-L255>

Proposal of new blocks triggers a call to proposeBlock in the libProposing library. In that function, there is this the following block of code:

            if (params.coinbase == address(0)) {
            params.coinbase = msg.sender;
        }

This sets the params.coinbase variable set by the caller of the function to be the msg.sender if it was empty.

As part of the process of proposal, hooks can be called of type AssignmentHook. An assignment hook's onBlockProposed will be triggered as follows:

                    // When a hook is called, all ether in this contract will be send to the hook.
                // If the ether sent to the hook is not used entirely, the hook shall send the Ether
                // back to this contract for the next hook to use.
                // Proposers shall choose use extra hooks wisely.
                IHook(params.hookCalls[i].hook).onBlockProposed{ value: address(this).balance }(
                    blk, meta_, params.hookCalls[i].data
                );

Notice how the meta data is passed to this function. Part of the function of the onBlockProposed is to pay the assigned prover their fee and the payee should be the current proposer of the block. this is done as follows:

            // The proposer irrevocably pays a fee to the assigned prover, either in
        // Ether or ERC20 tokens.
        if (assignment.feeToken == address(0)) {
            // Paying Ether
            _blk.assignedProver.sendEther(proverFee, MAX_GAS_PAYING_PROVER);
        } else {
            // Paying ERC20 tokens
            IERC20(assignment.feeToken).safeTransferFrom(
                _meta.coinbase, _blk.assignedProver, proverFee
            );
        }

Notice how if the payment is in ERC20 tokens, the payee will be the variable \_meta.coinbase, and like we showed earlier, this can be set to any arbitrary address by the proposer. This can lead to a scenario as such:

1.  proposer A approves the assignmentHook contract to spend a portion of their tokens, the allowance is set higher than the actual fee they will be paying.
2.  proposer A proposes a block, and a fee is charged and payed to the assigned prover, but there remains allowance that the assignment hook contract can still use.
3.  proposer B proposes a block and sets params.coinbase as the the address of proposer A.
4.  proposer A address will be the payee of the fee for the assigned prover for the block proposed by proposer B.

The scenario above describes how someone can be forced maliciously to pay fees for block proposals by other actors.

### Recommended Mitigation Steps

A simple fix to this to ensure the block proposer will always be the msg.sender, as such:

        if (params.coinbase == address(0 || params.coinbase != msg.sender)) {
            params.coinbase = msg.sender;
        }

**[dantaik (Taiko) confirmed and commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/163#issuecomment-2032257802):**

> This is a valid bug report. It has been fixed here: https://github.com/taikoxyz/taiko-mono/pull/16327

---

## [[H-05] Signatures can be replayed in `withdraw()` to withdraw more tokens than the user originally intended.](https://github.com/code-423n4/2024-03-taiko-findings/issues/60)

_Submitted by [lightoasis](https://github.com/code-423n4/2024-03-taiko-findings/issues/60), also found by [0xleadwizard](https://github.com/code-423n4/2024-03-taiko-findings/issues/277), [wangxx2026](https://github.com/code-423n4/2024-03-taiko-findings/issues/254), [alexfilippov314](https://github.com/code-423n4/2024-03-taiko-findings/issues/204), [ladboy233](https://github.com/code-423n4/2024-03-taiko-findings/issues/178), and [Tendency](https://github.com/code-423n4/2024-03-taiko-findings/issues/121)_

Signatures can be replayed in `withdraw()` to withdraw more tokens than the user originally intended.

### Vulnerability Details

In the TimelockTokenPool.sol contracts, users can provide a signature to allow someone else to withdraw all their withdrawable tokens on their behalf using their signature. [TimelockTokenPool.sol#L170) ](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L170)

        function withdraw(address _to, bytes memory _sig) external {
            if (_to == address(0)) revert INVALID_PARAM();
            bytes32 hash = keccak256(abi.encodePacked("Withdraw unlocked Taiko token to: ", _to));
     @>     address recipient = ECDSA.recover(hash, _sig);
            _withdraw(recipient, _to);
        }

As seen from above, the signature provided does not include a nonce and this can lead to signature replay attacks. Due to the lack of a nonce, withdraw() can be called multiple times with the same signature. Therefore, if a user provides a signature to withdraw all his withdrawable tokens at one particular time, an attacker can repeatedly call withdraw() with the same signature to withdraw more tokens than the user originally intended.
The vulnerability is similar to [Arbitrum H-01](https://solodit.xyz/issues/h-01-signatures-can-be-replayed-in-castvotewithreasonandparamsbysig-to-use-up-more-votes-than-a-user-intended-code4rena-arbitrum-foundation-arbitrum-foundation-git) where user's signatures could be replayed to use up more votes than a user intended due to a lack of nonce.

### Recommended Mitigation Steps

Consider using a nonce or other signature replay protection in the TimelockTokenPool contract.

**[dantaik (Taiko) confirmed and commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/60#issuecomment-2032045461):**

> Valid bug report, trying to fix it in this PR: https://github.com/taikoxyz/taiko-mono/pull/16611/files

---

# Medium Risk Findings (14)

## [[M-01] There is no slippage check for the eth deposits processing in the `LibDepositing.processDeposits`](https://github.com/code-423n4/2024-03-taiko-findings/issues/321)

_Submitted by [Shield](https://github.com/code-423n4/2024-03-taiko-findings/issues/321), also found by [ladboy233](https://github.com/code-423n4/2024-03-taiko-findings/issues/185)_

<https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibDepositing.sol#L138-L142>

<https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/TaikoL1.sol#L209-L211>

<https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibDepositing.sol#L83>

<https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibDepositing.sol#L93>

<https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibDepositing.sol#L101>

The `LibDepositing.depositEtherToL2` function is called by the TaikoL1.depositEtherToL2 to deposit ether to the `L2 chain`. The maximum number of `unprocessed eth deposits` are capped at `_config.ethDepositRingBufferSize - 1` as shown here:

```solidity
        unchecked {
            return _amount >= _config.ethDepositMinAmount && _amount <= _config.ethDepositMaxAmount
                && _state.slotA.numEthDeposits - _state.slotA.nextEthDepositToProcess
                    < _config.ethDepositRingBufferSize - 1;
        }
```

The Taiko configuration states that `ethDepositRingBufferSize == 1024`. Hence the maximum unprocessed eth deposits allowed by the taiko L1 contract is `capped at 1023`.

When the L2 block is proposed by calling the `LibProposing.proposeBlock` function by the TaikoL1 contract, it processes the unprocessed `eth deposits` by calling the `LibDepositing.processDeposits`. But it is allowed to process `at most 32 eth deposits per block` as per the following conditional check in the `processDeposits` function.

```solidity
deposits_ = new TaikoData.EthDeposit[(numPending.min(_config.ethDepositMaxCountPerBlock));
```

Here the `ethDepositMaxCountPerBlock == 32` as configured in the `TaikoL1.getConfig` function.

And the `fee amount` for each of the `eth deposits` are calculated as follows:

```solidity
uint96 fee = uint96(_config.ethDepositMaxFee.min(block.basefee * _config.ethDepositGas));

uint96 _fee = deposits_[i].amount > fee ? fee : deposits_[i].amount;

deposits_[i].amount -= _fee;
```

Hence the `deposited eth amount` is deducted by the calculated `_fee amount` for the `eth deposit transaction`. If the basefee of the `L1 block` increases significantly then the maximum fee of `ethDepositMaxFee: 1 ether / 10` will be applied. Thus deducting that amount from the `transferred eth deposit to the recipient in L2`.

Now let's consider the following scenario:

1.  `nextEthDepositToProcess` is currently `100`.
2.  `numEthDeposits` is `1060` currently.
3.  The number of proposed L2 blocks required to process 1060th eth deposit is = 1060 - 100 / 32 = 30 L2 blocks.
4.  As a result all the `above 30 L2 blocks` will not be proposed in a single L1 block and will require multiple L1 blocks for it.
5.  If there is `huge congestion` in the mainnet during this time the `block.basefee` of the subsequent `L1 blocks` would increase. And this could prompt the maximum fee of `_config.ethDepositMaxFee` to be charged on the deposited amount (in the `LibDepositing.processDeposits` function, since subsequent L1 block would have a higher `block.basefee`) thus prompting loss of funds on the recipient.
6.  For example let's assume the depositor deposit `1.1 ether` and current gas fee is `0.01 ether`. Hence the recipient expects to receive approximately `1.09 ether` at the time of the deposit on L1. But when the deposit is processed in a subsequent L1 block, if the fee amount increases to the maximum amount of `0.1 ether` then the recipient will only get approximately `1 ether` only. This will cost the recipient a `loss of 0.9 ether`. If there was a slippage check a depositor can set for his eth deposits then the he can prevent excessive gas costs during processing.

### Proof of Concept

```solidity
        unchecked {
            return _amount >= _config.ethDepositMinAmount && _amount <= _config.ethDepositMaxAmount
                && _state.slotA.numEthDeposits - _state.slotA.nextEthDepositToProcess
                    < _config.ethDepositRingBufferSize - 1;
        }
```

<https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibDepositing.sol#L138-L142>

```solidity
            ethDepositRingBufferSize: 1024,
            ethDepositMinCountPerBlock: 8,
            ethDepositMaxCountPerBlock: 32,
```

<https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/TaikoL1.sol#L209-L211>

```solidity
            uint96 fee = uint96(_config.ethDepositMaxFee.min(block.basefee * _config.ethDepositGas));
```

<https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibDepositing.sol#L83>

```solidity
                uint96 _fee = deposits_[i].amount > fee ? fee : deposits_[i].amount;
```

<https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibDepositing.sol#L93>

```solidity
                    deposits_[i].amount -= _fee;
```

<https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibDepositing.sol#L101>

### Tools Used

VSCode

### Recommended Mitigation Steps

Hence it is recommended to add a slippage check for the fee amount of the deposited eth amount in the `LibDepositing.processDeposits` function, since `depositEtherToL2` and `processDepositare` two different transactions with a delay during which the L1 block `basefee` can increase significantly causing loss of funds to the recipient in the form of fee increase.

**[dantaik (Taiko) acknowledged, but disagreed with severity and commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/321#issuecomment-2033375181):**

> Thank you for the feedback. The current issue is **valid but minor** as we believe users can choose not to deposit Ether using the `depositEtherToL2` function if there are already many deposits pending in the queue. Going forward, the processing of such deposits will likely be moved to the node software directly.

**[0xean (Judge) commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/321#issuecomment-2045819455):**

> Agree this is valid, the impact is most likely small, but I think the likelihood of it occurring at some point is relatively high. The user is exposed to non-deterministic behavior that they cannot fully understand ahead of signing a transaction.

---

## [[M-02] The top tier prover can not re-prove](https://github.com/code-423n4/2024-03-taiko-findings/issues/305)

_Submitted by [Shield](https://github.com/code-423n4/2024-03-taiko-findings/issues/305), also found by [zzebra83](https://github.com/code-423n4/2024-03-taiko-findings/issues/165) and [Tendency](https://github.com/code-423n4/2024-03-taiko-findings/issues/118)_

<https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibProving.sol#L219-L236>

<https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibProving.sol#L389>

In the `LibProving.proveBlock` function the `top tier prover` is allowed to prove a new transition as long as the new transition is different from the previous transition and `assert` conditional checks pass.

```solidity
            if (sameTransition) revert L1_ALREADY_PROVED();

            if (isTopTier) {
                // The top tier prover re-proves.
                assert(tier.validityBond == 0);
                assert(ts.validityBond == 0 && ts.contestBond == 0 && ts.contester == address(0));
```

But the `assert condition` of this logic is wrong since it checks for the `ts.contestBond == 0` where as it should be `ts.contestBond == 1` since 1 is set as the default value for `ts.contestBond` parameter for gas savings as shown below:

```solidity
            ts_.contestBond = 1; // to save gas
```

As a result of the even though code expects the top-tier prover to re-prove a different transition, the transaction will revert.

### Proof of Concept

Add the following testcase `test_L1_GuardianProverCanOverwriteIfNotSameProof_test` to the `TaikoL1LibProvingWithTiers.t.sol` test file.

If you change the ts.contestBond == 0
to ts.contestBond == 1 in the second `assert` statement of the `LibProving.proveBlock` function, the test will run successfully and transaction execution will succeed.

<details>

```solidity
    function test_L1_GuardianProverCanOverwriteIfNotSameProof_test() external {
        giveEthAndTko(Alice, 1e7 ether, 1000 ether);
        giveEthAndTko(Carol, 1e7 ether, 1000 ether);
        console2.log("Alice balance:", tko.balanceOf(Alice));
        // This is a very weird test (code?) issue here.
        // If this line is uncommented,
        // Alice/Bob has no balance.. (Causing reverts !!!)
        // Current investigations are ongoing with foundry team
        giveEthAndTko(Bob, 1e7 ether, 100 ether);
        console2.log("Bob balance:", tko.balanceOf(Bob));
        // Bob
        vm.prank(Bob, Bob);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        for (uint256 blockId = 1; blockId < conf.blockMaxProposals * 3; blockId++) {
            printVariables("before propose");
            (TaikoData.BlockMetadata memory meta,) = proposeBlock(Alice, Bob, 1_000_000, 1024);
            //printVariables("after propose");
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 stateRoot = bytes32(1e9 + blockId);
            // This proof cannot be verified obviously because of
            // blockhash:blockId
            proveBlock(Bob, Bob, meta, parentHash, stateRoot, stateRoot, LibTiers.TIER_GUARDIAN, "");

            // Prove as guardian
            proveBlock(
                Carol, Carol, meta, parentHash, blockHash, stateRoot, LibTiers.TIER_GUARDIAN, ""
            );

            vm.roll(block.number + 15 * 12);

            uint16 minTier = meta.minTier;
            vm.warp(block.timestamp + tierProvider().getTier(LibTiers.TIER_GUARDIAN).cooldownWindow * 60 + 1);

            verifyBlock(Carol, 1);

            parentHash = blockHash;
        }
        printVariables("");
    }
```

</details>

### Tools Used

VSCode

### Recommended Mitigation Steps

Hence recommended to update the `ts.contestBond == 0` in the second `assert` statement to `ts.contestBond == 1` in the `LibProving.proveBlock` function.

**[dantaik (Taiko) confirmed and commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/305#issuecomment-2031537557):**

> This is a valid bug report, it has been fixed already here: https://github.com/taikoxyz/taiko-mono/pull/16543

---

## [[M-03] retryMessage unable to handle edge cases.](https://github.com/code-423n4/2024-03-taiko-findings/issues/298)

_Submitted by [josephdara](https://github.com/code-423n4/2024-03-taiko-findings/issues/298), also found by [josephdara](https://github.com/code-423n4/2024-03-taiko-findings/issues/296), [grearlake](https://github.com/code-423n4/2024-03-taiko-findings/issues/314), [Shield](https://github.com/code-423n4/2024-03-taiko-findings/issues/286), MrPotatoMagic ([1](https://github.com/code-423n4/2024-03-taiko-findings/issues/281), [2](https://github.com/code-423n4/2024-03-taiko-findings/issues/273)), [Aymen0909](https://github.com/code-423n4/2024-03-taiko-findings/issues/242), [ladboy233](https://github.com/code-423n4/2024-03-taiko-findings/issues/182), [iamandreiski](https://github.com/code-423n4/2024-03-taiko-findings/issues/150), [lanrebayode77](https://github.com/code-423n4/2024-03-taiko-findings/issues/107), [t0x1c](https://github.com/code-423n4/2024-03-taiko-findings/issues/48), and Fassi_Security ([1](https://github.com/code-423n4/2024-03-taiko-findings/issues/29), [2](https://github.com/code-423n4/2024-03-taiko-findings/issues/26))_

The function `retryMessage()` is unable to handle some edge scenarios listed below.

1.  Reverting or refunding a sender when the receiver is banned after the transaction is placed in a `RETRIABLE` state.
2.  Message that is suspended after the transaction is placed in a `RETRIABLE` state.

### Proof of Concept

A message is set to `RETRIABLE`in the `processMessage` when transfer fails or if the target address does not satisfy some conditions.

<details>

```solidity
//IN PROCESSMESSAGE

                if (_invokeMessageCall(_message, msgHash, gasLimit)) {
                    _updateMessageStatus(msgHash, Status.DONE);
                } else {
                    _updateMessageStatus(msgHash, Status.RETRIABLE);
                }


//_invokeMessageCall() FUNCTION
function _invokeMessageCall(
        Message calldata _message,
        bytes32 _msgHash,
        uint256 _gasLimit
    )
        private
        returns (bool success_)
    {
        if (_gasLimit == 0) revert B_INVALID_GAS_LIMIT();
        assert(_message.from != address(this));

        _storeContext(_msgHash, _message.from, _message.srcChainId);

        if (
            _message.data.length >= 4 // msg can be empty
                && bytes4(_message.data) != IMessageInvocable.onMessageInvocation.selector
                && _message.to.isContract()
        ) {
            success_ = false;
        } else {
            (success_,) = ExcessivelySafeCall.excessivelySafeCall(
                _message.to,
                _gasLimit,
                _message.value,
                64, // return max 64 bytes
                _message.data
            );
        }

        // Must reset the context after the message call
        _resetContext();
    }
```

</details>

The issue here is, when the team attempts suspension of a message which is in a `RETRIABLE` state, the code does not block execution.
Same or a banned address.
This is because the `proofReceipt[msgHash]` which handles suspension is not checked. The ` addressBanned[_addr]` is not checked too.

<details>

```solidity
    function retryMessage(
        Message calldata _message,
        bool _isLastAttempt
    )
        external
        nonReentrant
        whenNotPaused
        sameChain(_message.destChainId)
    {
        // If the gasLimit is set to 0 or isLastAttempt is true, the caller must
        // be the message.destOwner.
        if (_message.gasLimit == 0 || _isLastAttempt) {
            if (msg.sender != _message.destOwner) revert B_PERMISSION_DENIED();
        }

        bytes32 msgHash = hashMessage(_message);
        if (messageStatus[msgHash] != Status.RETRIABLE) {
            revert B_NON_RETRIABLE();
        }

        // Attempt to invoke the messageCall.
        if (_invokeMessageCall(_message, msgHash, gasleft())) {
            _updateMessageStatus(msgHash, Status.DONE);
        } else if (_isLastAttempt) {
            _updateMessageStatus(msgHash, Status.FAILED);
        }
```

</details>

### Recommended Mitigation Steps

Recheck necessary details to verify that the transaction is still good to go.
Check the `proofReceipt[msgHash].receivedAt` and the ` addressBanned[_addr]`

**[adaki2004 (Taiko) disputed and commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/298#issuecomment-2031829775):**

> I'd dispute this with an addition (see end sentence).
>
> 2 cases mentioned here:
>
> 1. Reverting or refunding a sender when the receiver is banned after the transaction is placed in a RETRIABLE state.
>
> Intentional to NOT refund sender when he/she is banned. (Tho we might remove the "banAddress", because it confuses a lot of people. The original intention behind banning an address is: NOT be able to call another , very important contract (`message.to`) on behalf of the `Bridge`, like the `SignalService`.)
>
> 2. Message that is suspended after the transaction is placed in a RETRIABLE state.
>    Not to refund suspended messages is a feature, it is a failsafe/security mechanism. In such case we need to use it, it would be a severe situation and we do not necessary want to refund (by default) the owner, since it might be a fake message on the destination chain. (That can be one reason - so makes no sense to refund).
>    Also suspension would never happen after RETRIABLE. If we suspend message it is between NEW and (DONE or RETRIABLE).
>
> So as we considering removing banning addresses (and not allow `SignalService` to be called) for avoid confusion, but not because it is an issue, but a simplification and to avoid confusion. https://github.com/taikoxyz/taiko-mono/pull/16604

**[0xean (Judge) commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/298#issuecomment-2051841623):**

> Using this issue to aggregate all of the issues around ban list functionality that has since been removed from the sponsors code base.

_Note: For full discussion, see [here](https://github.com/code-423n4/2024-03-taiko-findings/issues/298)._

---

## [[M-04] A recalled ERC20 bridge transfer can lock tokens in the bridge](https://github.com/code-423n4/2024-03-taiko-findings/issues/279)

_Submitted by [monrel](https://github.com/code-423n4/2024-03-taiko-findings/issues/279), also found by [monrel](https://github.com/code-423n4/2024-03-taiko-findings/issues/271)_

<https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L320-L335>

<https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/adapters/USDCAdapter.sol#L43-L45>

<https://github.com/circlefin/stablecoin-evm/blob/0828084aec860712531e8d79fde478927a34b3f4/contracts/v1/FiatTokenV1.sol#L133-L136>

A recalling ERC20 bridge transfer can lock funds in the bridge if the call to mint tokens fail on the source chain. Depending on the Native token logic this could either be a permanent lock or a lock of an unknown period of time.

Example of how this can happen with the provided USDCAdapter:

USDC limits the amount of USDC that can be minted on each chain by giving each minter a minting allowance. If the minting allowance is reach minting will revert. If this happens in a recalled message the tokens together with the ETH value is locked.

### Proof of Concept

USDC limits the amount of USDC that can be minted on each chain by giving each minter a minting allowance.

If `_amount <= mintingAllowedAmount` is reached for the `USDCAdapter` tokens can not be minted but since this is a recalled message the funds are stuck.

Both `onMessageIncovation()` and `onMessageRecalled()` call `_transferToken()` to either mint or release tokens.

<https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L320-L335>

```solidity
    function _transferTokens(
        CanonicalERC20 memory _ctoken,
        address _to,
        uint256 _amount
    )
        private
        returns (address token_)
    {
        if (_ctoken.chainId == block.chainid) {
            token_ = _ctoken.addr;
            IERC20(token_).safeTransfer(_to, _amount);
        } else {
            token_ = _getOrDeployBridgedToken(_ctoken);
            IBridgedERC20(token_).mint(_to, _amount);
        }
    }
```

A recalled message to bridge USDC L1->L2 will revert when we attempt to mint through the `USDCAdapter`

<https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/adapters/USDCAdapter.sol#L43-L45>

```solidity
    function _mintToken(address _account, uint256 _amount) internal override {
        usdc.mint(_account, _amount);

```

On the following condition in the native USDC contract

<https://github.com/circlefin/stablecoin-evm/blob/0828084aec860712531e8d79fde478927a34b3f4/contracts/v1/FiatTokenV1.sol#L133-L136>

```solidity
        require(
            _amount <= mintingAllowedAmount,
            "FiatToken: mint amount exceeds minterAllowance"
        );
```

Course of events that ends in locked funds:

1.  User bridges USDC from L2->L1
2.  The message is recalled from L1
3.  The USDCAdapter has reached the `mintingAllowedAmount`
4.  The recalled message is stuck because minting reverts. The USDC and ETH passed in are both locked.

### Tools Used

Foundry, VScode

### Recommended Mitigation Steps

Add new functionality in the vault that allows users to send a new message to the destination chain again with new message data if `onMessageRecalls()` can not mint tokens. We give users the ability to redeem for canonical tokens instead of being stuck.

**[dantaik (Taiko) acknowledged and commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/279#issuecomment-2033383461):**

> Thank you for your feedback. In your example, if the user cannot mint tokens in USDCAdapter by using `recallMessage`, the user can wait and call `recallMessage` again. That's why recallMessage is _retriable_.
>
> There is no perfect solution here, and I personally don't want to make the bridge too complicated by introducing this re-send-another-message feature.
>
> Adding a warning on the bridge UI to show a warning message might be a good solution, something like "USDC on Taiko has reached 95% of its max supply cap, bridging USDC to Taiko may end up your fund becoming unavailable for some time until others bridge USDC away from Taiko".

**[0xean (Judge) commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/279#issuecomment-2049345554):**

> The sponsor comments simply show their isn't a great solution to the problem, it still represents a loss of user funds (if it goes on forever) or a denial of service and a risk that users should be aware of.
>
> @dontonka / @adaki2004 (Taiko) any last comments here?

**[adaki2004 (Taiko) commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/279#issuecomment-2049448918):**

> We are OK with med, no issue. Please proceed accordinlgy - as we dont have:
>
> 1. the perfect solution to the problem
> 2. the intention to fix it ATM - since we wont be using any native tokens anytime soon.
>
> But please proceed the way which is suitable for the wardens better, we appreciate their efforts. (So not questioning the severity)

---

## [[M-05] Bridge watcher can forge arbitrary message and drain bridge](https://github.com/code-423n4/2024-03-taiko-findings/issues/278)

_Submitted by [monrel](https://github.com/code-423n4/2024-03-taiko-findings/issues/278), also found by [josephdara](https://github.com/code-423n4/2024-03-taiko-findings/issues/294), [Shield](https://github.com/code-423n4/2024-03-taiko-findings/issues/221), and [t0x1c](https://github.com/code-423n4/2024-03-taiko-findings/issues/47)_

<https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L82-L95>

<https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L230-L231>

The `bridge_watchdog` role can forge arbitrary messages and drain the bridge of all ETH and tokens.

### Proof of Concept

`bridge_watchdog` can call `suspendMessasges()` to suspend and un-suspend a message

<https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L82-L95>

```solidity
    function suspendMessages(
        bytes32[] calldata _msgHashes,
        bool _suspend
    )
        external
        onlyFromOwnerOrNamed("bridge_watchdog")
    {
        uint64 _timestamp = _suspend ? type(uint64).max : uint64(block.timestamp);
        for (uint256 i; i < _msgHashes.length; ++i) {
            bytes32 msgHash = _msgHashes[i];
            proofReceipt[msgHash].receivedAt = _timestamp;
            emit MessageSuspended(msgHash, _suspend);
        }
    }
```

When this function is called to un-suspend a message we set `proofReceipt[msgHash] = _timestamp`. If the msgHash was not proven before it will now be treated as proven since any `msgHash` with a `timestamp != 0` is treated as proven

<https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L230-L231>

```solidity
        uint64 receivedAt = proofReceipt[msgHash].receivedAt;
        bool isMessageProven = receivedAt != 0
```

`bridge_watchdog` can therefore forge arbitrary messages and have them treated as proven by first suspending them and then un-suspending them.

`bride_watchdog` is supposed to only be able to ban and suspend messages, in the expected worst case `bridge_watchdog` is limited to DDOSing messages and bans until governance removes the the `bridge_watchdog`.

With the privilege escalation shown here the role can instead drain the bridge of all ETH and tokens.

### POC

Here is a POC showing that we can forge an arbitrary message by suspending and un-suspending a message

To run this POC first change the following code in Bridge.t.sol so that we use a real signalService

```diff
register(
+address(addressManager), "signal_service", address(signalService), destChainId
-address(addressManager), "signal_service", address(mockProofSignalService), destChainId
);
```

Paste the below code and run into Bridge.t.sol and run `forge test --match-test testWatchdogDrain -vvv`

<details>

```solidity
    function testWatchdogDrain() public {
        uint256 balanceBefore = Bob.balance;
        IBridge.Message memory message = IBridge.Message({
            id: 0,
            from: address(bridge),
            srcChainId: uint64(block.chainid),
            destChainId: destChainId,
            srcOwner: Alice,
            destOwner: Alice,
            to: Bob,
            refundTo: Alice,
            value: 10 ether,
            fee: 1,
            gasLimit: 1_000_000,
            data: "",
            memo: ""
        });


        bytes memory proof = hex"00";
        bytes32 msgHash = destChainBridge.hashMessage(message);

        bytes32[] memory msgHashA = new bytes32[](1);
        msgHashA[0] = msgHash;

        vm.prank(Alice);
        destChainBridge.suspendMessages(msgHashA, true);

        vm.prank(Alice);
        destChainBridge.suspendMessages(msgHashA, false);

        vm.chainId(destChainId);
        vm.prank(Bob, Bob);

        destChainBridge.processMessage(message, proof);

        IBridge.Status status = destChainBridge.messageStatus(msgHash);

        assertEq(status == IBridge.Status.DONE, true);
        console2.log("Bobs Stolen funds", Bob.balance-balanceBefore);

        console2.log("We have successfully processed a message without actually proving it!");
    }

```

</details>

### Tools Used

Foundry, VScode

### Recommended Mitigation Steps

Un-suspended messages should be set to 0 and be proven or re-proven.

```diff
    function suspendMessages(
        bytes32[] calldata _msgHashes,
        bool _suspend
    )
        external
        onlyFromOwnerOrNamed("bridge_watchdog")
    {
+       uint64 _timestamp = _suspend ? type(uint64).max : 0;
        for (uint256 i; i < _msgHashes.length; ++i) {
            bytes32 msgHash = _msgHashes[i];
            proofReceipt[msgHash].receivedAt = _timestamp;
            emit MessageSuspended(msgHash, _suspend);
        }
    }
```

**[dantaik (Taiko) confirmed and commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/278#issuecomment-2031031880):**

> This is a valid bug report. The bug has been fixed in this PR: https://github.com/taikoxyz/taiko-mono/pull/16545

**[0xean (Judge) decreased severity to Medium and commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/278#issuecomment-2045135078):**

> Good report, but I am not sure it qualifies as H severity and most likely should be M.
>
> I think there is a pre-condition here (a malicious watchdog).
>
> > 2 — Med: Assets not at direct risk, but the function of the protocol or its availability could be impacted, or leak value with a hypothetical attack path with stated assumptions, but external requirements.
>
> Agree that if this attack is feasible, it represents privilege escalation.
>
> As pointed out previously:
>
> > Privilege escalation issues are judged by likelihood and impact and their severity is uncapped.

_Note: For full discussion, see [here](https://github.com/code-423n4/2024-03-taiko-findings/issues/278)._

---

## [[M-06] First block proposer check in the `LibProposing._isProposerPermitted` function is errorneous](https://github.com/code-423n4/2024-03-taiko-findings/issues/274)

_Submitted by [Shield](https://github.com/code-423n4/2024-03-taiko-findings/issues/274), also found by [monrel](https://github.com/code-423n4/2024-03-taiko-findings/issues/382) and [blockdev](https://github.com/code-423n4/2024-03-taiko-findings/issues/9)_

<https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibProposing.sol#L93-L94>

<https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibProposing.sol#L299-L317>

The `LibProposing.proposeBlock` function calls the `_isProposerPermitted` private function, to ensure if the `proposer is set`. Only that specific address has the permission to propose the block.

In the `_isProposerPermitted` function, for the first block after the genesis block only the `proposerOne` is allowed to propose the first block as shown below:

```solidity
            address proposerOne = _resolver.resolve("proposer_one", true);
            if (proposerOne != address(0) && msg.sender != proposerOne) {
                return false;
            }
```

But the issue here is that when the `msg.sender == proposerOne` the function `does not return true` if the following conditions occur.

If the `proposer != address(0) && msg.sender != proposer`. In which case even though the `msg.sender == proposerOne` is `true` for the first block the `_isProposerPermitted` will still return `false` thus reverting the block proposer for the first block.

Hence even though the `proposer_one` is the proposer of the first block the transaction will still revert if the above mentioned conditions occur and the `_isProposerPermitted` returns `false` for the first block after the genesis block.

Hence this will break the block proposing logic since the proposal of the first block after the genesis block reverts thus not allowing subsequent blocks to be proposed.

### Proof of Concept

```solidity
        TaikoData.SlotB memory b = _state.slotB;
        if (!_isProposerPermitted(b, _resolver)) revert L1_UNAUTHORIZED();
```

<https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibProposing.sol#L93-L94>

```solidity
    function _isProposerPermitted(
        TaikoData.SlotB memory _slotB,
        IAddressResolver _resolver
    )
        private
        view
        returns (bool)
    {
        if (_slotB.numBlocks == 1) {
            // Only proposer_one can propose the first block after genesis
            address proposerOne = _resolver.resolve("proposer_one", true);
            if (proposerOne != address(0) && msg.sender != proposerOne) {
                return false;
            }
        }

        address proposer = _resolver.resolve("proposer", true);
        return proposer == address(0) || msg.sender == proposer;
    }
```

<https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibProposing.sol#L299-L317>

### Tools Used

VSCode

### Recommended Mitigation Steps

It is recommended to add logic in the `LibProposing._isProposerPermitted` function to `return true` when the `msg.sender == proposerOne`, for proposing the first block after genesis block.

**[dantaik (Taiko) confirmed and commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/274#issuecomment-2031595523):**

> I think this is a valid bug: fixing it [here](https://github.com/taikoxyz/taiko-mono/pull/16605)

---

## [[M-07] Incorrect \_\_Essential_init() function is used in TaikoToken making snapshooter devoid of calling snapshot()](https://github.com/code-423n4/2024-03-taiko-findings/issues/261)

_Submitted by [MrPotatoMagic](https://github.com/code-423n4/2024-03-taiko-findings/issues/261), also found by [Limbooo](https://github.com/code-423n4/2024-03-taiko-findings/issues/322), [imare](https://github.com/code-423n4/2024-03-taiko-findings/issues/308), and [t0x1c](https://github.com/code-423n4/2024-03-taiko-findings/issues/144)_

<https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoToken.sol#L34> <br><https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoToken.sol#L52>

The EssentialContract.sol contract is inherited by the TaikoToken contract. This essential contract contains two \_\_Essential_init() functions, one with an owner parameter only (see [here](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/EssentialContract.sol#L109)) and the other with owner and address manager parameters (see [here](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/EssentialContract.sol#L95)).

The issue with the current code is that it uses the [\_\_Essential_init()](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/EssentialContract.sol#L109) function with the owner parameter only. This would cause the [onlyFromOwnerOrNamed("snapshooter")](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoToken.sol#L52) modifier on the [snapshot](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoToken.sol#L52) function to not be able to resolve the snapshooter role since the address manager contract was never set during initialization, thus causing a revert.

Due to this:

1.  Snapshooter role is denied from taking snapshots.
2.  Timely snapshots for certain periods could have failed by the snapshooter since they would have required the owner to jump in by the time the issue was realized.
3.  Correct/Intended functionality of the protocol is affected i.e. the snapshooter role assigned to an address cannot ever perform its tasks validly.

### Proof of Concept

Here is the whole process:

1.  Snapshooter address calls the [snapshot()](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoToken.sol#L52) function. The [onlyFromOwnerOrNamed("snapshooter")](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoToken.sol#L52) modifier is encountered first.

```solidity
File: TaikoToken.sol
57:     function snapshot() public onlyFromOwnerOrNamed("snapshooter") {
58:         _snapshot();
59:     }
```

2.  In the second condition, the [modifier](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/EssentialContract.sol#L41) calls the [resolve()](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/AddressResolver.sol#L30) function with the "snapshooter" role as `_name` in order to check if the caller (msg.sender) is indeed the address approved by the owner.

```solidity
File: EssentialContract.sol
46:     modifier onlyFromOwnerOrNamed(bytes32 _name) {
47:         if (msg.sender != owner() && msg.sender != resolve(_name, true))
48:             revert RESOLVER_DENIED();
49:         _;
50:     }
```

3.  The [resolve()](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/AddressResolver.sol#L30) function is called which internally calls the function [\_resolve()](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/AddressResolver.sol#L72). In the function \_resolve(), the condition on Line 69 evaluates to true and we revert. This is because the addressManager address was never set during initialization using the [\_\_Essential_init()](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/EssentialContract.sol#L95) function with the owner and address manager parameters. Due to this, the snapshooter address is denied from performing it's allocated tasks.

```solidity
File: AddressResolver.sol
64:     function _resolve(
65:         uint64 _chainId,
66:         bytes32 _name,
67:         bool _allowZeroAddress
68:     ) private view returns (address payable addr_) {
69:         if (addressManager == address(0)) revert RESOLVER_INVALID_MANAGER();
70:
71:         addr_ = payable(
72:             IDefaultResolver(addressManager).getAddress(_chainId, _name)
73:         );
74:
75:         if (!_allowZeroAddress && addr_ == address(0)) {
76:             revert RESOLVER_ZERO_ADDR(_chainId, _name);
77:         }
78:     }
```

### Recommended Mitigation Steps

In the [init()](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoToken.sol#L25) function, consider using the [\_\_Essential_init()](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/EssentialContract.sol#L95) function with the owner and address manager parameters instead of the [\_\_Essential_init()](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/EssentialContract.sol#L109) function with the owner parameter. This would allow the snapshooter address to proceed with taking snapshots as expected.

**[dantaik (Taiko) confirmed and commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/261#issuecomment-2031678339):**

> This is a valid bug report. The bug is fixed by https://github.com/taikoxyz/taiko-mono/commit/c64ec193c95113a4c33692289e23e8d9fa864073

---

## [[M-08] Bridged tokens would be lost if sender and receiver are contracts that don't implement fallback/receive](https://github.com/code-423n4/2024-03-taiko-findings/issues/226)

_Submitted by [Shield](https://github.com/code-423n4/2024-03-taiko-findings/issues/226), also found by [Shield](https://github.com/code-423n4/2024-03-taiko-findings/issues/330)_

When a bridged token is received on the dest chain, `ERC20Vault.onMessageInvocation()` is being called.
`onMessageInvocation()` always calls `to.sendEther(msg.value)` even when the `msg.value` is zero.
`sendEther()` would attempt to call the contract with the value supplied and empty data. If the `to` address ia a contract that doesn't implement neither the fallback function nor receive then the entire transaction would revert.

The same issue occurs during recalling the message, if the sender is also a contract that doesn't implement neither a fallback nor receive then the recalling would fail as well.

### Impact

Funds would be lost, since the sending can't be finalized and recovering would revert as well.

While this might be considered a user error when sending a value that's greater than zero (they should've checked that the `to` address implements the receiver), this can't be said about the case where the value is zero - the user won't expect the vault to call the `to` contract with zero value.

### Proof of Concept

Add the following PoC to `test\tokenvault\ERC20Vault.t.sol`:

<details>
<summary>Coded PoC</summary>

```solidity
contract NoFallback{
    // other functions might be implemented here, but neither a fallback nor receive
}
```

<details>

```solidity
    function test_noFallback()
        public
    {
        vm.startPrank(Alice);

        vm.chainId(destChainId);

        erc20.mint(address(erc20Vault));

        uint256 amount = 0;
        address to = address(new NoFallback());

        uint256 erc20VaultBalanceBefore = erc20.balanceOf(address(erc20Vault));
        uint256 toBalanceBefore = erc20.balanceOf(to);

        destChainIdBridge.sendReceiveERC20ToERC20Vault(
            erc20ToCanonicalERC20(destChainId),
            Alice,
            to,
            amount,
            bytes32(0),
            address(erc20Vault),
            srcChainId,
            0
        );

        uint256 erc20VaultBalanceAfter = erc20.balanceOf(address(erc20Vault));
        assertEq(erc20VaultBalanceBefore - erc20VaultBalanceAfter, amount);

        uint256 toBalanceAfter = erc20.balanceOf(to);
        assertEq(toBalanceAfter - toBalanceBefore, amount);
    }

    function test_20Vault_onMessageRecalled_20() public {
        Alice = address(new NoFallback());
        erc20.mint(Alice);

        vm.startPrank(Alice);

        uint256 amount = 2 wei;
        erc20.approve(address(erc20Vault), amount);

        uint256 aliceBalanceBefore = erc20.balanceOf(Alice);
        uint256 erc20VaultBalanceBefore = erc20.balanceOf(address(erc20Vault));

        IBridge.Message memory _messageToSimulateFail = erc20Vault.sendToken(
            ERC20Vault.BridgeTransferOp(
                destChainId, address(0), Bob, address(erc20), amount, 1_000_000, 0, Bob, ""
            )
        );

        uint256 aliceBalanceAfter = erc20.balanceOf(Alice);
        uint256 erc20VaultBalanceAfter = erc20.balanceOf(address(erc20Vault));

        assertEq(aliceBalanceBefore - aliceBalanceAfter, amount);
        assertEq(erc20VaultBalanceAfter - erc20VaultBalanceBefore, amount);

        // No need to imitate that it is failed because we have a mock SignalService
        bridge.recallMessage(_messageToSimulateFail, bytes(""));

        uint256 aliceBalanceAfterRecall = erc20.balanceOf(Alice);
        uint256 erc20VaultBalanceAfterRecall = erc20.balanceOf(address(erc20Vault));

        // Release -> original balance
        assertEq(aliceBalanceAfterRecall, aliceBalanceBefore);
        assertEq(erc20VaultBalanceAfterRecall, erc20VaultBalanceBefore);
    }
```

</details>

Output:

```

Failing tests:
Encountered 1 failing test in test/tokenvault/ERC20Vault.t.sol:TestERC20Vault
[FAIL. Reason: ETH_TRANSFER_FAILED()] test_20Vault_receive_erc20_canonical_to_dest_chain_transfers_from_canonical_token() (gas: 201153)


Failing tests:
Encountered 1 failing test in test/tokenvault/ERC20Vault.t.sol:TestERC20Vault
[FAIL. Reason: ETH_TRANSFER_FAILED()] test_20Vault_onMessageRecalled_20()
```

</details>

### Recommended Mitigation Steps

- Don't call `sendEther()` when the value is zero
  - Or modify `sendEther()` to return when the value is zero
- Find a solution for cases when the value is non-zero
  - This one is a bit more complicated, one way might be to allow the sender to request the ERC20 token while giving up on the ETH

**[dantaik (Taiko) confirmed and commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/226#issuecomment-2079065682):**

> We have change the sendEther function such that if the amount is 0, there is no further action and the sendEther function simply returns.
>
> If if default and receive functions are both unimplemented on the destination chain for the to address, then the owner can fail the message with retryMessage({..., \_lastAttemp=true}); >or use failMessage(...) , then on the source chain, the owner can call recallMessage to get back his tokens.
>
> At the end of the day, the user must trust the dapp that use our Bridge to set the right message parameters.

---

## [[M-09] LibProposing:proposeBlock allows blocks with a zero parentMetaHash to be proposed after the genesis block and avoid parent block verification](https://github.com/code-423n4/2024-03-taiko-findings/issues/218)

_Submitted by [joaovwfreire](https://github.com/code-423n4/2024-03-taiko-findings/issues/218)_

<https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibProposing.sol#L108>

<https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibProposing.sol#L213>

<https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibProving.sol#L121>

The proposeBlock at the LibProposing library has the following check to ensure the proposed block has the correct parentMetaHash set:

```solidity
function proposeBlock(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        IAddressResolver _resolver,
        bytes calldata _data,
        bytes calldata _txList
    )
        internal
        returns (TaikoData.BlockMetadata memory meta_, TaikoData.EthDeposit[] memory deposits_)
    {
    ...
if (params.parentMetaHash != 0 && parentMetaHash != params.parentMetaHash) {
            revert L1_UNEXPECTED_PARENT();
        }
    ...
    }
```

However, there are no sanity checks to ensure params.parentMetaHash is not zero outside of the genesis block.

### Impact

Malicious proposers can propose new blocks without any parentMetaHash.
This can induce a maliciously-generated block to be artificially contested as the final block relies on data held by the meta\_ variable.
Snippet 1:

```solidity
TaikoData.Block memory blk = TaikoData.Block({
            metaHash: keccak256(abi.encode(meta_)),
...
})
```

This also generates issues for independent provers, as they may not utilize the proposed block's data to attempt to prove it and utilize the correct parentMetaHash, which will make the LibProving:proveBlock call revert with an L1_BLOCK_MISTATCH error:

```solidity
function proveBlock
	...
	if (blk.blockId != _meta.id || blk.metaHash != keccak256(abi.encode(_meta))) {
            revert L1_BLOCK_MISMATCH();
        }
	...
}
```

Also, according to the documentation, [ If the parent block hash is incorrect, the winning transition won't be used for block verification, and the prover will forfeit their validity bond entirely.](https://taiko.mirror.xyz/Z4I5ZhreGkyfdaL5I9P0Rj0DNX4zaWFmcws-0CVMJ2A#:~:text=If%20the%20parent%20block%20hash%20is%20incorrect%2C%20the%20winning%20transition%20won%27t%20be%20used%20for%20block%20verification%2C%20and%20the%20prover%20will%20forfeit%20their%20validity%20bond%20entirely) If a maliciously proposed block with zero parent block hash is contested and a higher-tier prover ends up proving the proposed block, then he/she loses its own validity bond.

### Proof of Concept

The test suite contains the TaikoL1TestBase:proposeBlock that creates new block proposals with a zero parentMetaHash. This is called multiple times at tests like test_L1_verifying_multiple_blocks_once and test_L1_multiple_blocks_in_one_L1_block at the TaikoL1.t.sol test file, demonstrating the lack of reversion if the parentMetaHash is not zero outside of the genesis block.

### Recommended Mitigation Steps

Make sure to check the parentMetaHash value is not zero if it isn't at the genesis block, otherwise users are going to be able to wrongly induce contestations.

**[adaki2004 (Taiko) confirmed](https://github.com/code-423n4/2024-03-taiko-findings/issues/218#issuecomment-2033993978)**

---

## [[M-10] The decision to return the liveness bond depends solely on the last guardian](https://github.com/code-423n4/2024-03-taiko-findings/issues/205)

_Submitted by [alexfilippov314](https://github.com/code-423n4/2024-03-taiko-findings/issues/205), also found by [t0x1c](https://github.com/code-423n4/2024-03-taiko-findings/issues/248)_

<https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/GuardianProver.sol#L46>

<https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L192>

### Vulnerability details

The `GuardianProver` contract is a multisig that might contest any proof in some exceptional cases (bugs in the prover or verifier). To contest a proof, a predefined number of guardians should approve a hash of the message that includes `_meta` and `_tran`.

```solidity
function approve(
    TaikoData.BlockMetadata calldata _meta,
    TaikoData.Transition calldata _tran,
    TaikoData.TierProof calldata _proof
)
    external
    whenNotPaused
    nonReentrant
    returns (bool approved_)
{
    if (_proof.tier != LibTiers.TIER_GUARDIAN) revert INVALID_PROOF();

    bytes32 hash = keccak256(abi.encode(_meta, _tran));
    approved_ = approve(_meta.id, hash);

    if (approved_) {
        deleteApproval(hash);
        ITaikoL1(resolve("taiko", false)).proveBlock(_meta.id, abi.encode(_meta, _tran, _proof));
    }

    emit GuardianApproval(msg.sender, _meta.id, _tran.blockHash, approved_);
}
```

The issue arises from the fact that the approved message doesn't include the `_proof`. It means that the last approving guardian can provide any desired value in the `_proof`. The data from the `_proof` is used to determine whether it is necessary to return the liveness bond to the assigned prover or not:

```solidity
if (isTopTier) {
    // A special return value from the top tier prover can signal this
    // contract to return all liveness bond.
    bool returnLivenessBond = blk.livenessBond > 0 && _proof.data.length == 32
        && bytes32(_proof.data) == RETURN_LIVENESS_BOND;

    if (returnLivenessBond) {
        tko.transfer(blk.assignedProver, blk.livenessBond);
        blk.livenessBond = 0;
    }
}
```

As a result, the last guardian can solely decide whether to return the liveness bond to the assigned prover or not.

### Impact

The decision to return the liveness bond depends solely on the last guardian.

### Recommended Mitigation Steps

Consider including the `_proof` in the approved message.

```solidity
bytes32 hash = keccak256(abi.encode(_meta, _tran, _proof));
```

**[dantaik (Taiko) confirmed and commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/205#issuecomment-2079069856):**

> Now guardian provers must also agree on whether liveness bond should be returned bytes32(\_proof.data) == LibStrings.H_RETURN_LIVENESS_BOND, so the hash they sign is now:
>
> bytes32 hash = keccak256(abi.encode(\_meta, \_tran, \_proof.data));
>
> rather than the previous code:
>
> bytes32 hash = keccak256(abi.encode(\_meta, \_tran));

---

## [[M-11] Proposers would choose to avoid higher tier by exploiting non-randomness of parameter used in getMinTier()](https://github.com/code-423n4/2024-03-taiko-findings/issues/172)

_Submitted by [t0x1c](https://github.com/code-423n4/2024-03-taiko-findings/issues/172), also found by [Mahi_Vasisth](https://github.com/code-423n4/2024-03-taiko-findings/issues/54)_

The issue exists for both `MainnetTierProvider.sol` and `TestnetTierProvider.sol`. For this report, we shall concentrate only on describing it via `MainnetTierProvider.sol`.

The proving tier is chosen by the [getMinTier()](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/tiers/MainnetTierProvider.sol#L66-L70) function which accepts a `_rand` param.

```js
  File: contracts/L1/tiers/MainnetTierProvider.sol

  66:               function getMinTier(uint256 _rand) public pure override returns (uint16) {
  67:                   // 0.1% require SGX + ZKVM; all others require SGX
  68: @--->             if (_rand % 1000 == 0) return LibTiers.TIER_SGX_ZKVM;
  69:                   else return LibTiers.TIER_SGX;
  70:               }
```

If `_rand % 1000 == 0`, a costlier tier `TIER_SGX_ZKVM` is used instead of the cheaper `TIER_SGX`. The `_rand` param is passed in the form of `meta_.difficulty` [which is calculated inside](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibProposing.sol#L199-L209) `proposeBlock()`:

```js
  File: contracts/L1/libs/LibProposing.sol

  199:                  // Following the Merge, the L1 mixHash incorporates the
  200:                  // prevrandao value from the beacon chain. Given the possibility
  201:                  // of multiple Taiko blocks being proposed within a single
  202:                  // Ethereum block, we choose to introduce a salt to this random
  203:                  // number as the L2 mixHash.
  204: @--->            meta_.difficulty = keccak256(abi.encodePacked(block.prevrandao, b.numBlocks, block.number));
  205:
  206:                  // Use the difficulty as a random number
  207:                  meta_.minTier = ITierProvider(_resolver.resolve("tier_provider", false)).getMinTier(
  208: @--->                uint256(meta_.difficulty)
  209:                  );
```

As can be seen, all the parameters used in L204 to calculate `meta_.difficulty` can be known in advance and hence a proposer can choose not to propose when `meta_.difficulty` modulus 1000 equals zero, because in such cases it will cost him more to afford the proof (sgx + zk proof in this case).

### Impact

Since the proposer will now wait for the next or any future block to call `proposeBlock()` instead of the current costlier one, **transactions will now take longer to finalilze**.

If `_rand` were truly random, it would have been an even playing field in all situations as the proposer wouldn't be able to pick & choose since he won't know in advance which tier he might get. We would then truly have:

```js
  67:                   // 0.1% require SGX + ZKVM; all others require SGX
```

### Recommended Mitigation Steps

Consider using VRF like solutions to make `_rand` truly random.

**[dantaik (Taiko) acknowledged and commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/172#issuecomment-2032346577):**

> This is a very well known issue.
>
> Using VRF creates a third party dependency which may be a bigger risk for a Based rollup. We'll monitor how this plays out and mitigate the issue later.

**[adaki2004 (Taiko) commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/172#issuecomment-2034096641):**

> Eventually we will have only 1 (1 "aggregated ZK multiproof") proof tier, which will be the default/min too. (Maybe keeping guardian for a while to be as a failsafe, but that one also cannot be "picked" with thispseudoe random calculation).
> Also Taiko foundation will run a proposer node, so in case noone is willing to propose to avoid fees, we will, regardless of cost - at least until we reach the 1 tier maturity.

**[genesiscrew (Warden) commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/172#issuecomment-2048545898):**

> Considering this report and the responses from the sponsors, I am unable to see how this would impact the function of the protocol in such a way that would deem it a medium risk. I personally think this is informational. The report states proving will take longer because it assumes all proposers will want to avoid paying fees because they can predict the block difficulty. I find that a bit of a stretch.

**[adaki2004 (Taiko) commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/172#issuecomment-2049215839):**

> Not the proving but the liveness (proposing) would take longer as provers would deny to grant signatures to prove blocks - which's evaluation i happening during `proposeBlock`.
>
> But at least +2 years post mainnet taiko foundation is commited to `proposeBlock` every X time intervals (even if not breaking even) to keep the liveness and get over this.
>
> And as stated, by the time hopefully this minTier() will vanish in that time - hopefully even in months after launch (not years) when ZK is cheap enough. So for now we would say it is a known issue, we are aware of.

**[t0x1c (Warden) commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/172#issuecomment-2051225141):**

> Thank you for the inputs. From what I see, this is being acknowledged by the sponsor as a valid issue which is known to the team.
> Also important to note that it wasn't mentioned in the list of C4 "known issues" section on the audit page, so should qualify as a Medium.

**[adaki2004 (Taiko) commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/172#issuecomment-2051231358):**

> Can accept medium.

---

## [[M-12] Invocation delays are not honoured when protocol unpauses](https://github.com/code-423n4/2024-03-taiko-findings/issues/170)

_Submitted by [t0x1c](https://github.com/code-423n4/2024-03-taiko-findings/issues/170)_

<https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/common/EssentialContract.sol#L78>

<https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/bridge/Bridge.sol#L258>

**_Context:_** The protocol has `pause()` and [unpause()](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/common/EssentialContract.sol#L78) functions inside `EssentialContract.sol` which are tracked throughout the protocol via the modifiers [whenPaused](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/common/EssentialContract.sol#L53) and [whenNotPaused](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/common/EssentialContract.sol#L58).

**_Issue:_** Various delays and time lapses throughout the protocol ignore the effect of such pauses. The example in focus being that of `processMessage()` which does not take into account the pause duration while [checking invocationDelay and invocationExtraDelay](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/bridge/Bridge.sol#L233-L258). One impact of this is that it allows a non-preferred executor to front run a preferredExecutor, after an unpause.

```js
  File: contracts/bridge/Bridge.sol

  233: @--->            (uint256 invocationDelay, uint256 invocationExtraDelay) = getInvocationDelays();
  234:
  235:                  if (!isMessageProven) {
  236:                      if (!_proveSignalReceived(signalService, msgHash, _message.srcChainId, _proof)) {
  237:                          revert B_NOT_RECEIVED();
  238:                      }
  239:
  240:                      receivedAt = uint64(block.timestamp);
  241:
  242:                      if (invocationDelay != 0) {
  243:                          proofReceipt[msgHash] = ProofReceipt({
  244:                              receivedAt: receivedAt,
  245:                              preferredExecutor: _message.gasLimit == 0 ? _message.destOwner : msg.sender
  246:                          });
  247:                      }
  248:                  }
  249:
  250:                  if (invocationDelay != 0 && msg.sender != proofReceipt[msgHash].preferredExecutor) {
  251:                      // If msg.sender is not the one that proved the message, then there
  252:                      // is an extra delay.
  253:                      unchecked {
  254:                          invocationDelay += invocationExtraDelay;
  255:                      }
  256:                  }
  257:
  258: @--->            if (block.timestamp >= invocationDelay + receivedAt) {
```

### Description & Impact

Consider the following flow:

- Assumption: `invocationDelay = 60 minutes` and `invocationExtraDelay = 30 minutes`.
- A message is sent.
- First call to `processMessage()` occurred at `t` where it was proven by Bob i.e. its `receivedAt = t`. Bob is marked as the `preferredExecutor`.
- Preferred executor should be able to call `processMessage()` at `t+60` while a non-preferred executor should be able to call it only at `t+90` due to the code logic on [L250](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/bridge/Bridge.sol#L250).
- At `t+55`, protocol is paused.
- At `t+100`, protocol is unpaused.
- **_Impact:_** The 30-minute time window advantage which the preferred executor had over the non-preferred one is now lost to him. [L258](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/bridge/Bridge.sol#L258) now considers the invocation delays to have passed and hence the non-preferred executor can immediately call `processMessage()` by front-running Bob and hence pocketing the reward of `message.fee` on [L98](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/bridge/Bridge.sol#L298).

```js
  File: contracts/bridge/Bridge.sol

  293:                      // Refund the processing fee
  294:                      if (msg.sender == refundTo) {
  295:                          refundTo.sendEther(_message.fee + refundAmount);
  296:                      } else {
  297:                          // If sender is another address, reward it and refund the rest
  298: @--->                    msg.sender.sendEther(_message.fee);
  299:                          refundTo.sendEther(refundAmount);
  300:                      }
```

Similar behaviour where the paused time is ignored by the protocol can be witnessed in:

- [recallMessage()](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/bridge/Bridge.sol#L187-L189) which similarly uses `invocationDelay`. However, no `invocationExtraDelay` is used there.
- [TimelockTokenPool.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/team/TimelockTokenPool.sol) for:

```js
        // If non-zero, indicates the start time for the recipient to receive
        // tokens, subject to an unlocking schedule.
        uint64 grantStart;
        // If non-zero, indicates the time after which the token to be received
        // will be actually non-zero
        uint64 grantCliff;
        // If non-zero, specifies the total seconds required for the recipient
        // to fully own all granted tokens.
        uint32 grantPeriod;
        // If non-zero, indicates the start time for the recipient to unlock
        // tokens.
        uint64 unlockStart;
        // If non-zero, indicates the time after which the unlock will be
        // actually non-zero
        uint64 unlockCliff;
        // If non-zero, specifies the total seconds required for the recipient
        // to fully unlock all owned tokens.
        uint32 unlockPeriod;
```

- [TaikoData.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/TaikoData.sol) for:

```js
        // The max period in seconds that a blob can be reused for DA.
        uint24 blobExpiry;
```

### Recommended Mitigation Steps

Introduce a new variable which keeps track of how much time has already been spent in the valid wait window before a pause happened. Also track the last unpause timestamp (similar to how it is done in [pauseProving()](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/TaikoL1.sol#L111) and [unpausing](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/TaikoL1.sol#L124) mechanisms).
Also refer my other recommendation under the report titled: _"Incorrect calculations for cooldownWindow and provingWindow could cause a state transition to spend more than expected time in these windows"_. That will help fix the issue without any further leaks.

**[dantaik (Taiko) confirmed and commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/170#issuecomment-2032338122):**

> This is a valid bug report, fixing in https://github.com/taikoxyz/taiko-mono/pull/16612
>
> TimelockTokenPool.sol will not have a similar fix as the risk is very managable. Blob caching/sharing is disabled, so no fix for it as well.

---

## [[M-13] Taiko SGX Attestation - Improper validation in certchain decoding](https://github.com/code-423n4/2024-03-taiko-findings/issues/168)

_Submitted by [zzebra83](https://github.com/code-423n4/2024-03-taiko-findings/issues/168)_

<https://github.com/code-423n4/2024-03-taiko/blob/0d081a40e0b9637eddf8e760fabbecc250f23599/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L135>

<https://github.com/code-423n4/2024-03-taiko/blob/0d081a40e0b9637eddf8e760fabbecc250f23599/packages/protocol/contracts/verifiers/SgxVerifier.sol#L115-L136>

As part of of its ZK proof setup, Taiko leverages SGX provers. it also enables remote SGX attestation and this is possible via leveraging code from Automata, which provides a modular attestation layer extending machine-level trust to Ethereum via the AutomataDcapV3Attestation repo, which is in scope of this audit.

Anyone with SGX hardware can register their instance to be an SGX prover in the Taiko Network via calling the registerInstance function in SgxVerifier.sol. This is why attestation is critical to prove the reliability and trustworthiness of the SGX prover.

The attestation process of SGX provers is a multi fold process, and starts with calling the verifyParsedQuote function in AutomataDcapV3Attestation.sol. One of the steps involves decoding the certchain provided by the SGX prover, as seen below:

            // Step 4: Parse Quote CertChain
        IPEMCertChainLib.ECSha256Certificate[] memory parsedQuoteCerts;
        TCBInfoStruct.TCBInfo memory fetchedTcbInfo;
        {
            // 536k gas
            parsedQuoteCerts = new IPEMCertChainLib.ECSha256Certificate[](3);
            for (uint256 i; i < 3; ++i) {
                bool isPckCert = i == 0; // additional parsing for PCKCert
                bool certDecodedSuccessfully;
                // todo! move decodeCert offchain
                (certDecodedSuccessfully, parsedQuoteCerts[i]) = pemCertLib.decodeCert(
                    authDataV3.certification.decodedCertDataArray[i], isPckCert
                );
                if (!certDecodedSuccessfully) {
                    return (false, retData);
                }
            }
        }

after this step is executed, a number of other steps are done including:

Step 5: basic PCK and TCB check
Step 6: Verify TCB Level
Step 7: Verify cert chain for PCK
Step 8: Verify the local attestation sig and qe report sig

The decoding of the certchain happens through the EMCertChainLib lib, and this involves a number of steps, one of which is to validate the decoded notBefore and notAfter tags of the certificate:

            {
            uint256 notBeforePtr = der.firstChildOf(tbsPtr);
            uint256 notAfterPtr = der.nextSiblingOf(notBeforePtr);
            bytes1 notBeforeTag = der[notBeforePtr.ixs()];
            bytes1 notAfterTag = der[notAfterPtr.ixs()];
            if (
                (notBeforeTag != 0x17 && notBeforeTag == 0x18)
                    || (notAfterTag != 0x17 && notAfterTag != 0x18)
            ) {
                return (false, cert);
            }
            cert.notBefore = X509DateUtils.toTimestamp(der.bytesAt(notBeforePtr));
            cert.notAfter = X509DateUtils.toTimestamp(der.bytesAt(notAfterPtr));
        }

These fields determine the time format, whether the notBeforePtr and notAfterPtr are in UTC or generalized time, and are used to ensure consistency in timestamps used to determine the validity period of the certificate.

However the validation can fail because the logic above is faulty, as it will allow the attestor to pass in any value for the notBefore tag, indeeed the condition of:

    (notBeforeTag != 0x17 && notBeforeTag == 0x18)

will allow the attestor to pass in any beforetag because the condition will always be false.

Consider if we pass an invalid tag of 0x10:

1.  notBeforeTag != 0x17 is True.
2.  notBeforeTag == 0x18 is False.
3.  full condition is False.

I believe the original intention was to ensure the beforeTag is strictly 0x17 or 0x18, just as with the afterTag. Because of this oversight, a malicious attestor could pass in any notBefore Tag as part of their certificate.

This issue requires attention given the significance of the attestation process of SGX provers within Taiko's ZK setup. The whole point of attestation is to prove the SGX provers are secure, untampered, and trustworthy, and improper validation related to certificate validity periods can have unforeseen consequences.

### Recommended Mitigation Steps

Update the condition as below:

                if (
                (notBeforeTag != 0x17 && notBeforeTag != 0x18)
                    || (notAfterTag != 0x17 && notAfterTag != 0x18)
            ) {
                return (false, cert);

**[smtmfft (Taiko) confirmed and commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/168#issuecomment-2033492460):**

> I think this is a valid catch, already submitted a fix.

---

## [[M-14] Malicious caller of `processMessage()` can pocket the fee while forcing `excessivelySafeCall()` to fail](https://github.com/code-423n4/2024-03-taiko-findings/issues/97)

_Submitted by [t0x1c](https://github.com/code-423n4/2024-03-taiko-findings/issues/97), also found by [Shield](https://github.com/code-423n4/2024-03-taiko-findings/issues/223) and [ladboy233](https://github.com/code-423n4/2024-03-taiko-findings/issues/180)_

The logic inside function `processMessage()` [provides a reward to the msg.sender](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/bridge/Bridge.sol#L298) if they are not the `refundTo` address. However this reward or `_message.fee` is awarded even if the `_invokeMessageCall()` on [L282](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/bridge/Bridge.sol#L282) fails and the message goes into a `RETRIABLE` state. In the retriable state, it has to be called by someone again and the current `msg.sender` has no obligation to be the one to call it.

This logic can be gamed by a malicious user using the **63/64th rule specified in** [EIP-150](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-150.md).

```js
  File: contracts/bridge/Bridge.sol

  278:                          // Use the specified message gas limit if called by the owner, else
  279:                          // use remaining gas
  280: @--->                    uint256 gasLimit = msg.sender == _message.destOwner ? gasleft() : _message.gasLimit;
  281:
  282: @--->                    if (_invokeMessageCall(_message, msgHash, gasLimit)) {
  283:                              _updateMessageStatus(msgHash, Status.DONE);
  284:                          } else {
  285: @--->                        _updateMessageStatus(msgHash, Status.RETRIABLE);
  286:                          }
  287:                      }
  288:
  289:                      // Determine the refund recipient
  290:                      address refundTo =
  291:                          _message.refundTo == address(0) ? _message.destOwner : _message.refundTo;
  292:
  293:                      // Refund the processing fee
  294:                      if (msg.sender == refundTo) {
  295:                          refundTo.sendEther(_message.fee + refundAmount);
  296:                      } else {
  297:                          // If sender is another address, reward it and refund the rest
  298: @--->                    msg.sender.sendEther(_message.fee);
  299:                          refundTo.sendEther(refundAmount);
  300:                      }
```

### Description

The `_invokeMessageCall()` on [L282](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/bridge/Bridge.sol#L282) internally calls `excessivelySafeCall()` on [L497](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/bridge/Bridge.sol#L497). When `excessivelySafeCall()` makes an external call, only 63/64th of the gas is used by it. Thus the following scenario can happen:

- Malicious user notices that [L285-L307](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/bridge/Bridge.sol#L285-L307) uses approx 165_000 gas.

- He also notices that [L226-L280](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/bridge/Bridge.sol#L226-L280) uses approx 94_000 gas.

- He calculates that he must provide approximately a minimum of `94000 + (64 * 165000) = 10_654_000` gas so that the function execution does not revert anywhere.

- Meanwhile, a message owner has message which has a `_message.gasLimit` of 11_000_000. This is so because the `receive()` function of the contract receiving ether is expected to consume gas in this range due to its internal calls & transactions. The owner expects at least 10_800_000 of gas would be used up and hence has provided some extra buffer.

- Note that **any message** that has a processing requirement of greater than `63 * 165000 = 10_395_000` gas can now become a target of the malicious user.

- Malicious user now calls `processMessage()` with a specific gas figure. Let's use an example figure of `{gas: 10_897_060}`. This means only `63/64 * (10897060 - 94000) = 10_634_262` is forwarded to `excessivelySafeCall()` and `1/64 * (10897060 - 94000) = 168_797` will be kept back which is enough for executing the remaining lines of code L285-L307. Note that since `(10897060 - 94000) = 10_803_060` which is less than the message owner's provided `_message.gasLimit` of `11_000_000`, what actually gets considered is only `10_803_060`.

- The external call reverts inside `receive()` due to out of gas error (since 10_634_262 < 10_800_000) and hence `_success` is set to `false` on [L44](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/thirdparty/nomad-xyz/ExcessivelySafeCall.sol#L44).

- The remaining L285-L307 are executed and the malicious user receives his reward.

- The message goes into `RETRIABLE` state now and someone will need to call `retryMessage()` later on.

A different bug report titled **_"No incentive for message non-owners to retryMessage()"_** has also been raised which highlights the incentivization scheme of `retryMessage()`.

### Impact

- Protocol can be gamed by a user to gain rewards while additionally saving money by providing the least possible gas.

- There is no incentive for any external user now to ever provide more than `{gas: 10_897_060}` (approx figure).

### Proof of Concept

Apply the following patch to add the test inside `protocol/test/bridge/Bridge.t.sol` and run via `forge test -vv --mt test_t0x1c_gasManipulation` to see it pass:

<details>

```diff
diff --git a/packages/protocol/test/bridge/Bridge.t.sol b/packages/protocol/test/bridge/Bridge.t.sol
index 6b7dca6..ce77ce2 100644
--- a/packages/protocol/test/bridge/Bridge.t.sol
+++ b/packages/protocol/test/bridge/Bridge.t.sol
@@ -1,11 +1,19 @@
 // SPDX-License-Identifier: MIT
 pragma solidity 0.8.24;

 import "../TaikoTest.sol";

+contract ToContract {
+    receive() external payable {
+        uint someVar;
+        for(uint loop; loop < 86_990; ++loop)
+            someVar += 1e18;
+    }
+}
+
 // A contract which is not our ErcXXXTokenVault
 // Which in such case, the sent funds are still recoverable, but not via the
 // onMessageRecall() but Bridge will send it back
 contract UntrustedSendMessageRelayer {
     function sendMessage(
         address bridge,
@@ -115,12 +123,71 @@ contract BridgeTest is TaikoTest {
         register(address(addressManager), "bridge", address(destChainBridge), destChainId);

         register(address(addressManager), "taiko", address(uint160(123)), destChainId);
         vm.stopPrank();
     }

+
+    function test_t0x1c_gasManipulation() public {
+        //**************** SETUP **********************
+        ToContract toContract = new ToContract();
+        IBridge.Message memory message = IBridge.Message({
+            id: 0,
+            from: address(bridge),
+            srcChainId: uint64(block.chainid),
+            destChainId: destChainId,
+            srcOwner: Alice,
+            destOwner: Alice,
+            to: address(toContract),
+            refundTo: Alice,
+            value: 1000,
+            fee: 1000,
+            gasLimit: 11_000_000,
+            data: "",
+            memo: ""
+        });
+        // Mocking proof - but obviously it needs to be created in prod
+        // corresponding to the message
+        bytes memory proof = hex"00";
+
+        bytes32 msgHash = destChainBridge.hashMessage(message);
+
+        vm.chainId(destChainId);
+        skip(13 hours);
+        assertEq(destChainBridge.messageStatus(msgHash) == IBridge.Status.NEW, true);
+        uint256 carolInitialBalance = Carol.balance;
+
+        uint256 snapshot = vm.snapshot();
+        //**************** SETUP ENDS **********************
+
+
+
+        //**************** NORMAL USER **********************
+        console.log("\n**************** Normal User ****************");
+        vm.prank(Carol, Carol);
+        destChainBridge.processMessage(message, proof);
+
+        assertEq(destChainBridge.messageStatus(msgHash) == IBridge.Status.DONE, true);
+        assertEq(Carol.balance, carolInitialBalance + 1000, "Carol balance mismatch");
+        if (destChainBridge.messageStatus(msgHash) == IBridge.Status.DONE)
+            console.log("message status = DONE");
+
+
+
+        //**************** MALICIOUS USER **********************
+        vm.revertTo(snapshot);
+        console.log("\n**************** Malicious User ****************");
+        vm.prank(Carol, Carol);
+        destChainBridge.processMessage{gas: 10_897_060}(message, proof); // @audit-info : specify gas to force failure of excessively safe external call
+
+        assertEq(destChainBridge.messageStatus(msgHash) == IBridge.Status.RETRIABLE, true); // @audit : message now in RETRIABLE state. Carol receives the fee.
+        assertEq(Carol.balance, carolInitialBalance + 1000, "Carol balance mismatched");
+        if (destChainBridge.messageStatus(msgHash) == IBridge.Status.RETRIABLE)
+            console.log("message status = RETRIABLE");
+    }
+
     function test_Bridge_send_ether_to_to_with_value() public {
         IBridge.Message memory message = IBridge.Message({
             id: 0,
             from: address(bridge),
             srcChainId: uint64(block.chainid),
             destChainId: destChainId,
```

</details>

### Tools Used

Foundry

### Recommended Mitigation Steps

Reward the `msg.sender` (provided it's a _non-refundTo_ address) with `_message.fee` only if `_invokeMessageCall()` returns `true`. Additionally, it is advisable to release this withheld reward after a successful `retryMessage()` to that function's caller.

**[dantaik (Taiko) confirmed and commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/97#issuecomment-2032446424):**

> Fixed in https://github.com/taikoxyz/taiko-mono/pull/16613
>
> I don't think paying fees only when `_invokeMessageCall` returns true is a good idea as this will require the relayer to simulate all transactions without guaranteed reward.

---

# Low Risk and Non-Critical Issues

For this audit, 33 reports were submitted by wardens detailing low risk and non-critical issues. The [report highlighted below](https://github.com/code-423n4/2024-03-taiko-findings/issues/335) by **MrPotatoMagic** received the top score from the judge.

_The following wardens also submitted reports: [Shield](https://github.com/code-423n4/2024-03-taiko-findings/issues/255), [Sathish9098](https://github.com/code-423n4/2024-03-taiko-findings/issues/120), [rjs](https://github.com/code-423n4/2024-03-taiko-findings/issues/372), [zabihullahazadzoi](https://github.com/code-423n4/2024-03-taiko-findings/issues/366), [JCK](https://github.com/code-423n4/2024-03-taiko-findings/issues/357), [cheatc0d3](https://github.com/code-423n4/2024-03-taiko-findings/issues/355), [DadeKuma](https://github.com/code-423n4/2024-03-taiko-findings/issues/343), [0x11singh99](https://github.com/code-423n4/2024-03-taiko-findings/issues/338), [monrel](https://github.com/code-423n4/2024-03-taiko-findings/issues/329), [slvDev](https://github.com/code-423n4/2024-03-taiko-findings/issues/326), [grearlake](https://github.com/code-423n4/2024-03-taiko-findings/issues/318), [Masamune](https://github.com/code-423n4/2024-03-taiko-findings/issues/311), [imare](https://github.com/code-423n4/2024-03-taiko-findings/issues/304), [josephdara](https://github.com/code-423n4/2024-03-taiko-findings/issues/300), [t0x1c](https://github.com/code-423n4/2024-03-taiko-findings/issues/265), [sxima](https://github.com/code-423n4/2024-03-taiko-findings/issues/235), [joaovwfreire](https://github.com/code-423n4/2024-03-taiko-findings/issues/217), [alexfilippov314](https://github.com/code-423n4/2024-03-taiko-findings/issues/209), [pfapostol](https://github.com/code-423n4/2024-03-taiko-findings/issues/195), [ladboy233](https://github.com/code-423n4/2024-03-taiko-findings/issues/188), [hihen](https://github.com/code-423n4/2024-03-taiko-findings/issues/176), [Pechenite](https://github.com/code-423n4/2024-03-taiko-findings/issues/160), [clara](https://github.com/code-423n4/2024-03-taiko-findings/issues/151), [pa6kuda](https://github.com/code-423n4/2024-03-taiko-findings/issues/148), [albahaca](https://github.com/code-423n4/2024-03-taiko-findings/issues/146), [foxb868](https://github.com/code-423n4/2024-03-taiko-findings/issues/140), [Myd](https://github.com/code-423n4/2024-03-taiko-findings/issues/125), [t4sk](https://github.com/code-423n4/2024-03-taiko-findings/issues/49), [Fassi_Security](https://github.com/code-423n4/2024-03-taiko-findings/issues/28), [oualidpro](https://github.com/code-423n4/2024-03-taiko-findings/issues/20), [Kalyan-Singh](https://github.com/code-423n4/2024-03-taiko-findings/issues/15), and [n1punp](https://github.com/code-423n4/2024-03-taiko-findings/issues/11)._

## [L-01] Consider initializing ContextUpgradeable contract by calling \_\_Context_init() in TaikoToken.sol

[Link](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoToken.sol#L25)

ContextUpgradeable is not initialized in TaikoToken.sol contract. This contract is used in ERC20PermitUpgradeable which is used in ERC20VotesUpgradeable. But neither contract initializes this Context contract when the contracts themselves are intialized.

In TaikoToken.sol [here](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoToken.sol#L25), we can see that the below \_\_Context_init() function is not called.

```solidity
File: ContextUpgradeable.sol
18:     function __Context_init() internal onlyInitializing {
19:     }
20:
21:     function __Context_init_unchained() internal onlyInitializing {
22:     }
```

## [L-02] \_\_ERC1155Receiver_init() not initialized in ERC1155Vault

[Link](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L29)

Consider initializing these functions in an init() function in the ERC1155Vault contract.

```solidity
File: ERC1155ReceiverUpgradeable.sol
14:     function __ERC1155Receiver_init() internal onlyInitializing {
15:     }
16:
17:     function __ERC1155Receiver_init_unchained() internal onlyInitializing {
18:     }
```

## [L-03] If amountUnlocked in TimelockTokenPool is less than 1e18, rounding down occurs

[Link](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L197)

If amountUnlocked is less than 1e18, round down occurs. This is not a problem since grants will usually be dealing with way higher values and thus higher unlocking. But this would be a problem for team members or advisors getting maybe 10 taiko or less (in case price of taiko is high). So the more frequent the withdrawing there might be chances of losing tokens due to round down.

```solidity
File: TimelockTokenPool.sol
198:         uint128 _amountUnlocked = amountUnlocked / 1e18; // divide first
```

## [L-04] sendSignal() calls can be spammed by attacker to relayer

[Link](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L63)

Since the function is external, an attacker can continuously spam signals to the offchain relayer which is always listening to signals. This would be more cost efficient on Taiko where fees are cheap.

The signals could also be used to mess with the relayer service i.e. by sending a the same signal early by frontrunning a user's bytes32 signal \_parameter.

```solidity
File: SignalService.sol
68:     function sendSignal(bytes32 _signal) external returns (bytes32) {
69:         return _sendSignal(msg.sender, _signal, _signal);
70:     }
```

## [L-05] Add "Zero if owner will process themself" comment to gasLimit instead of fee

In the current code, the preferredExecutor for executing bridged transactions is determined by whether the gasLimit is 0 or not and not the fee.

```solidity
File: IBridge.sol
38:         // Processing fee for the relayer. Zero if owner will process themself.
39:         uint256 fee;
40:         // gasLimit to invoke on the destination chain.
41:         uint256 gasLimit;
```

## [L-06] Bridge integration issues with swapping protocols

Cross-chain swapping could not occur on chains having long invocation delays since deadline of the swap might expire and become outdated. Consider having custom delays for dapps looking to use bridge.

```solidity
File: Bridge.sol
459:     /// the transactor is not the preferredExecutor who proved this message.
460:     function getInvocationDelays()
461:         public
462:         view
463:         virtual
464:         returns (uint256 invocationDelay_, uint256 invocationExtraDelay_)
465:     {
466:         if (
467:             block.chainid == 1 // Ethereum mainnet
468:         ) {
469:             // For Taiko mainnet
470:             // 384 seconds = 6.4 minutes = one ethereum epoch
471:             return (1 hours, 384 seconds);
472:         } else if (
473:             block.chainid == 2 || // Ropsten
474:             block.chainid == 4 || // Rinkeby
475:             block.chainid == 5 || // Goerli
476:             block.chainid == 42 || // Kovan
477:             block.chainid == 17_000 || // Holesky
478:             block.chainid == 11_155_111 // Sepolia
479:         ) {
480:             // For all Taiko public testnets
481:             return (30 minutes, 384 seconds);
482:         } else if (block.chainid >= 32_300 && block.chainid <= 32_400) {
483:             // For all Taiko internal devnets
484:             return (5 minutes, 384 seconds);
485:         } else {
486:             // This is a Taiko L2 chain where no deleys are applied.
487:             return (0, 0);
488:         }
489:     }
```

## [L-07] sendMessage() does not check if STATUS is equal to NEW

[Link](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L115)

Adding a sanity check would be good to avoid being able to call message that is not in the STATUS = NEW state. This would ensure retriable, recalls and failed txns cannot be repeated again.

```solidity
File: Bridge.sol
119:     function sendMessage(
120:         Message calldata _message
121:     )
122:         external
123:         payable
124:         override
125:         nonReentrant
126:         whenNotPaused
127:         returns (bytes32 msgHash_, Message memory message_)
128:     {
129:         // Ensure the message owner is not null.
130:         if (
131:             _message.srcOwner == address(0) || _message.destOwner == address(0)
132:         ) {
133:             revert B_INVALID_USER();
134:         }
135:
136:         // Check if the destination chain is enabled.
137:         (bool destChainEnabled, ) = isDestChainEnabled(_message.destChainId);
138:
139:         // Verify destination chain and to address.
140:         if (!destChainEnabled) revert B_INVALID_CHAINID();
141:         if (_message.destChainId == block.chainid) {
142:             revert B_INVALID_CHAINID();
143:         }
144:
145:         // Ensure the sent value matches the expected amount.
146:
148:         uint256 expectedAmount = _message.value + _message.fee;
149:         if (expectedAmount != msg.value) revert B_INVALID_VALUE();
150:
151:         message_ = _message;
152:
153:         // Configure message details and send signal to indicate message sending.
154:         message_.id = nextMessageId++;
155:         message_.from = msg.sender;
156:         message_.srcChainId = uint64(block.chainid);
157:
158:         msgHash_ = hashMessage(message_);
159:
160:         ISignalService(resolve("signal_service", false)).sendSignal(msgHash_);
161:         emit MessageSent(msgHash_, message_);
162:     }
```

## [L-08] Protocol does not refund extra ETH but implements strict check

[See spec here](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/IBridge.sol#L105)

The IBridge.sol contract specifies that extra ETH provided when sending a message is refunded back to the user. This currently does not happen since the code implements strict equality check. Using strict equality is better but pointing out the spec described, which would either be followed in the code implemented or the spec should be described properly in the IBridge.sol contract.

```solidity
File: Bridge.sol
146:         uint256 expectedAmount = _message.value + _message.fee;
147:         if (expectedAmount != msg.value) revert B_INVALID_VALUE();
```

## [L-09] If a message is suspended before processMessage() is called, the ERC20 tokens on the source chain and Ether are not refunded.

If a message is suspended before processMessage() is called, the status of the message remains new and the ERC20 tokens on the source and the Ether is locked as well. If the message will never be unsuspended, consider refunding the tokens to the user.

```solidity
File: Bridge.sol
287:         if (block.timestamp >= invocationDelay + receivedAt) {
288:             // If the gas limit is set to zero, only the owner can process the message.
289:             if (_message.gasLimit == 0 && msg.sender != _message.destOwner) {
290:                 revert B_PERMISSION_DENIED();
291:             }
```

## [L-10] User loses all Ether if their address is blacklisted on canonical token

When recalls are made on the source chain using the function recallMessage(), it calls the onMessageRecalled() function on the ERC20Vault contract. The onMessageRecalled() function transfers the ERC20 tokens back to the user along with any Ether that was supplied.

The issue is with this dual transfer where both ERC20 tokens are Ether are transferred to the user in the same call. If the user is blacklisted on the canonical token, the whole call reverts, causing the Ether to be stuck in the Bridge contract.

To understand this, let's consider a simple example:

1. User bridges ERC20 canonical tokens and Ether from chain A to chain B.
2. The message call on the destination chain B goes into RETRIABLE status if it fails for the first time. (**Note: User can only process after invocation delay**).
3. On multiple retries after a while, the user decides to make a last attempt, on which the call fails and goes into FAILED status.
4. During this time on chain B, the user was blacklisted on the ERC20 canonical token on the source chain.
5. When the failure signal is received by the source chain A from chain B, the user calls recallMessage() on chain A only to find out that although the blacklist is only for the canonical ERC20 token, the Ether is stuck as well.

## [L-11] onMessageInvocation checks in \_invokeMessageCall() can be bypassed to call arbitrary function from Bridge contract

[Link](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L490)

The if block requires the data to be greater than equal to 4 bytes, equal to the onMessageInvocation selector and last but not the least for the target address to be a contract.

What an attacker could do to bypass this expected spec is to pre-compute an address for the destination chain and pass it in `_message.to`. He can pass gasLimit = 0 from source to only allow him to process the message on the destination.

On the destination chain, the attacker can deploy his pre-computed contract address and call processMessage() with it from the constructor. For a chain (L2s/L3s) with no invocation delays, the proving + executing of the message data would go through in one single call.

When we arrive at the isContract check below on the `_message.to` address, we evaluate to false since the size of the contract during construction is 0. Due to this, the attacker can validly bypass the onMessageInvocation selector that is a requirement/single source of tx origination by the protocol for all transactions occurring from the bridge contract. This breaks a core invariant of the protocol.

```solidity
File: Bridge.sol
513:         if (
514:             _message.data.length >= 4 && // msg can be empty
515:             bytes4(_message.data) !=
516:             IMessageInvocable.onMessageInvocation.selector &&
517:             _message.to.isContract()
518:         ) {
519:             success_ = false;
520:         } else {
521:             (success_, ) = ExcessivelySafeCall.excessivelySafeCall(
522:                 _message.to,
523:                 _gasLimit,
524:                 _message.value,
525:                 64, // return max 64 bytes
526:                 _message.data
527:             );
528:         }
```

## [L-12] Consider reading return value from snapshot() function

[Link](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoToken.sol#L52)

The snapshot() function returns a uint256 snapshotId. These ids if retrieved earlier can make the devs life easier when taking multiple timely snapshots.

```solidity
File: TaikoToken.sol
54:     function snapshot() public onlyFromOwnerOrNamed("snapshooter") {
55:         _snapshot();
56:     }
```

## [L-13] One off error in block sync threshold check to sync chain data

The check should be \_l1BlockId >= lastSyncedBlock + BLOCK_SYNC_THRESHOLD since threshold is the minimum threshold.

```solidity
File: TaikoL2.sol
150:         if (_l1BlockId > lastSyncedBlock + BLOCK_SYNC_THRESHOLD) {
151:             // Store the L1's state root as a signal to the local signal service to
152:             // allow for multi-hop bridging.
153:             ISignalService(resolve("signal_service", false)).syncChainData(
154:                 ownerChainId,
155:                 LibSignals.STATE_ROOT,
156:                 _l1BlockId,
157:                 _l1StateRoot
158:             );
```

Same issue here:

```solidity
File: LibVerifying.sol
240:         if (_lastVerifiedBlockId > lastSyncedBlock + _config.blockSyncThreshold) {
241:             signalService.syncChainData(
242:                 _config.chainId, LibSignals.STATE_ROOT, _lastVerifiedBlockId, _stateRoot
243:             );
244:         }
```

## [L-14] One-off error when evaluating deposits to process with the ring buffer size

[Link](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibDepositing.sol#L141)

When calculating the deposits to process, we do not want to overwrite existing slots. This is why the last check/condition is implemented.

The issue with the condition is that it is one-off by the max size the ring bugger allows. Since + 1 is already added, make the check < into <= to work to it's full capacity.

```solidity
File: LibDepositing.sol
148:         unchecked {
149:
150:             return
151:                 _amount >= _config.ethDepositMinAmount &&
152:                 _amount <= _config.ethDepositMaxAmount &&
153:                 _state.slotA.numEthDeposits -
154:                     _state.slotA.nextEthDepositToProcess <
155:                 _config.ethDepositRingBufferSize - 1;
156:         }
```

## [R-01] Consider implementing changeBridgedToken() and btokenBlacklist for ERC721Vault and ERC1155Vault

[Link](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L29)

Both vaults are currently missing these two functions. Implementing them is not required but it would be good as a safety net for high-valued NFT collections in emergency scenarios that could arise.

## [R-02] Instead of passing an empty string for the data parameter in NFT vaults on token transfers, allow users to supply data

Allow users to supply the data parameter when transferring tokens from vault to them to ensure any off-chain compatibility/functionality can be built.

```solidity
File: ERC1155Vault.sol
227:     function _transferTokens(
228:         CanonicalNFT memory ctoken,
229:         address to,
230:         uint256[] memory tokenIds,
231:         uint256[] memory amounts
232:     ) private returns (address token) {
233:         if (ctoken.chainId == block.chainid) {
234:             // Token lives on this chain
235:             token = ctoken.addr;
236:
237:             IERC1155(token).safeBatchTransferFrom(
238:                 address(this),
239:                 to,
240:                 tokenIds,
241:                 amounts,
242:                 ""
243:             );
```

## [R-03] Use named imports to improve readability of the code and avoid polluting the global namespace

```solidity
File: LibAddress.sol
4: import "@openzeppelin/contracts/utils/Address.sol";
5: import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
6: import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
7: import "@openzeppelin/contracts/interfaces/IERC1271.sol";
8: import "../thirdparty/nomad-xyz/ExcessivelySafeCall.sol";
```

## [N-01] Avoid hardcoding data in BridgedERC1155

[Link](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC1155.sol#L52)

Instead of hardcoding the data, place it in a constant variable and assign the variables here for better maintainability.

```solidity
File: BridgedERC1155.sol
53:         LibBridgedToken.validateInputs(_srcToken, _srcChainId, "foo", "foo");
```

## [N-02] Missing source()/canonical() function on BridgedERC115 contract

[Link](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC1155.sol#L52)

The BridgedERC1155 contract should implement a similar function to source()/canonical() as done in the other two vaults. This would better for external dapps to retrieve the data much easily.

## [N-03] Using unchecked arithmetic in for loops is handled by solc compiler 0.8.22 onwards

```solidity
File: MerkleTrie.sol
205:     function _parseProof(bytes[] memory _proof) private pure returns (TrieNode[] memory proof_) {
206:         uint256 length = _proof.length;
207:         proof_ = new TrieNode[](length);
208:         for (uint256 i = 0; i < length;) {
209:             proof_[i] = TrieNode({ encoded: _proof[i], decoded: RLPReader.readList(_proof[i]) });
210:
211:             unchecked {
212:                 ++i;
213:             }
214:         }
215:     }
```

## [N-04] Typo in comment in Bytes.sol

Use rather instead of rathern.

```solidity
File: Bytes.sol
93:     /// @notice Slices a byte array with a given starting index up to the end of the original byte
94:     ///         array. Returns a new array rathern than a pointer to the original.
```

## [N-05] Incorrect comment regarding gasLimit in processMessage()

As confirmed with the sponsor, the comment above the gasLimit variable should be inversed i.e. use gasLeft is called by owner, else gasLimit

```solidity
File: Bridge.sol
307:             } else {
308:                 // Use the specified message gas limit if called by the owner, else
309:                 // use remaining gas
310:
311:                 uint256 gasLimit = msg.sender == _message.destOwner
312:                     ? gasleft()
313:                     : _message.gasLimit;
```

## [N-06] Use require instead of assert

Use require instead of assert to avoid Panic error, see solidity docs [here](https://docs.soliditylang.org/en/v0.8.25/control-structures.html#panic-via-assert-and-error-via-require).

```solidity
File: Bridge.sol
503:     function _invokeMessageCall(
504:         Message calldata _message,
505:         bytes32 _msgHash,
506:         uint256 _gasLimit
507:     ) private returns (bool success_) {
508:         if (_gasLimit == 0) revert B_INVALID_GAS_LIMIT();
509:         assert(_message.from != address(this));
```

## [N-07] Incorrect natspec comment for proveMessageReceived()

Correct first comment on Line 394 to "msgHash has been received"

```solidity
File: Bridge.sol
394:     /// @notice Checks if a msgHash has failed on its destination chain.
395:     /// @param _message The message.
396:     /// @param _proof The merkle inclusion proof.
397:     /// @return true if the message has failed, false otherwise.
398:     function proveMessageReceived(
399:         Message calldata _message,
400:         bytes calldata _proof
401:     ) public view returns (bool) {
```

## [N-08] Missing address(0) check for USDC in USDCAdapter

[Link](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/adapters/USDCAdapter.sol#L38)

It is important to implement this check in init() functions since they can only be called once.

```solidity
File: USDCAdapter.sol
38:     function init(address _owner, address _addressManager, IUSDC _usdc) external initializer {
39:         __Essential_init(_owner, _addressManager);
40:
41:         usdc = _usdc;
42:     }
```

## [N-09] srcToken and srcChainId is not updated on old token after migration through changeBridgedToken()

[Link](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20.sol#L73)

When a token is migrated to another token, the old token still points towards the same srcToken and srcChainId as the new token since they are not updated through changeBridgedToken().

Due to this external dapps integrating and using these values as reference could run into potential issues. Consider clearing them or changing them to some placeholder data representing the src token and chainId but with a prefix.

```solidity
File: BridgedERC20.sol
123:     function canonical() public view returns (address, uint256) {
124:         return (srcToken, srcChainId);
125:     }
```

## [N-10] MerkleClaimable does not check if claimStart is less than claimEnd

```solidity
File: MerkleClaimable.sol
90:     function _setConfig(uint64 _claimStart, uint64 _claimEnd, bytes32 _merkleRoot) private {
91:
92:         claimStart = _claimStart;
93:         claimEnd = _claimEnd;
94:         merkleRoot = _merkleRoot;
95:     }
```

## [N-11] Consider reading return value from snapshot() function

[Link](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoToken.sol#L52)

The snapshot() function returns a uint256 snapshotId. These ids if retrieved earlier can make the devs life easier when taking multiple timely snapshots.

```solidity
File: TaikoToken.sol
54:     function snapshot() public onlyFromOwnerOrNamed("snapshooter") {
55:         _snapshot();
56:     }
```

## [N-12] Guardian proof that is never fully approved by minGuardians is never deleted

A guardian proof hashs is only deleted if it has been approved by min number of guardians in the approval bits. In case it is not, the approval for the hash remains and is not deleted.

```solidity
File: GuardianProver.sol
50:         if (approved_) {
51:             deleteApproval(hash);
52:             ITaikoL1(resolve("taiko", false)).proveBlock(_meta.id, abi.encode(_meta, _tran, _proof));
53:         }
```

## [N-13] Consider making the TIMELOCK_ADMIN_ROLE undergo a delay when transferring the admin role

The admin is allowed to skip the delay in operations. But the delay should not be skipped when the role is being transferred.

```solidity
File: TaikoTimelockController.sol
25:     function getMinDelay() public view override returns (uint256) {
26:         return hasRole(TIMELOCK_ADMIN_ROLE, msg.sender) ? 0 : super.getMinDelay();
27:     }
```

**[dantaik (Taiko) confirmed commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/335#issuecomment-2036565025):**

> Many of the above are fixed in https://github.com/taikoxyz/taiko-mono/pull/16627/files:

---

# Gas Optimizations

For this audit, 28 reports were submitted by wardens detailing gas optimizations. The [report highlighted below](https://github.com/code-423n4/2024-03-taiko-findings/issues/344) by **DadeKuma** received the top score from the judge.

_The following wardens also submitted reports: [0x11singh99](https://github.com/code-423n4/2024-03-taiko-findings/issues/375), [dharma09](https://github.com/code-423n4/2024-03-taiko-findings/issues/354), [zabihullahazadzoi](https://github.com/code-423n4/2024-03-taiko-findings/issues/353), [0xAnah](https://github.com/code-423n4/2024-03-taiko-findings/issues/348), [slvDev](https://github.com/code-423n4/2024-03-taiko-findings/issues/325), [hunter_w3b](https://github.com/code-423n4/2024-03-taiko-findings/issues/292), [pfapostol](https://github.com/code-423n4/2024-03-taiko-findings/issues/196), [MrPotatoMagic](https://github.com/code-423n4/2024-03-taiko-findings/issues/189), [hihen](https://github.com/code-423n4/2024-03-taiko-findings/issues/174), [albahaca](https://github.com/code-423n4/2024-03-taiko-findings/issues/134), [Sathish9098](https://github.com/code-423n4/2024-03-taiko-findings/issues/117), [IllIllI](https://github.com/code-423n4/2024-03-taiko-findings/issues/74), [Auditor2947](https://github.com/code-423n4/2024-03-taiko-findings/issues/378), [rjs](https://github.com/code-423n4/2024-03-taiko-findings/issues/371), [SAQ](https://github.com/code-423n4/2024-03-taiko-findings/issues/367), [SY_S](https://github.com/code-423n4/2024-03-taiko-findings/issues/362), [SM3_SS](https://github.com/code-423n4/2024-03-taiko-findings/issues/360), [cheatc0d3](https://github.com/code-423n4/2024-03-taiko-findings/issues/341), [clara](https://github.com/code-423n4/2024-03-taiko-findings/issues/339), [pavankv](https://github.com/code-423n4/2024-03-taiko-findings/issues/333), [unique](https://github.com/code-423n4/2024-03-taiko-findings/issues/331), [sxima](https://github.com/code-423n4/2024-03-taiko-findings/issues/234), [0xhacksmithh](https://github.com/code-423n4/2024-03-taiko-findings/issues/194), [K42](https://github.com/code-423n4/2024-03-taiko-findings/issues/193), [Pechenite](https://github.com/code-423n4/2024-03-taiko-findings/issues/159), [oualidpro](https://github.com/code-423n4/2024-03-taiko-findings/issues/19), and [caglankaan](https://github.com/code-423n4/2024-03-taiko-findings/issues/7)._

### Gas Optimizations

|                                                      Id                                                      | Title                                                                                            | Instances | Gas Saved |
| :----------------------------------------------------------------------------------------------------------: | :----------------------------------------------------------------------------------------------- | :-------: | --------: |
|                 [[G-01]](#g-01-use-arrayunsafeaccess-to-avoid-repeated-array-length-checks)                  | Use `Array.unsafeAccess` to avoid repeated array length checks                                   |    80     |   168,000 |
|                    [[G-02]](#g-02-state-variables-can-be-packed-into-fewer-storage-slots)                    | State variables can be packed into fewer storage slots                                           |     2     |    40,000 |
|                        [[G-03]](#g-03-structs-can-be-packed-into-fewer-storage-slots)                        | Structs can be packed into fewer storage slots                                                   |     3     |    60,000 |
|    [[G-04]](#g-04-multiple-mappings-that-share-an-id-can-be-combined-into-a-single-mapping-of-id--struct)    | Multiple `mapping`s that share an ID can be combined into a single `mapping` of ID / `struct`    |     1     |    20,084 |
|               [[G-05]](#g-05-use-of-memory-instead-of-storage-for-structarray-state-variables)               | Use of `memory` instead of `storage` for struct/array state variables                            |     2     |    12,600 |
|                             [[G-06]](#g-06-state-variables-access-within-a-loop)                             | State variables access within a loop                                                             |     4     |     1,060 |
|                        [[G-07]](#g-07-unused-non-constant-state-variables-waste-gas)                         | Unused non-constant state variables waste gas                                                    |     2     |         - |
|           [[G-08]](#g-08-state-variables-only-set-in-the-constructor-should-be-declared-immutable)           | State variables only set in the constructor should be declared `immutable`                       |     2     |    40,000 |
|                          [[G-09]](#g-09-cache-state-variables-with-stack-variables)                          | Cache state variables with stack variables                                                       |    17     |     4,400 |
|                              [[G-10]](#g-10-modifiers-order-should-be-changed)                               | Modifiers order should be changed                                                                |     5     |         - |
|                        [[G-11]](#g-11-low-level-call-can-be-optimized-with-assembly)                         | Low level `call` can be optimized with assembly                                                  |     1     |       248 |
|                  [[G-12]](#g-12-use-of-memory-instead-of-calldata-for-immutable-arguments)                   | Use of `memory` instead of `calldata` for immutable arguments                                    |    116    |    41,658 |
|                     [[G-13]](#g-13-avoid-updating-storage-when-the-value-hasnt-changed)                      | Avoid updating storage when the value hasn't changed                                             |    12     |     8,400 |
|                                  [[G-14]](#g-14-use-of-emit-inside-a-loop)                                   | Use of `emit` inside a loop                                                                      |     4     |     4,104 |
|              [[G-15]](#g-15-use-uint2561uint2562-instead-of-truefalse-to-save-gas-for-changes)               | Use `uint256(1)/uint256(2)` instead of `true/false` to save gas for changes                      |    10     |   170,000 |
|                 [[G-16]](#g-16-shortcircuit-rules-can-be-be-used-to-optimize-some-gas-usage)                 | Shortcircuit rules can be be used to optimize some gas usage                                     |     1     |     2,100 |
|                          [[G-17]](#g-17-cache-multiple-accesses-of-a-mappingarray)                           | Cache multiple accesses of a mapping/array                                                       |    13     |       672 |
|                               [[G-18]](#g-18-redundant-state-variable-getters)                               | Redundant state variable getters                                                                 |     2     |         - |
|                            [[G-19]](#g-19-using-private-for-constants-saves-gas)                             | Using `private` for constants saves gas                                                          |    14     |   117,684 |
| [[G-20]](#g-20-require-or-revert-statements-that-check-input-arguments-should-be-at-the-top-of-the-function) | require() or revert() statements that check input arguments should be at the top of the function |     4     |         - |
|                           [[G-21]](#g-21-consider-activating-via-ir-for-deploying)                           | Consider activating `via-ir` for deploying                                                       |     -     |         - |
|              [[G-22]](#g-22-function-calls-should-be-cached-instead-of-re-calling-the-function)              | Function calls should be cached instead of re-calling the function                               |    12     |         - |
|               [[G-23]](#g-23-functions-that-revert-when-called-by-normal-users-can-be-payable)               | Functions that revert when called by normal users can be `payable`                               |    37     |       777 |
|          [[G-24]](#g-24-caching-global-variables-is-more-expensive-than-using-the-actual-variable)           | Caching global variables is more expensive than using the actual variable                        |     1     |        12 |
|          [[G-25]](#g-25-add-unchecked-blocks-for-subtractions-where-the-operands-cannot-underflow)           | Add `unchecked` blocks for subtractions where the operands cannot underflow                      |     7     |       595 |
|            [[G-26]](#g-26-add-unchecked-blocks-for-divisions-where-the-operands-cannot-overflow)             | Add `unchecked` blocks for divisions where the operands cannot overflow                          |    13     |     2,067 |
|                       [[G-27]](#g-27-empty-blocks-should-be-removed-or-emit-something)                       | Empty blocks should be removed or emit something                                                 |     1     |     4,006 |
|              [[G-28]](#g-28-usage-of-uintsints-smaller-than-32-bytes-256-bits-incurs-overhead)               | Usage of `uints`/`ints` smaller than 32 bytes (256 bits) incurs overhead                         |    322    |     1,932 |
|                    [[G-29]](#g-29-stack-variable-cost-less-while-used-in-emitting-event)                     | Stack variable cost less while used in emitting event                                            |     7     |        63 |
|                            [[G-30]](#g-30-redundant-event-fields-can-be-removed)                             | Redundant `event` fields can be removed                                                          |     1     |       358 |
|                        [[G-31]](#g-31-using-pre-instead-of-post-incrementsdecrements)                        | Using pre instead of post increments/decrements                                                  |     7     |         5 |
|                                     [[G-32]](#g-32--costs-less-gas-than)                                     | `>=`/`<=` costs less gas than `>`/`<`                                                            |    130    |       390 |
|                [[G-33]](#g-33-internal-functions-only-called-once-can-be-inlined-to-save-gas)                | `internal` functions only called once can be inlined to save gas                                 |    20     |       400 |
|                     [[G-34]](#g-34-inline-modifiers-that-are-only-used-once-to-save-gas)                     | Inline `modifiers` that are only used once, to save gas                                          |     5     |         - |
|                [[G-35]](#g-35-private-functions-only-called-once-can-be-inlined-to-save-gas)                 | `private` functions only called once can be inlined to save gas                                  |    41     |       820 |
|                            [[G-36]](#g-36-use-multiple-revert-checks-to-save-gas)                            | Use multiple revert checks to save gas                                                           |    37     |        74 |
|          [[G-37]](#g-37-abiencode-is-less-efficient-than-abiencodepacked-for-non-address-arguments)          | `abi.encode()` is less efficient than `abi.encodepacked()` for non-address arguments             |    16     |        80 |
|                  [[G-38]](#g-38-unused-named-return-variables-without-optimizer-waste-gas)                   | Unused named return variables without optimizer waste gas                                        |    20     |        54 |
|               [[G-39]](#g-39-consider-pre-calculating-the-address-of-addressthis-to-save-gas)                | Consider pre-calculating the address of `address(this)` to save gas                              |    40     |         - |
|                           [[G-40]](#g-40-consider-using-soladys-fixedpointmathlib)                           | Consider using Solady's `FixedPointMathLib`                                                      |     4     |         - |
|                    [[G-41]](#g-41-reduce-deployment-costs-by-tweaking-contracts-metadata)                    | Reduce deployment costs by tweaking contracts' metadata                                          |    86     |         - |
|                                [[G-42]](#g-42-emitting-constants-wastes-gas)                                 | Emitting constants wastes gas                                                                    |     4     |        32 |
|                          [[G-43]](#g-43-update-openzeppelin-dependency-to-save-gas)                          | Update OpenZeppelin dependency to save gas                                                       |    54     |         - |
|                               [[G-44]](#g-44-function-names-can-be-optimized)                                | Function names can be optimized                                                                  |    56     |     1,232 |
|                                  [[G-45]](#g-45-avoid-zero-transfers-calls)                                  | Avoid zero transfers calls                                                                       |    10     |         - |
|                 [[G-46]](#g-46-using-delete-instead-of-setting-mappingstruct-to-0-saves-gas)                 | Using `delete` instead of setting mapping/struct to 0 saves gas                                  |    10     |        50 |
|                            [[G-47]](#g-47-using-bool-for-storage-incurs-overhead)                            | Using `bool` for storage incurs overhead                                                         |    10     |     1,000 |
|                       [[G-48]](#g-48-mappings-are-cheaper-to-use-than-storage-arrays)                        | Mappings are cheaper to use than storage arrays                                                  |    36     |    75,600 |
|                   [[G-49]](#g-49-bytes-constants-are-more-efficient-than-string-constants)                   | Bytes constants are more efficient than string constants                                         |     5     |     1,890 |
|                              [[G-50]](#g-50-constructors-can-be-marked-payable)                              | Constructors can be marked `payable`                                                             |     3     |        63 |
|                            [[G-51]](#g-51-inverting-the-if-condition-wastes-gas)                             | Inverting the `if` condition wastes gas                                                          |     2     |         6 |
|                                     [[G-52]](#g-52-long-revert-strings)                                      | Long revert strings                                                                              |    27     |       720 |
|                          [[G-53]](#g-53-nesting-if-statements-that-use--saves-gas)                           | Nesting `if` statements that use `&&` saves gas                                                  |    23     |       690 |
|                            [[G-54]](#g-54-counting-down-when-iterating-saves-gas)                            | Counting down when iterating, saves gas                                                          |    45     |       270 |
|           [[G-55]](#g-55-do-while-is-cheaper-than-for-loops-when-the-initial-check-can-be-skipped)           | `do-while` is cheaper than `for`-loops when the initial check can be skipped                     |    49     |         - |
|                                  [[G-56]](#g-56-lack-of-unchecked-in-loops)                                  | Lack of `unchecked` in loops                                                                     |    39     |     2,340 |
|                           [[G-57]](#g-57-uint-comparison-with-zero-can-be-cheaper)                           | `uint` comparison with zero can be cheaper                                                       |    15     |        60 |
|                              [[G-58]](#g-58-use-assembly-to-check-for-address0)                              | Use assembly to check for `address(0)`                                                           |    74     |       444 |
|                    [[G-59]](#g-59-use-scratch-space-for-building-calldata-with-assembly)                     | Use scratch space for building calldata with assembly                                            |    333    |    73,260 |
|                                 [[G-60]](#g-60-use-assembly-to-write-hashes)                                 | Use assembly to write hashes                                                                     |    25     |     3,000 |
|                              [[G-61]](#g-61-use-assembly-to-validate-msgsender)                              | Use assembly to validate `msg.sender`                                                            |    17     |       204 |
|                         [[G-62]](#g-62-use-assembly-to-write-address-storage-values)                         | Use assembly to write `address` storage values                                                   |    18     |     1,332 |
|                                [[G-63]](#g-63-use-assembly-to-emit-an-event)                                 | Use assembly to emit an `event`                                                                  |    55     |     2,090 |

Total: 2012 instances over 63 issues with an estimate of **866,926 gas** saved.

---

## Gas Optimizations

---

### [G-01] Use `Array.unsafeAccess` to avoid repeated array length checks

When using storage arrays, solidity adds an internal lookup of the array's length (a **Gcoldsload 2100 gas**) to ensure it doesn't read past the array's end.

It's possible to avoid this lookup by using `Array.unsafeAccess` in cases where the length has already been checked.

_There are 80 instances of this issue._

<details>
<summary>Expand findings</summary>

```solidity
File: packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol

81: 		            if (_serialNumIsRevoked[index][serialNumBatch[i]]) {

84: 		            _serialNumIsRevoked[index][serialNumBatch[i]] = true;

96: 		            if (!_serialNumIsRevoked[index][serialNumBatch[i]]) {

99: 		            delete _serialNumIsRevoked[index][serialNumBatch[i]];

192: 		            EnclaveIdStruct.TcbLevel memory tcb = enclaveId.tcbLevels[i];

215: 		            TCBInfoStruct.TCBLevelObj memory current = tcb.tcbLevels[i];

241: 		            if (pckCpuSvns[i] < tcbCpuSvns[i]) {

263: 		                issuer = certs[i];

265: 		                issuer = certs[i + 1];

268: 		                    certRevoked = _serialNumIsRevoked[uint256(IPEMCertChainLib.CRL.ROOT)][certs[i]
269: 		                        .serialNumber];

270: 		                } else if (certs[i].isPck) {

271: 		                    certRevoked = _serialNumIsRevoked[uint256(IPEMCertChainLib.CRL.PCK)][certs[i]
272: 		                        .serialNumber];

280: 		                block.timestamp > certs[i].notBefore && block.timestamp < certs[i].notAfter;

286: 		                certs[i].tbsCertificate, certs[i].signature, issuer.pubKey

424: 		                (certDecodedSuccessfully, parsedQuoteCerts[i]) = pemCertLib.decodeCert(

425: 		                    authDataV3.certification.decodedCertDataArray[i], isPckCert
```

[[81](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L81), [84](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L84), [96](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L96), [99](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L99), [192](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L192), [215](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L215), [241](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L241), [263](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L263), [265](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L265), [268-269](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L268-L269), [270](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L270), [271-272](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L271-L272), [280](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L280), [286](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L286), [424](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L424), [425](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L425)]

```solidity
File: packages/protocol/contracts/bridge/Bridge.sol

91: 		            bytes32 msgHash = _msgHashes[i];

92: 		            proofReceipt[msgHash].receivedAt = _timestamp;
```

[[91](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L91), [92](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L92)]

```solidity
File: packages/protocol/contracts/L2/TaikoL2.sol

236: 		                inputs[j % 255] = blockhash(j);
```

[[236](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L236)]

```solidity
File: packages/protocol/contracts/signal/SignalService.sol

105: 		            hop = hopProofs[i];
```

[[105](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L105)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC1155Vault.sol

48: 		            if (_op.amounts[i] == 0) revert VAULT_INVALID_AMOUNT();

252: 		                    BridgedERC1155(_op.token).burn(_user, _op.tokenIds[i], _op.amounts[i]);

273: 		                        id: _op.tokenIds[i],

274: 		                        amount: _op.amounts[i],
```

[[48](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L48), [252](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L252), [273](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L273), [274](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L274)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC721Vault.sol

35: 		            if (_op.amounts[i] != 0) revert VAULT_INVALID_AMOUNT();

171: 		                IERC721(token_).safeTransferFrom(address(this), _to, _tokenIds[i]);

176: 		                BridgedERC721(token_).mint(_to, _tokenIds[i]);

198: 		                    BridgedERC721(_op.token).burn(_user, _op.tokenIds[i]);

211: 		                    t.safeTransferFrom(_user, address(this), _op.tokenIds[i]);
```

[[35](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L35), [171](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L171), [176](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L176), [198](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L198), [211](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L211)]

```solidity
File: packages/protocol/contracts/verifiers/SgxVerifier.sol

105: 		            uint256 idx = _ids[i];

107: 		            if (instances[idx].addr == address(0)) revert SGX_INVALID_INSTANCE();

109: 		            emit InstanceDeleted(idx, instances[idx].addr);

111: 		            delete instances[idx];

211: 		            if (addressRegistered[_instances[i]]) revert SGX_ALREADY_ATTESTED();

213: 		            addressRegistered[_instances[i]] = true;

215: 		            if (_instances[i] == address(0)) revert SGX_INVALID_INSTANCE();

217: 		            instances[nextInstanceId] = Instance(_instances[i], validSince);

218: 		            ids[i] = nextInstanceId;

220: 		            emit InstanceAdded(nextInstanceId, _instances[i], address(0), validSince);
```

[[105](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L105), [107](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L107), [109](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L109), [111](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L111), [211](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L211), [213](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L213), [215](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L215), [217](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L217), [218](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L218), [220](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L220)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol

62: 		            (success, certs[i], increment) = _removeHeadersAndFooters(input);

245: 		            contentStr = LibString.concat(contentStr, split[i]);

367: 		                cpusvns[i] = cpusvn;
```

[[62](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L62), [245](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L245), [367](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L367)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol

334: 		            bytes1 char = self[off + i];

336: 		            decoded = uint8(BASE32_HEX_TABLE[uint256(uint8(char)) - 0x30]);
```

[[334](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L334), [336](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L336)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol

141: 		            if (decipher[i] != 0xff) {

153: 		                if (decipher[3 + paddingLen + i] != bytes1(sha256ExplicitNullParam[i])) {

159: 		                if (decipher[3 + paddingLen + i] != bytes1(sha256ImplicitNullParam[i])) {

175: 		            if (decipher[5 + paddingLen + digestAlgoWithParamLen + i] != _sha256[i]) {

274: 		            if (decipher[i] != 0xff) {

284: 		            if (decipher[3 + paddingLen + i] != bytes1(sha1Prefix[i])) {

291: 		            if (decipher[3 + paddingLen + sha1Prefix.length + i] != _sha1[i]) {
```

[[141](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L141), [153](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L153), [159](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L159), [175](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L175), [274](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L274), [284](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L284), [291](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L291)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol

60: 		            timestamp += uint256(monthDays[i - 1]) * 86_400; // Days in seconds
```

[[60](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol#L60)]

```solidity
File: packages/protocol/contracts/L1/hooks/AssignmentHook.sol

173: 		            if (_tierFees[i].tier == _tierId) return _tierFees[i].fee;
```

[[173](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L173)]

```solidity
File: packages/protocol/contracts/L1/libs/LibDepositing.sol

87: 		                uint256 data = _state.ethDeposits[j % _config.ethDepositRingBufferSize];

88: 		                deposits_[i] = TaikoData.EthDeposit({

93: 		                uint96 _fee = deposits_[i].amount > fee ? fee : deposits_[i].amount;

101: 		                    deposits_[i].amount -= _fee;
```

[[87](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibDepositing.sol#L87), [88](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibDepositing.sol#L88), [93](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibDepositing.sol#L93), [101](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibDepositing.sol#L101)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProposing.sol

245: 		                if (uint160(prevHook) >= uint160(params.hookCalls[i].hook)) {

253: 		                IHook(params.hookCalls[i].hook).onBlockProposed{ value: address(this).balance }(

254: 		                    blk, meta_, params.hookCalls[i].data

257: 		                prevHook = params.hookCalls[i].hook;
```

[[245](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L245), [253](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L253), [254](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L254), [257](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L257)]

```solidity
File: packages/protocol/contracts/L1/provers/Guardians.sol

75: 		            delete guardianIds[guardians[i]];

81: 		            address guardian = _newGuardians[i];

84: 		            if (guardianIds[guardian] != 0) revert INVALID_GUARDIAN_SET();

88: 		            guardianIds[guardian] = guardians.length;
```

[[75](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L75), [81](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L81), [84](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L84), [88](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L88)]

```solidity
File: packages/protocol/contracts/team/airdrop/ERC721Airdrop.sol

60: 		            IERC721(token).safeTransferFrom(vault, user, tokenIds[i]);
```

[[60](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC721Airdrop.sol#L60)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol

154: 		            uint256 digits = uint256(uint8(bytes1(encoded[i])));

282: 		            quoteCerts[i] = Base64.decode(string(quoteCerts[i]));
```

[[154](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol#L154), [282](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol#L282)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol

47: 		                out_[i] = bytes1(uint8((_len / (256 ** (lenLen - i))) % 256));

60: 		            if (b[i] != 0) {

67: 		            out_[j] = b[i++];
```

[[47](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol#L47), [60](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol#L60), [67](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol#L67)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol

86: 		            TrieNode memory currentNode = proof[i];

118: 		                    value_ = RLPReader.readBytes(currentNode.decoded[TREE_RADIX]);

134: 		                    uint8 branchKey = uint8(key[currentKeyIndex]);

135: 		                    RLPReader.RLPItem memory nextNode = currentNode.decoded[branchKey];

141: 		                uint8 prefix = uint8(path[0]);

171: 		                    value_ = RLPReader.readBytes(currentNode.decoded[1]);

188: 		                    currentNodeID = _getNodeID(currentNode.decoded[1]);

209: 		            proof_[i] = TrieNode({ encoded: _proof[i], decoded: RLPReader.readList(_proof[i]) });

244: 		        for (; shared_ < max && _a[shared_] == _b[shared_];) {
```

[[86](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L86), [118](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L118), [134](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L134), [135](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L135), [141](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L141), [171](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L171), [188](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L188), [209](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L209), [244](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L244)]

</details>

---

### [G-02] State variables can be packed into fewer storage slots

Each slot saved can avoid an extra Gsset (**20000 gas**). Reads and writes (if two variables that occupy the same slot are written by the same function) will have a cheaper gas consumption.

_There are 2 instances of this issue._

```solidity
File: packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol

// @audit Can save 1 storage slot (from 7 to 6)
// @audit Consider using the following order:
/*
  *	mapping(bytes32 => bool) _trustedUserMrEnclave (32)
  *	mapping(bytes32 => bool) _trustedUserMrSigner (32)
  *	mapping(uint256 => mapping(bytes => bool)) _serialNumIsRevoked (32)
  *	mapping(string => TCBInfoStruct.TCBInfo) tcbInfo (32)
  *	EnclaveIdStruct.EnclaveId qeIdentity (20)
  *	bool _checkLocalEnclaveReport (1)
  *	address owner (20)
*/
22: 		contract AutomataDcapV3Attestation is IAttestation {
```

[[22](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L22)]

```solidity
File: packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol

// @audit Can save 1 storage slot (from 6 to 5)
// @audit Consider using the following order:
/*
  *	mapping(address => uint256) claimedAmount (32)
  *	mapping(address => uint256) withdrawnAmount (32)
  *	uint256[] __gap (32)
  *	address token (20)
  *	uint64 withdrawalWindow (8)
  *	address vault (20)
*/
12: 		contract ERC20Airdrop2 is MerkleClaimable {
```

[[12](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol#L12)]

---

### [G-03] Structs can be packed into fewer storage slots

Each slot saved can avoid an extra Gsset (**20000 gas**) for the first setting of the struct. Subsequent reads as well as writes have smaller gas savings.

_There are 3 instances of this issue._

<details>
<summary>Expand findings</summary>

```solidity
File: packages/protocol/contracts/L1/TaikoData.sol

// @audit Can save 1 storage slot (from 8 to 7)
// @audit Consider using the following order:
/*
  *	uint256 ethDepositRingBufferSize (32)
  *	uint256 ethDepositGas (32)
  *	uint256 ethDepositMaxFee (32)
  *	uint96 livenessBond (12)
  *	uint96 ethDepositMinAmount (12)
  *	uint64 chainId (8)
  *	uint96 ethDepositMaxAmount (12)
  *	uint64 blockMaxProposals (8)
  *	uint64 blockRingBufferSize (8)
  *	uint32 blockMaxGasLimit (4)
  *	uint64 maxBlocksToVerifyPerProposal (8)
  *	uint64 ethDepositMinCountPerBlock (8)
  *	uint64 ethDepositMaxCountPerBlock (8)
  *	uint24 blockMaxTxListBytes (3)
  *	uint24 blobExpiry (3)
  *	bool blobAllowedForDA (1)
  *	bool blobReuseEnabled (1)
  *	uint8 blockSyncThreshold (1)
*/
10: 		    struct Config {
11: 		        // ---------------------------------------------------------------------
12: 		        // Group 1: General configs
13: 		        // ---------------------------------------------------------------------
14: 		        // The chain ID of the network where Taiko contracts are deployed.
15: 		        uint64 chainId;
16: 		        // ---------------------------------------------------------------------
17: 		        // Group 2: Block level configs
18: 		        // ---------------------------------------------------------------------
19: 		        // The maximum number of proposals allowed in a single block.
20: 		        uint64 blockMaxProposals;
21: 		        // Size of the block ring buffer, allowing extra space for proposals.
22: 		        uint64 blockRingBufferSize;
23: 		        // The maximum number of verifications allowed when a block is proposed.
24: 		        uint64 maxBlocksToVerifyPerProposal;
25: 		        // The maximum gas limit allowed for a block.
26: 		        uint32 blockMaxGasLimit;
27: 		        // The maximum allowed bytes for the proposed transaction list calldata.
28: 		        uint24 blockMaxTxListBytes;
29: 		        // The max period in seconds that a blob can be reused for DA.
30: 		        uint24 blobExpiry;
31: 		        // True if EIP-4844 is enabled for DA
32: 		        bool blobAllowedForDA;
33: 		        // True if blob can be reused
34: 		        bool blobReuseEnabled;
35: 		        // ---------------------------------------------------------------------
36: 		        // Group 3: Proof related configs
37: 		        // ---------------------------------------------------------------------
38: 		        // The amount of Taiko token as a prover liveness bond
39: 		        uint96 livenessBond;
40: 		        // ---------------------------------------------------------------------
41: 		        // Group 4: ETH deposit related configs
42: 		        // ---------------------------------------------------------------------
43: 		        // The size of the ETH deposit ring buffer.
44: 		        uint256 ethDepositRingBufferSize;
45: 		        // The minimum number of ETH deposits allowed per block.
46: 		        uint64 ethDepositMinCountPerBlock;
47: 		        // The maximum number of ETH deposits allowed per block.
48: 		        uint64 ethDepositMaxCountPerBlock;
49: 		        // The minimum amount of ETH required for a deposit.
50: 		        uint96 ethDepositMinAmount;
51: 		        // The maximum amount of ETH allowed for a deposit.
52: 		        uint96 ethDepositMaxAmount;
53: 		        // The gas cost for processing an ETH deposit.
54: 		        uint256 ethDepositGas;
55: 		        // The maximum fee allowed for an ETH deposit.
56: 		        uint256 ethDepositMaxFee;
57: 		        // The max number of L2 blocks that can stay unsynced on L1 (a value of zero disables
58: 		        // syncing)
59: 		        uint8 blockSyncThreshold;
60: 		    }

// @audit Can save 1 storage slot (from 7 to 6)
// @audit Consider using the following order:
/*
  *	bytes32 extraData (32)
  *	bytes32 blobHash (32)
  *	bytes32 parentMetaHash (32)
  *	HookCall[] hookCalls (32)
  *	address assignedProver (20)
  *	uint24 txListByteOffset (3)
  *	uint24 txListByteSize (3)
  *	bool cacheBlobForReuse (1)
  *	address coinbase (20)
*/
78: 		    struct BlockParams {
79: 		        address assignedProver;
80: 		        address coinbase;
81: 		        bytes32 extraData;
82: 		        bytes32 blobHash;
83: 		        uint24 txListByteOffset;
84: 		        uint24 txListByteSize;
85: 		        bool cacheBlobForReuse;
86: 		        bytes32 parentMetaHash;
87: 		        HookCall[] hookCalls;
88: 		    }
```

[[10-60](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L10-L60), [78-88](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L78-L88)]

```solidity
File: packages/protocol/contracts/signal/ISignalService.sol

// @audit Can save 1 storage slot (from 5 to 4)
// @audit Consider using the following order:
/*
  *	bytes32 rootHash (32)
  *	bytes[] accountProof (32)
  *	bytes[] storageProof (32)
  *	uint64 chainId (8)
  *	uint64 blockId (8)
  *	CacheOption cacheOption (1)
*/
20: 		    struct HopProof {
21: 		        uint64 chainId;
22: 		        uint64 blockId;
23: 		        bytes32 rootHash;
24: 		        CacheOption cacheOption;
25: 		        bytes[] accountProof;
26: 		        bytes[] storageProof;
27: 		    }
```

[[20-27](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/ISignalService.sol#L20-L27)]

</details>

---

### [G-04] Multiple `mapping`s that share an ID can be combined into a single `mapping` of ID / `struct`

This can avoid a Gsset (**20000 Gas**) per mapping combined. Reads and writes will also be cheaper when a function requires both values as they both can fit in the same storage slot.

Finally, if both fields are accessed in the same function, this can save **~42 gas** per access due to not having to recalculate the key's `keccak256` hash (Gkeccak256 - **30 Gas**) and that calculation's associated stack operations.

_There is 1 instance of this issue._

```solidity
File: packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol

// @audit consider merging _trustedUserMrEnclave, _trustedUserMrSigner
39: 		    mapping(bytes32 enclave => bool trusted) private _trustedUserMrEnclave;
40: 		    mapping(bytes32 signer => bool trusted) private _trustedUserMrSigner;
```

[[39](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L39)]

---

### [G-05] Use of `memory` instead of `storage` for struct/array state variables

When fetching data from `storage`, using the `memory` keyword to assign it to a variable reads all fields of the struct/array and incurs a Gcoldsload (**2100 gas**) for each field.

This can be avoided by declaring the variable with the `storage` keyword and caching the necessary fields in stack variables.

The `memory` keyword should only be used if the entire struct/array is being returned or passed to a function that requires `memory`, or if it is being read from another `memory` array/struct.

_There are 2 instances of this issue._

```solidity
File: packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol

180: 		        EnclaveIdStruct.EnclaveId memory enclaveId = qeIdentity;
```

[[180](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L180)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC20Vault.sol

171: 		            CanonicalERC20 memory ctoken = bridgedToCanonical[btokenOld_];
```

[[171](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L171)]

---

### [G-06] State variables access within a loop

State variable reads and writes are more expensive than local variable reads and writes. Therefore, it is recommended to replace state variable reads and writes within loops with a local variable. Gas savings should be multiplied by the average loop length.

_There are 4 instances of this issue._

```solidity
File: packages/protocol/contracts/verifiers/SgxVerifier.sol

// @audit nextInstanceId
218: 		            ids[i] = nextInstanceId;
```

[[218](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L218)]

```solidity
File: packages/protocol/contracts/L1/provers/Guardians.sol

// @audit guardians
87: 		            guardians.push(guardian);

// @audit guardians
88: 		            guardianIds[guardian] = guardians.length;

// @audit minGuardians
135: 		                if (count == minGuardians) return true;
```

[[87](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L87), [88](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L88), [135](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L135)]

---

### [G-07] Unused non-constant state variables waste gas

If the variable is assigned a non-zero value, saves Gsset (20000 gas). If it's assigned a zero value, saves Gsreset (2900 gas).

If the variable remains unassigned, there is no gas savings unless the variable is public, in which case the compiler-generated non-payable getter deployment cost is saved.

If the state variable is overriding an interface's public function, mark the variable as constant or immutable so that it does not use a storage slot.

_There are 2 instances of this issue._

```solidity
File: packages/protocol/contracts/tokenvault/BaseNFTVault.sol

56: 		    mapping(address btoken => CanonicalNFT canonical) public bridgedToCanonical;

59: 		    mapping(uint256 chainId => mapping(address ctoken => address btoken)) public canonicalToBridged;
```

[[56](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BaseNFTVault.sol#L56), [59](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BaseNFTVault.sol#L59)]

---

### [G-08] State variables only set in the constructor should be declared `immutable`

Accessing state variables within a function involves an SLOAD operation, but `immutable` variables can be accessed directly without the need of it, thus reducing gas costs. As these state variables are assigned only in the constructor, consider declaring them `immutable`.

_There are 2 instances of this issue._

```solidity
File: packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol

52: 		    address public owner;
```

[[52](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L52)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/SigVerifyLib.sol

18: 		    address private ES256VERIFIER;
```

[[18](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/SigVerifyLib.sol#L18)]

---

### [G-09] Cache state variables with stack variables

Caching of a state variable replaces each Gwarmaccess (**100 gas**) with a cheaper stack read. Other less obvious fixes/optimizations include having local memory caches of state variable structs, or having local caches of state variable contracts/addresses.

_There are 17 instances of this issue._

<details>
<summary>Expand findings</summary>

```solidity
File: packages/protocol/contracts/common/AddressResolver.sol

// @audit addressManager on line 83
81: 		        if (addressManager == address(0)) revert RESOLVER_INVALID_MANAGER();
```

[[81](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/AddressResolver.sol#L81)]

```solidity
File: packages/protocol/contracts/L1/TaikoL1.sol

// @audit state on lines 67, 70
69: 		        if (!state.slotB.provingPaused) {

// @audit state on line 94
96: 		        LibVerifying.verifyBlocks(state, config, this, maxBlocksToVerify);

// @audit state on line 151
154: 		            ts_ = state.transitions[slot][blk_.verifiedTransitionId];

// @audit state on line 181
182: 		        b_ = state.slotB;
```

[[69](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoL1.sol#L69), [96](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoL1.sol#L96), [154](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoL1.sol#L154), [182](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoL1.sol#L182)]

```solidity
File: packages/protocol/contracts/L2/CrossChainOwned.sol

// @audit nextTxId on line 53
43: 		        if (txId != nextTxId) revert XCO_INVALID_TX_ID();
```

[[43](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/CrossChainOwned.sol#L43)]

```solidity
File: packages/protocol/contracts/L2/TaikoL2.sol

// @audit gasExcess on line 265
262: 		        if (gasExcess > 0) {

// @audit lastSyncedBlock on line 275
276: 		                numL1Blocks = _l1BlockId - lastSyncedBlock;
```

[[262](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L262), [276](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L276)]

```solidity
File: packages/protocol/contracts/team/TimelockTokenPool.sol

// @audit sharedVault on line 219
220: 		        IERC20(costToken).safeTransferFrom(_recipient, sharedVault, costToWithdraw);
```

[[220](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L220)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC20Base.sol

// @audit migratingAddress on line 63
61: 		        if (msg.sender == migratingAddress) {

// @audit migratingAddress on line 80
80: 		            emit MigratedTo(migratingAddress, _account, _amount);
```

[[61](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20Base.sol#L61), [80](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20Base.sol#L80)]

```solidity
File: packages/protocol/contracts/verifiers/SgxVerifier.sol

// @audit nextInstanceId on lines 218, 220, 222
217: 		            instances[nextInstanceId] = Instance(_instances[i], validSince);
```

[[217](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L217)]

```solidity
File: packages/protocol/contracts/L1/provers/Guardians.sol

// @audit version on line 95
92: 		        ++version;

// @audit guardians on lines 74, 87, 88
77: 		        delete guardians;

// @audit version on line 116
119: 		        uint256 _approval = _approvals[version][_hash];
```

[[92](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L92), [77](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L77), [119](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L119)]

```solidity
File: packages/protocol/contracts/team/airdrop/ERC20Airdrop.sol

// @audit token on line 63
71: 		        IVotes(token).delegateBySig(delegatee, nonce, expiry, v, r, s);
```

[[71](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC20Airdrop.sol#L71)]

```solidity
File: packages/protocol/contracts/tokenvault/adapters/USDCAdapter.sol

// @audit usdc on line 48
49: 		        usdc.burn(_amount);
```

[[49](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/adapters/USDCAdapter.sol#L49)]

</details>

---

### [G-10] Modifiers order should be changed

According to solidity docs, modifiers are executed in the order they are presented, so the order can be improved to avoid unnecessary `SLOAD`s and/or external calls by prioritizing cheaper modifiers first.

_There are 5 instances of this issue._

```solidity
File: packages/protocol/contracts/bridge/Bridge.sol

155: 		    function recallMessage(
156: 		        Message calldata _message,
157: 		        bytes calldata _proof
158: 		    )
159: 		        external
160: 		        nonReentrant
161: 		        whenNotPaused
162: 		        sameChain(_message.srcChainId)

217: 		    function processMessage(
218: 		        Message calldata _message,
219: 		        bytes calldata _proof
220: 		    )
221: 		        external
222: 		        nonReentrant
223: 		        whenNotPaused
224: 		        sameChain(_message.destChainId)

310: 		    function retryMessage(
311: 		        Message calldata _message,
312: 		        bool _isLastAttempt
313: 		    )
314: 		        external
315: 		        nonReentrant
316: 		        whenNotPaused
317: 		        sameChain(_message.destChainId)
```

[[155-162](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L155-L162), [217-224](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L217-L224), [310-317](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L310-L317)]

```solidity
File: packages/protocol/contracts/L1/TaikoL1.sol

75: 		    function proveBlock(
76: 		        uint64 _blockId,
77: 		        bytes calldata _input
78: 		    )
79: 		        external
80: 		        nonReentrant
81: 		        whenNotPaused
82: 		        whenProvingNotPaused

100: 		    function verifyBlocks(uint64 _maxBlocksToVerify)
101: 		        external
102: 		        nonReentrant
103: 		        whenNotPaused
104: 		        whenProvingNotPaused
```

[[75-82](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoL1.sol#L75-L82), [100-104](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoL1.sol#L100-L104)]

---

### [G-11] Low level `call` can be optimized with assembly

`returnData` is copied to memory even if the variable is not utilized: the proper way to handle this is through a low level assembly call.

```solidity
// before
(bool success,) = payable(receiver).call{gas: gas, value: value}("");

//after
bool success;
assembly {
    success := call(gas, receiver, value, 0, 0, 0, 0)
}
```

_There is 1 instance of this issue._

```solidity
File: packages/protocol/contracts/L2/CrossChainOwned.sol

50: 		        (bool success,) = address(this).call(txdata);
```

[[50](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/CrossChainOwned.sol#L50)]

---

### [G-12] Use of `memory` instead of `calldata` for immutable arguments

Consider refactoring the function arguments from `memory` to `calldata` when they are immutable, as `calldata` is cheaper.

_There are 116 instances of this issue._

<details>
<summary>Expand findings</summary>

```solidity
File: packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol

// @audit quoteEnclaveReport
175: 		    function _verifyQEReportWithIdentity(V3Struct.EnclaveReport memory quoteEnclaveReport)

// @audit pck, tcb
206: 		    function _checkTcbLevels(
207: 		        IPEMCertChainLib.PCKCertificateField memory pck,
208: 		        TCBInfoStruct.TCBInfo memory tcb

// @audit pckCpuSvns, tcbCpuSvns
229: 		    function _isCpuSvnHigherOrGreater(
230: 		        uint256[] memory pckCpuSvns,
231: 		        uint8[] memory tcbCpuSvns

// @audit certs
248: 		    function _verifyCertChain(IPEMCertChainLib.ECSha256Certificate[] memory certs)

// @audit pckCertPubKey, signedQuoteData, authDataV3, qeEnclaveReport
303: 		    function _enclaveReportSigVerification(
304: 		        bytes memory pckCertPubKey,
305: 		        bytes memory signedQuoteData,
306: 		        V3Struct.ECDSAQuoteV3AuthData memory authDataV3,
307: 		        V3Struct.EnclaveReport memory qeEnclaveReport
```

[[175](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L175), [206-208](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L206-L208), [229-231](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L229-L231), [248](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L248), [303-307](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L303-L307)]

```solidity
File: packages/protocol/contracts/L2/TaikoL2.sol

// @audit _config
252: 		    function _calc1559BaseFee(
253: 		        Config memory _config,
254: 		        uint64 _l1BlockId,
255: 		        uint32 _parentGasUsed
```

[[252-255](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L252-L255)]

```solidity
File: packages/protocol/contracts/libs/LibAddress.sol

// @audit _sig
61: 		    function isValidSignature(
62: 		        address _addr,
63: 		        bytes32 _hash,
64: 		        bytes memory _sig
```

[[61-64](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/libs/LibAddress.sol#L61-L64)]

```solidity
File: packages/protocol/contracts/signal/SignalService.sol

// @audit _hop
206: 		    function _verifyHopProof(
207: 		        uint64 _chainId,
208: 		        address _app,
209: 		        bytes32 _signal,
210: 		        bytes32 _value,
211: 		        HopProof memory _hop,
212: 		        address _signalService

// @audit _hop
271: 		    function _cacheChainData(
272: 		        HopProof memory _hop,
273: 		        uint64 _chainId,
274: 		        uint64 _blockId,
275: 		        bytes32 _signalRoot,
276: 		        bool _isFullProof,
277: 		        bool _isLastHop
```

[[206-212](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L206-L212), [271-277](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L271-L277)]

```solidity
File: packages/protocol/contracts/team/TimelockTokenPool.sol

// @audit _sig
168: 		    function withdraw(address _to, bytes memory _sig) external {

// @audit _grant
235: 		    function _getAmountOwned(Grant memory _grant) private view returns (uint128) {

// @audit _grant
267: 		    function _validateGrant(Grant memory _grant) private pure {
```

[[168](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L168), [235](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L235), [267](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L267)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC1155.sol

// @audit _symbol, _name
38: 		    function init(
39: 		        address _owner,
40: 		        address _addressManager,
41: 		        address _srcToken,
42: 		        uint256 _srcChainId,
43: 		        string memory _symbol,
44: 		        string memory _name
```

[[38-44](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC1155.sol#L38-L44)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC20.sol

// @audit _symbol, _name
52: 		    function init(
53: 		        address _owner,
54: 		        address _addressManager,
55: 		        address _srcToken,
56: 		        uint256 _srcChainId,
57: 		        uint8 _decimals,
58: 		        string memory _symbol,
59: 		        string memory _name
```

[[52-59](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20.sol#L52-L59)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC721.sol

// @audit _symbol, _name
31: 		    function init(
32: 		        address _owner,
33: 		        address _addressManager,
34: 		        address _srcToken,
35: 		        uint256 _srcChainId,
36: 		        string memory _symbol,
37: 		        string memory _name
```

[[31-37](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC721.sol#L31-L37)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC1155Vault.sol

// @audit _op
240: 		    function _handleMessage(
241: 		        address _user,
242: 		        BridgeTransferOp memory _op

// @audit _ctoken
303: 		    function _deployBridgedToken(CanonicalNFT memory _ctoken) private returns (address btoken_) {
```

[[240-242](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L240-L242), [303](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L303)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC20Vault.sol

// @audit ctoken
407: 		    function _deployBridgedToken(CanonicalERC20 memory ctoken) private returns (address btoken) {
```

[[407](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L407)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC721Vault.sol

// @audit _tokenIds
160: 		    function _transferTokens(
161: 		        CanonicalNFT memory _ctoken,
162: 		        address _to,
163: 		        uint256[] memory _tokenIds

// @audit _op
187: 		    function _handleMessage(
188: 		        address _user,
189: 		        BridgeTransferOp memory _op

// @audit _ctoken
240: 		    function _deployBridgedToken(CanonicalNFT memory _ctoken) private returns (address btoken_) {
```

[[160-163](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L160-L163), [187-189](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L187-L189), [240](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L240)]

```solidity
File: packages/protocol/contracts/tokenvault/LibBridgedToken.sol

// @audit _symbol, _name
11: 		    function validateInputs(
12: 		        address _srcToken,
13: 		        uint256 _srcChainId,
14: 		        string memory _symbol,
15: 		        string memory _name

// @audit _name
28: 		    function buildName(
29: 		        string memory _name,
30: 		        uint256 _srcChainId

// @audit _symbol
39: 		    function buildSymbol(string memory _symbol) internal pure returns (string memory) {
```

[[11-15](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/LibBridgedToken.sol#L11-L15), [28-30](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/LibBridgedToken.sol#L28-L30), [39](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/LibBridgedToken.sol#L39)]

```solidity
File: packages/protocol/contracts/verifiers/SgxVerifier.sol

// @audit _instances
195: 		    function _addInstances(
196: 		        address[] memory _instances,
197: 		        bool instantValid
```

[[195-197](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L195-L197)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol

// @audit pemChain
40: 		    function splitCertificateChain(
41: 		        bytes memory pemChain,
42: 		        uint256 size

// @audit der
74: 		    function decodeCert(
75: 		        bytes memory der,
76: 		        bool isPckCert

// @audit pemData
216: 		    function _removeHeadersAndFooters(string memory pemData)

// @audit input
252: 		    function _trimBytes(
253: 		        bytes memory input,
254: 		        uint256 expectedLength

// @audit der
269: 		    function _findPckTcbInfo(
270: 		        bytes memory der,
271: 		        uint256 tbsPtr,
272: 		        uint256 tbsParentPtr

// @audit der
341: 		    function _findTcb(
342: 		        bytes memory der,
343: 		        uint256 oidPtr
```

[[40-42](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L40-L42), [74-76](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L74-L76), [216](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L216), [252-254](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L252-L254), [269-272](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L269-L272), [341-343](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L341-L343)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/Asn1Decode.sol

// @audit der
47: 		    function root(bytes memory der) internal pure returns (uint256) {

// @audit der
56: 		    function rootOfBitStringAt(bytes memory der, uint256 ptr) internal pure returns (uint256) {

// @audit der
66: 		    function rootOfOctetStringAt(bytes memory der, uint256 ptr) internal pure returns (uint256) {

// @audit der
77: 		    function nextSiblingOf(bytes memory der, uint256 ptr) internal pure returns (uint256) {

// @audit der
87: 		    function firstChildOf(bytes memory der, uint256 ptr) internal pure returns (uint256) {

// @audit der
111: 		    function bytesAt(bytes memory der, uint256 ptr) internal pure returns (bytes memory) {

// @audit der
121: 		    function allBytesAt(bytes memory der, uint256 ptr) internal pure returns (bytes memory) {

// @audit der
131: 		    function bytes32At(bytes memory der, uint256 ptr) internal pure returns (bytes32) {

// @audit der
141: 		    function uintAt(bytes memory der, uint256 ptr) internal pure returns (uint256) {

// @audit der
154: 		    function uintBytesAt(bytes memory der, uint256 ptr) internal pure returns (bytes memory) {

// @audit der
165: 		    function keccakOfBytesAt(bytes memory der, uint256 ptr) internal pure returns (bytes32) {

// @audit der
169: 		    function keccakOfAllBytesAt(bytes memory der, uint256 ptr) internal pure returns (bytes32) {

// @audit der
179: 		    function bitstringAt(bytes memory der, uint256 ptr) internal pure returns (bytes memory) {

// @audit der
187: 		    function _readNodeLength(bytes memory der, uint256 ix) private pure returns (uint256) {
```

[[47](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/Asn1Decode.sol#L47), [56](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/Asn1Decode.sol#L56), [66](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/Asn1Decode.sol#L66), [77](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/Asn1Decode.sol#L77), [87](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/Asn1Decode.sol#L87), [111](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/Asn1Decode.sol#L111), [121](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/Asn1Decode.sol#L121), [131](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/Asn1Decode.sol#L131), [141](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/Asn1Decode.sol#L141), [154](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/Asn1Decode.sol#L154), [165](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/Asn1Decode.sol#L165), [169](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/Asn1Decode.sol#L169), [179](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/Asn1Decode.sol#L179), [187](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/Asn1Decode.sol#L187)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol

// @audit self
16: 		    function keccak(
17: 		        bytes memory self,
18: 		        uint256 offset,
19: 		        uint256 len

// @audit self, other
39: 		    function compare(bytes memory self, bytes memory other) internal pure returns (int256) {

// @audit self, other
56: 		    function compare(
57: 		        bytes memory self,
58: 		        uint256 offset,
59: 		        uint256 len,
60: 		        bytes memory other,
61: 		        uint256 otheroffset,
62: 		        uint256 otherlen

// @audit self, other
116: 		    function equals(
117: 		        bytes memory self,
118: 		        uint256 offset,
119: 		        bytes memory other,
120: 		        uint256 otherOffset,
121: 		        uint256 len

// @audit self, other
138: 		    function equals(
139: 		        bytes memory self,
140: 		        uint256 offset,
141: 		        bytes memory other,
142: 		        uint256 otherOffset

// @audit self, other
160: 		    function equals(
161: 		        bytes memory self,
162: 		        uint256 offset,
163: 		        bytes memory other

// @audit self, other
178: 		    function equals(bytes memory self, bytes memory other) internal pure returns (bool) {

// @audit self
188: 		    function readUint8(bytes memory self, uint256 idx) internal pure returns (uint8 ret) {

// @audit self
198: 		    function readUint16(bytes memory self, uint256 idx) internal pure returns (uint16 ret) {

// @audit self
211: 		    function readUint32(bytes memory self, uint256 idx) internal pure returns (uint32 ret) {

// @audit self
224: 		    function readBytes32(bytes memory self, uint256 idx) internal pure returns (bytes32 ret) {

// @audit self
237: 		    function readBytes20(bytes memory self, uint256 idx) internal pure returns (bytes20 ret) {

// @audit self
255: 		    function readBytesN(
256: 		        bytes memory self,
257: 		        uint256 idx,
258: 		        uint256 len

// @audit self
284: 		    function substring(
285: 		        bytes memory self,
286: 		        uint256 offset,
287: 		        uint256 len

// @audit self
320: 		    function base32HexDecodeWord(
321: 		        bytes memory self,
322: 		        uint256 off,
323: 		        uint256 len

// @audit a, b
371: 		    function compareBytes(bytes memory a, bytes memory b) internal pure returns (bool) {
```

[[16-19](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L16-L19), [39](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L39), [56-62](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L56-L62), [116-121](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L116-L121), [138-142](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L138-L142), [160-163](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L160-L163), [178](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L178), [188](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L188), [198](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L198), [211](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L211), [224](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L224), [237](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L237), [255-258](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L255-L258), [284-287](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L284-L287), [320-323](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L320-L323), [371](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L371)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol

// @audit _s, _e, _m
43: 		    function pkcs1Sha256(
44: 		        bytes32 _sha256,
45: 		        bytes memory _s,
46: 		        bytes memory _e,
47: 		        bytes memory _m

// @audit _data, _s, _e, _m
191: 		    function pkcs1Sha256Raw(
192: 		        bytes memory _data,
193: 		        bytes memory _s,
194: 		        bytes memory _e,
195: 		        bytes memory _m

// @audit _s, _e, _m
212: 		    function pkcs1Sha1(
213: 		        bytes20 _sha1,
214: 		        bytes memory _s,
215: 		        bytes memory _e,
216: 		        bytes memory _m

// @audit _data, _s, _e, _m
307: 		    function pkcs1Sha1Raw(
308: 		        bytes memory _data,
309: 		        bytes memory _s,
310: 		        bytes memory _e,
311: 		        bytes memory _m
```

[[43-47](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L43-L47), [191-195](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L191-L195), [212-216](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L212-L216), [307-311](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L307-L311)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/SHA1.sol

// @audit data
11: 		    function sha1(bytes memory data) internal pure returns (bytes20 ret) {
```

[[11](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/SHA1.sol#L11)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/SigVerifyLib.sol

// @audit tbs, signature, publicKey
24: 		    function verifyAttStmtSignature(
25: 		        bytes memory tbs,
26: 		        bytes memory signature,
27: 		        PublicKey memory publicKey,
28: 		        Algorithm alg

// @audit tbs, signature, publicKey
54: 		    function verifyCertificateSignature(
55: 		        bytes memory tbs,
56: 		        bytes memory signature,
57: 		        PublicKey memory publicKey,
58: 		        CertSigAlgorithm alg

// @audit tbs, signature, publicKey
79: 		    function verifyRS256Signature(
80: 		        bytes memory tbs,
81: 		        bytes memory signature,
82: 		        bytes memory publicKey

// @audit tbs, signature, publicKey
96: 		    function verifyRS1Signature(
97: 		        bytes memory tbs,
98: 		        bytes memory signature,
99: 		        bytes memory publicKey

// @audit tbs, signature, publicKey
113: 		    function verifyES256Signature(
114: 		        bytes memory tbs,
115: 		        bytes memory signature,
116: 		        bytes memory publicKey
```

[[24-28](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/SigVerifyLib.sol#L24-L28), [54-58](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/SigVerifyLib.sol#L54-L58), [79-82](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/SigVerifyLib.sol#L79-L82), [96-99](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/SigVerifyLib.sol#L96-L99), [113-116](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/SigVerifyLib.sol#L113-L116)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol

// @audit x509Time
8: 		    function toTimestamp(bytes memory x509Time) internal pure returns (uint256) {
```

[[8](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol#L8)]

```solidity
File: packages/protocol/contracts/L1/gov/TaikoGovernor.sol

// @audit _description
48: 		    function propose(
49: 		        address[] memory _targets,
50: 		        uint256[] memory _values,
51: 		        bytes[] memory _calldatas,
52: 		        string memory _description

// @audit _description
69: 		    function propose(
70: 		        address[] memory _targets,
71: 		        uint256[] memory _values,
72: 		        string[] memory _signatures,
73: 		        bytes[] memory _calldatas,
74: 		        string memory _description
```

[[48-52](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/gov/TaikoGovernor.sol#L48-L52), [69-74](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/gov/TaikoGovernor.sol#L69-L74)]

```solidity
File: packages/protocol/contracts/L1/hooks/AssignmentHook.sol

// @audit _blk, _data
62: 		    function onBlockProposed(
63: 		        TaikoData.Block memory _blk,
64: 		        TaikoData.BlockMetadata memory _meta,
65: 		        bytes memory _data

// @audit _assignment
137: 		    function hashAssignment(
138: 		        ProverAssignment memory _assignment,
139: 		        address _taikoL1Address,
140: 		        bytes32 _blobHash

// @audit _tierFees
164: 		    function _getProverFee(
165: 		        TaikoData.TierFee[] memory _tierFees,
166: 		        uint16 _tierId
```

[[62-65](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L62-L65), [137-140](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L137-L140), [164-166](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L164-L166)]

```solidity
File: packages/protocol/contracts/L1/libs/LibDepositing.sol

// @audit _config
67: 		    function processDeposits(
68: 		        TaikoData.State storage _state,
69: 		        TaikoData.Config memory _config,
70: 		        address _feeRecipient

// @audit _config
122: 		    function canDepositEthToL2(
123: 		        TaikoData.State storage _state,
124: 		        TaikoData.Config memory _config,
125: 		        uint256 _amount
```

[[67-70](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibDepositing.sol#L67-L70), [122-125](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibDepositing.sol#L122-L125)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProposing.sol

// @audit _config
287: 		    function isBlobReusable(
288: 		        TaikoData.State storage _state,
289: 		        TaikoData.Config memory _config,
290: 		        bytes32 _blobHash

// @audit _slotB
299: 		    function _isProposerPermitted(
300: 		        TaikoData.SlotB memory _slotB,
301: 		        IAddressResolver _resolver
```

[[287-290](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L287-L290), [299-301](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L299-L301)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProving.sol

// @audit _config
91: 		    function proveBlock(
92: 		        TaikoData.State storage _state,
93: 		        TaikoData.Config memory _config,
94: 		        IAddressResolver _resolver,
95: 		        TaikoData.BlockMetadata memory _meta,
96: 		        TaikoData.Transition memory _tran,
97: 		        TaikoData.TierProof memory _proof

// @audit _tran
269: 		    function _createTransition(
270: 		        TaikoData.State storage _state,
271: 		        TaikoData.Block storage _blk,
272: 		        TaikoData.Transition memory _tran,
273: 		        uint64 slot

// @audit _tran, _proof, _tier
350: 		    function _overrideWithHigherProof(
351: 		        TaikoData.TransitionState storage _ts,
352: 		        TaikoData.Transition memory _tran,
353: 		        TaikoData.TierProof memory _proof,
354: 		        ITierProvider.Tier memory _tier,
355: 		        IERC20 _tko,
356: 		        bool _sameTransition

// @audit _tier
401: 		    function _checkProverPermission(
402: 		        TaikoData.State storage _state,
403: 		        TaikoData.Block storage _blk,
404: 		        TaikoData.TransitionState storage _ts,
405: 		        uint32 _tid,
406: 		        ITierProvider.Tier memory _tier
```

[[91-97](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L91-L97), [269-273](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L269-L273), [350-356](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L350-L356), [401-406](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L401-L406)]

```solidity
File: packages/protocol/contracts/L1/libs/LibUtils.sol

// @audit _config
23: 		    function getTransition(
24: 		        TaikoData.State storage _state,
25: 		        TaikoData.Config memory _config,
26: 		        uint64 _blockId,
27: 		        bytes32 _parentHash

// @audit _config
52: 		    function getBlock(
53: 		        TaikoData.State storage _state,
54: 		        TaikoData.Config memory _config,
55: 		        uint64 _blockId
```

[[23-27](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibUtils.sol#L23-L27), [52-55](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibUtils.sol#L52-L55)]

```solidity
File: packages/protocol/contracts/L1/libs/LibVerifying.sol

// @audit _config
224: 		    function _syncChainData(
225: 		        TaikoData.Config memory _config,
226: 		        IAddressResolver _resolver,
227: 		        uint64 _lastVerifiedBlockId,
228: 		        bytes32 _stateRoot

// @audit _config
245: 		    function _isConfigValid(TaikoData.Config memory _config) private view returns (bool) {
```

[[224-228](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L224-L228), [245](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L245)]

```solidity
File: packages/protocol/contracts/thirdparty/nomad-xyz/ExcessivelySafeCall.sol

// @audit _calldata
25: 		    function excessivelySafeCall(
26: 		        address _target,
27: 		        uint256 _gas,
28: 		        uint256 _value,
29: 		        uint16 _maxCopy,
30: 		        bytes memory _calldata
```

[[25-30](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/nomad-xyz/ExcessivelySafeCall.sol#L25-L30)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/Bytes.sol

// @audit _bytes
15: 		    function slice(
16: 		        bytes memory _bytes,
17: 		        uint256 _start,
18: 		        uint256 _length

// @audit _bytes
91: 		    function slice(bytes memory _bytes, uint256 _start) internal pure returns (bytes memory) {

// @audit _bytes
102: 		    function toNibbles(bytes memory _bytes) internal pure returns (bytes memory) {

// @audit _bytes, _other
149: 		    function equal(bytes memory _bytes, bytes memory _other) internal pure returns (bool) {
```

[[15-18](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/Bytes.sol#L15-L18), [91](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/Bytes.sol#L91), [102](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/Bytes.sol#L102), [149](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/Bytes.sol#L149)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol

// @audit quote
21: 		    function parseInput(
22: 		        bytes memory quote,
23: 		        address pemCertLibAddr

// @audit v3Quote
62: 		    function validateParsedInput(V3Struct.ParsedV3QuoteStruct memory v3Quote)

// @audit rawEnclaveReport
133: 		    function parseEnclaveReport(bytes memory rawEnclaveReport)

// @audit encoded
152: 		    function littleEndianDecode(bytes memory encoded) private pure returns (uint256 decoded) {

// @audit rawHeader
165: 		    function parseAndVerifyHeader(bytes memory rawHeader)

// @audit rawAuthData
203: 		    function parseAuthDataAndVerifyCertType(
204: 		        bytes memory rawAuthData,
205: 		        address pemCertLibAddr

// @audit enclaveReport
244: 		    function packQEReport(V3Struct.EnclaveReport memory enclaveReport)

// @audit certBytes
267: 		    function parseCerificationChainBytes(
268: 		        bytes memory certBytes,
269: 		        address pemCertLibAddr
```

[[21-23](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol#L21-L23), [62](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol#L62), [133](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol#L133), [152](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol#L152), [165](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol#L165), [203-205](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol#L203-L205), [244](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol#L244), [267-269](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol#L267-L269)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol

// @audit _in
35: 		    function toRLPItem(bytes memory _in) internal pure returns (RLPItem memory out_) {

// @audit _in
102: 		    function readList(bytes memory _in) internal pure returns (RLPItem[] memory out_) {

// @audit _in
128: 		    function readBytes(bytes memory _in) internal pure returns (bytes memory out_) {

// @audit _in
135: 		    function readRawBytes(RLPItem memory _in) internal pure returns (bytes memory out_) {

// @audit _in
144: 		    function _decodeLength(RLPItem memory _in)
```

[[35](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L35), [102](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L102), [128](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L128), [135](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L135), [144](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L144)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol

// @audit _in
13: 		    function writeBytes(bytes memory _in) internal pure returns (bytes memory out_) {
```

[[13](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol#L13)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol

// @audit _key, _value
50: 		    function verifyInclusionProof(
51: 		        bytes memory _key,
52: 		        bytes memory _value,
53: 		        bytes[] memory _proof,
54: 		        bytes32 _root

// @audit _key
68: 		    function get(
69: 		        bytes memory _key,
70: 		        bytes[] memory _proof,
71: 		        bytes32 _root

// @audit _proof
205: 		    function _parseProof(bytes[] memory _proof) private pure returns (TrieNode[] memory proof_) {

// @audit _node
227: 		    function _getNodePath(TrieNode memory _node) private pure returns (bytes memory nibbles_) {

// @audit _a, _b
235: 		    function _getSharedNibbleLength(
236: 		        bytes memory _a,
237: 		        bytes memory _b
```

[[50-54](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L50-L54), [68-71](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L68-L71), [205](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L205), [227](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L227), [235-237](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L235-L237)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/trie/SecureMerkleTrie.sol

// @audit _key, _value
19: 		    function verifyInclusionProof(
20: 		        bytes memory _key,
21: 		        bytes memory _value,
22: 		        bytes[] memory _proof,
23: 		        bytes32 _root

// @audit _key
38: 		    function get(
39: 		        bytes memory _key,
40: 		        bytes[] memory _proof,
41: 		        bytes32 _root

// @audit _key
54: 		    function _getSecureKey(bytes memory _key) private pure returns (bytes memory hash_) {
```

[[19-23](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/SecureMerkleTrie.sol#L19-L23), [38-41](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/SecureMerkleTrie.sol#L38-L41), [54](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/SecureMerkleTrie.sol#L54)]

</details>

---

### [G-13] Avoid updating storage when the value hasn't changed

If the old value is equal to the new value, not re-storing the value will avoid a Gsreset (**2900 gas**), potentially at the expense of a Gcoldsload (**2100 gas**) or a Gwarmaccess (**100 gas**)

_There are 12 instances of this issue._

<details>
<summary>Expand findings</summary>

```solidity
File: packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol

// @audit _trustedUserMrSigner
65: 		    function setMrSigner(bytes32 _mrSigner, bool _trusted) external onlyOwner {

// @audit _trustedUserMrEnclave
69: 		    function setMrEnclave(bytes32 _mrEnclave, bool _trusted) external onlyOwner {

// @audit tcbInfo
103: 		    function configureTcbInfoJson(

// @audit qeIdentity
114: 		    function configureQeIdentityJson(EnclaveIdStruct.EnclaveId calldata qeIdentityInput)
```

[[65](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L65), [69](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L69), [103](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L103), [114](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L114)]

```solidity
File: packages/protocol/contracts/bridge/Bridge.sol

// @audit messageStatus
515: 		    function _updateMessageStatus(bytes32 _msgHash, Status _status) private {
```

[[515](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L515)]

```solidity
File: packages/protocol/contracts/common/DefaultResolver.sol

// @audit __addresses
38: 		    function setAddress(
```

[[38](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/DefaultResolver.sol#L38)]

```solidity
File: packages/protocol/contracts/L2/TaikoL2EIP1559Configurable.sol

// @audit customConfig
25: 		    function setConfigAndExcess(
```

[[25](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2EIP1559Configurable.sol#L25)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC20.sol

// @audit snapshooter
80: 		    function setSnapshoter(address _snapshooter) external onlyOwner {
```

[[80](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20.sol#L80)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC20Base.sol

// @audit migratingAddress, migratingInbound
36: 		    function changeMigrationStatus(
```

[[36](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20Base.sol#L36)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC20Vault.sol

// @audit btokenBlacklist, bridgedToCanonical, canonicalToBridged
148: 		    function changeBridgedToken(
```

[[148](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L148)]

```solidity
File: packages/protocol/contracts/L1/provers/Guardians.sol

// @audit guardianIds, minGuardians
53: 		    function setGuardians(
```

[[53](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L53)]

```solidity
File: packages/protocol/contracts/team/airdrop/MerkleClaimable.sol

// @audit claimStart, claimEnd, merkleRoot
90: 		    function _setConfig(uint64 _claimStart, uint64 _claimEnd, bytes32 _merkleRoot) private {
```

[[90](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/MerkleClaimable.sol#L90)]

</details>

---

### [G-14] Use of `emit` inside a loop

Emitting an event inside a loop performs a `LOG` op N times, where N is the loop length. Consider refactoring the code to emit the event only once at the end of loop. Gas savings should be multiplied by the average loop length.

_There are 4 instances of this issue._

```solidity
File: packages/protocol/contracts/bridge/Bridge.sol

93: 		            emit MessageSuspended(msgHash, _suspend);
```

[[93](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L93)]

```solidity
File: packages/protocol/contracts/verifiers/SgxVerifier.sol

109: 		            emit InstanceDeleted(idx, instances[idx].addr);

220: 		            emit InstanceAdded(nextInstanceId, _instances[i], address(0), validSince);
```

[[109](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L109), [220](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L220)]

```solidity
File: packages/protocol/contracts/L1/libs/LibVerifying.sol

198: 		                emit BlockVerified({
199: 		                    blockId: blockId,
200: 		                    assignedProver: blk.assignedProver,
201: 		                    prover: ts.prover,
202: 		                    blockHash: blockHash,
203: 		                    stateRoot: stateRoot,
204: 		                    tier: ts.tier,
205: 		                    contestations: ts.contestations
206: 		                });
```

[[198-206](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L198-L206)]

---

### [G-15] Use `uint256(1)/uint256(2)` instead of `true/false` to save gas for changes

Use `uint256(1)` and `uint256(2)` for `true`/`false` to avoid a Gsset (20000 gas) when changing from `false` to `true`, after having been `true` in the past. See [source](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/58f635312aa21f947cae5f8578638a85aa2519f5/contracts/security/ReentrancyGuard.sol#L23-L27).

_There are 10 instances of this issue._

<details>
<summary>Expand findings</summary>

```solidity
File: packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol

38: 		    bool private _checkLocalEnclaveReport;

39: 		    mapping(bytes32 enclave => bool trusted) private _trustedUserMrEnclave;

40: 		    mapping(bytes32 signer => bool trusted) private _trustedUserMrSigner;

47: 		    mapping(uint256 idx => mapping(bytes serialNum => bool revoked)) private _serialNumIsRevoked;
```

[[38](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L38), [39](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L39), [40](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L40), [47](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L47)]

```solidity
File: packages/protocol/contracts/bridge/Bridge.sol

42: 		    mapping(address addr => bool banned) public addressBanned;
```

[[42](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L42)]

```solidity
File: packages/protocol/contracts/signal/SignalService.sol

21: 		    mapping(address addr => bool authorized) public isAuthorized;
```

[[21](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L21)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC20Base.sol

14: 		    bool public migratingInbound;
```

[[14](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20Base.sol#L14)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC20Vault.sol

52: 		    mapping(address btoken => bool blacklisted) public btokenBlacklist;
```

[[52](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L52)]

```solidity
File: packages/protocol/contracts/verifiers/SgxVerifier.sol

55: 		    mapping(address instanceAddress => bool alreadyAttested) public addressRegistered;
```

[[55](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L55)]

```solidity
File: packages/protocol/contracts/team/airdrop/MerkleClaimable.sol

12: 		    mapping(bytes32 hash => bool claimed) public isClaimed;
```

[[12](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/MerkleClaimable.sol#L12)]

</details>

---

### [G-16] Shortcircuit rules can be be used to optimize some gas usage

Some conditions may be reordered to save an `SLOAD` (**2100 gas**), as we avoid reading state variables when the first part of the condition fails (with `&&`), or succeeds (with `||`).

_There is 1 instance of this issue._

```solidity
File: packages/protocol/contracts/L2/CrossChainOwned.sol

// @audit switch with this condition
// ctx.from != owner() || ctx.srcChainId != ownerChainId
46: 		        if (ctx.srcChainId != ownerChainId || ctx.from != owner()) {
```

[[46](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/CrossChainOwned.sol#L46)]

---

### [G-17] Cache multiple accesses of a mapping/array

Consider using a local `storage` or `calldata` variable when accessing a mapping/array value multiple times.

This can be useful to avoid recalculating the mapping hash and/or the array offsets.

_There are 13 instances of this issue._

<details>
<summary>Expand findings</summary>

```solidity
File: packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol

// @audit _serialNumIsRevoked on line 81
84: 		            _serialNumIsRevoked[index][serialNumBatch[i]] = true;

// @audit _serialNumIsRevoked[index] on line 96
99: 		            delete _serialNumIsRevoked[index][serialNumBatch[i]];

// @audit _serialNumIsRevoked[uint256(IPEMCertChainLib.CRL.PCK)] on line 268
271: 		                    certRevoked = _serialNumIsRevoked[uint256(IPEMCertChainLib.CRL.PCK)][certs[i]
272: 		                        .serialNumber];
```

[[84](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L84), [99](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L99), [271-272](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L271-L272)]

```solidity
File: packages/protocol/contracts/bridge/Bridge.sol

// @audit proofReceipt on lines 168, 184
190: 		            delete proofReceipt[msgHash];
```

[[190](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L190)]

```solidity
File: packages/protocol/contracts/common/DefaultResolver.sol

// @audit __addresses on line 47
49: 		        __addresses[_chainId][_name] = _newAddress;
```

[[49](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/DefaultResolver.sol#L49)]

```solidity
File: packages/protocol/contracts/L1/TaikoL1.sol

// @audit state.transitions on line 154
154: 		            ts_ = state.transitions[slot][blk_.verifiedTransitionId];
```

[[154](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoL1.sol#L154)]

```solidity
File: packages/protocol/contracts/signal/SignalService.sol

// @audit topBlockId on line 247
248: 		            topBlockId[_chainId][_kind] = _blockId;
```

[[248](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L248)]

```solidity
File: packages/protocol/contracts/team/TimelockTokenPool.sol

// @audit recipients on line 137
142: 		        recipients[_recipient].grant = _grant;
```

[[142](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L142)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC20Vault.sol

// @audit canonicalToBridged on line 168
189: 		        canonicalToBridged[_ctoken.chainId][_ctoken.addr] = _btokenNew;

// @audit bridgedToCanonical on line 358
359: 		            ctoken_ = bridgedToCanonical[_token];
```

[[189](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L189), [359](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L359)]

```solidity
File: packages/protocol/contracts/verifiers/SgxVerifier.sol

// @audit instances on lines 107, 109
111: 		            delete instances[idx];

// @audit instances on lines 235, 236
237: 		            && block.timestamp <= instances[id].validSince + INSTANCE_EXPIRY;
```

[[111](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L111), [237](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L237)]

```solidity
File: packages/protocol/contracts/L1/provers/Guardians.sol

// @audit _approvals on line 116
119: 		        uint256 _approval = _approvals[version][_hash];
```

[[119](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L119)]

</details>

---

### [G-18] Redundant state variable getters

Getters for public state variables are automatically generated with public variables, so there is no need to code them manually, as it adds an unnecessary overhead.

_There are 2 instances of this issue._

```solidity
File: packages/protocol/contracts/L2/TaikoL2.sol

200: 		    function getBlockHash(uint64 _blockId) public view returns (bytes32) {
201: 		        if (_blockId >= block.number) return 0;
202: 		        if (_blockId + 256 >= block.number) return blockhash(_blockId);
203: 		        return l2Hashes[_blockId];
204: 		    }
```

[[200-204](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L200-L204)]

```solidity
File: packages/protocol/contracts/L2/TaikoL2EIP1559Configurable.sol

43: 		    function getConfig() public view override returns (Config memory) {
44: 		        return customConfig;
45: 		    }
```

[[43-45](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2EIP1559Configurable.sol#L43-L45)]

---

### [G-19] Using `private` for constants saves gas

Saves deployment gas due to the compiler not having to create non-payable getter functions for deployment calldata, not having to store the bytes of the value outside of where it's used, and not adding another entry to the method ID table.

_There are 14 instances of this issue._

<details>
<summary>Expand findings</summary>

```solidity
File: packages/protocol/contracts/L2/TaikoL2.sol

35: 		    uint8 public constant BLOCK_SYNC_THRESHOLD = 5;
```

[[35](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L35)]

```solidity
File: packages/protocol/contracts/libs/Lib4844.sol

10: 		    address public constant POINT_EVALUATION_PRECOMPILE_ADDRESS = address(0x0A);

13: 		    uint32 public constant FIELD_ELEMENTS_PER_BLOB = 4096;

16: 		    uint256 public constant BLS_MODULUS =
17: 		        52_435_875_175_126_190_479_447_740_508_185_965_837_690_552_500_527_637_822_603_658_699_938_581_184_513;
```

[[10](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/libs/Lib4844.sol#L10), [13](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/libs/Lib4844.sol#L13), [16-17](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/libs/Lib4844.sol#L16-L17)]

```solidity
File: packages/protocol/contracts/tokenvault/BaseNFTVault.sol

47: 		    bytes4 public constant ERC1155_INTERFACE_ID = 0xd9b67a26;

50: 		    bytes4 public constant ERC721_INTERFACE_ID = 0x80ac58cd;

53: 		    uint256 public constant MAX_TOKEN_PER_TXN = 10;
```

[[47](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BaseNFTVault.sol#L47), [50](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BaseNFTVault.sol#L50), [53](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BaseNFTVault.sol#L53)]

```solidity
File: packages/protocol/contracts/verifiers/SgxVerifier.sol

30: 		    uint64 public constant INSTANCE_EXPIRY = 180 days;

34: 		    uint64 public constant INSTANCE_VALIDITY_DELAY = 1 days;
```

[[30](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L30), [34](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L34)]

```solidity
File: packages/protocol/contracts/L1/hooks/AssignmentHook.sol

38: 		    uint256 public constant MAX_GAS_PAYING_PROVER = 50_000;
```

[[38](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L38)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProposing.sol

21: 		    uint256 public constant MAX_BYTES_PER_BLOB = 4096 * 32;
```

[[21](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L21)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProving.sol

20: 		    bytes32 public constant RETURN_LIVENESS_BOND = keccak256("RETURN_LIVENESS_BOND");

23: 		    bytes32 public constant TIER_OP = bytes32("tier_optimistic");
```

[[20](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L20), [23](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L23)]

```solidity
File: packages/protocol/contracts/L1/provers/Guardians.sol

11: 		    uint256 public constant MIN_NUM_GUARDIANS = 5;
```

[[11](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L11)]

</details>

---

### [G-20] require() or revert() statements that check input arguments should be at the top of the function

Checks that can be performed earlier should come before checks that involve state variables, function calls, and calculations. By doing these checks first, the function is able to revert before wasting a Gcoldsload (_2100 gas_) in a function that may ultimately revert.

_There are 4 instances of this issue._

```solidity
File: packages/protocol/contracts/common/EssentialContract.sol

// @audit expensive op on line 103
105: 		        if (_addressManager == address(0)) revert ZERO_ADDR_MANAGER();
```

[[105](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/EssentialContract.sol#L105)]

```solidity
File: packages/protocol/contracts/team/TimelockTokenPool.sol

// @audit expensive op on line 120
121: 		        if (_taikoToken == address(0)) revert INVALID_PARAM();

// @audit expensive op on line 120
124: 		        if (_costToken == address(0)) revert INVALID_PARAM();

// @audit expensive op on line 120
127: 		        if (_sharedVault == address(0)) revert INVALID_PARAM();
```

[[121](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L121), [124](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L124), [127](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L127)]

---

### [G-21] Consider activating `via-ir` for deploying

The IR-based code generator was developed to make code generation more performant by enabling optimization passes that can be applied across functions.

It is possible to activate the IR-based code generator through the command line by using the flag `--via-ir` or by including the option `{"viaIR": true}`.

Keep in mind that compiling with this option may take longer. However, you can simply test it before deploying your code. If you find that it provides better performance, you can add the `--via-ir` flag to your deploy command.

---

### [G-22] Function calls should be cached instead of re-calling the function

Consider caching the result instead of re-calling the function when possible. Note: this also includes casts, which cost between 42-46 gas, depending on the type.

_There are 12 instances of this issue._

```solidity
File: packages/protocol/contracts/L2/TaikoL2.sol

// @audit blockhash(parentId) is duplicated on line 157
154: 		        l2Hashes[parentId] = blockhash(parentId);
```

[[154](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L154)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol

// @audit der.nextSiblingOf(tbsPtr) is duplicated on line 111, 112, 127, 144, 157, 186
104: 		        tbsPtr = der.nextSiblingOf(tbsPtr);

// @audit der.firstChildOf(tbsPtr) is duplicated on line 130, 147, 161, 193, 194
115: 		            uint256 issuerPtr = der.firstChildOf(tbsPtr);

// @audit der.firstChildOf(issuerPtr) is duplicated on line 117
116: 		            issuerPtr = der.firstChildOf(issuerPtr);

// @audit der.firstChildOf(subjectPtr) is duplicated on line 149
148: 		            subjectPtr = der.firstChildOf(subjectPtr);

// @audit der.nextSiblingOf(sigPtr) is duplicated on line 176
167: 		            sigPtr = der.nextSiblingOf(sigPtr);

// @audit _trimBytes(der.bytesAt(sigPtr), 32) is duplicated on line 177
174: 		            bytes memory sigX = _trimBytes(der.bytesAt(sigPtr), 32);

// @audit der.bytesAt(sigPtr) is duplicated on line 177
174: 		            bytes memory sigX = _trimBytes(der.bytesAt(sigPtr), 32);

// @audit der.nextSiblingOf(extnValueOidPtr) is duplicated on line 318
312: 		                        uint256 pceidPtr = der.nextSiblingOf(extnValueOidPtr);

// @audit bytes2(svnValueBytes) is duplicated on line 360
359: 		                ? uint16(bytes2(svnValueBytes)) / 256
```

[[104](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L104), [115](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L115), [116](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L116), [148](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L148), [167](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L167), [174](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L174), [174](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L174), [312](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L312), [359](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L359)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol

// @audit MemoryPointer.wrap(MemoryPointer.unwrap(_in.ptr) + offset) is duplicated on line 86
78: 		                    ptr: MemoryPointer.wrap(MemoryPointer.unwrap(_in.ptr) + offset)

// @audit MemoryPointer.unwrap(_in.ptr) is duplicated on line 86
78: 		                    ptr: MemoryPointer.wrap(MemoryPointer.unwrap(_in.ptr) + offset)
```

[[78](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L78), [78](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L78)]

---

### [G-23] Functions that revert when called by normal users can be `payable`

If a function modifier such as `onlyOwner` is used, the function will revert if a normal user tries to pay the function.

Marking the function as `payable` will lower the gas for legitimate callers, as the compiler will not include checks for whether a payment was provided.

The extra opcodes avoided are:

`CALLVALUE(2), DUP1(3), ISZERO(3), PUSH2(3), JUMPI(10), PUSH1(3), DUP1(3), REVERT(0), JUMPDEST(1), POP(2)`

which cost an average of about 21 gas per call to the function, in addition to the extra deployment cost.

_There are 37 instances of this issue._

<details>
<summary>Expand findings</summary>

```solidity
File: packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol

65: 		    function setMrSigner(bytes32 _mrSigner, bool _trusted) external onlyOwner {

69: 		    function setMrEnclave(bytes32 _mrEnclave, bool _trusted) external onlyOwner {

73: 		    function addRevokedCertSerialNum(
74: 		        uint256 index,
75: 		        bytes[] calldata serialNumBatch
76: 		    )
77: 		        external
78: 		        onlyOwner

88: 		    function removeRevokedCertSerialNum(
89: 		        uint256 index,
90: 		        bytes[] calldata serialNumBatch
91: 		    )
92: 		        external
93: 		        onlyOwner

103: 		    function configureTcbInfoJson(
104: 		        string calldata fmspc,
105: 		        TCBInfoStruct.TCBInfo calldata tcbInfoInput
106: 		    )
107: 		        public
108: 		        onlyOwner

114: 		    function configureQeIdentityJson(EnclaveIdStruct.EnclaveId calldata qeIdentityInput)
115: 		        external
116: 		        onlyOwner

122: 		    function toggleLocalReportCheck() external onlyOwner {
```

[[65](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L65), [69](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L69), [73-78](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L73-L78), [88-93](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L88-L93), [103-108](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L103-L108), [114-116](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L114-L116), [122](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L122)]

```solidity
File: packages/protocol/contracts/bridge/Bridge.sol

82: 		    function suspendMessages(
83: 		        bytes32[] calldata _msgHashes,
84: 		        bool _suspend
85: 		    )
86: 		        external
87: 		        onlyFromOwnerOrNamed("bridge_watchdog")

101: 		    function banAddress(
102: 		        address _addr,
103: 		        bool _ban
104: 		    )
105: 		        external
106: 		        onlyFromOwnerOrNamed("bridge_watchdog")
107: 		        nonReentrant
```

[[82-87](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L82-L87), [101-107](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L101-L107)]

```solidity
File: packages/protocol/contracts/common/DefaultResolver.sol

38: 		    function setAddress(
39: 		        uint64 _chainId,
40: 		        bytes32 _name,
41: 		        address _newAddress
42: 		    )
43: 		        external
44: 		        virtual
45: 		        onlyOwner
```

[[38-45](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/DefaultResolver.sol#L38-L45)]

```solidity
File: packages/protocol/contracts/common/AddressResolver.sol

58: 		    function __AddressResolver_init(address _addressManager) internal virtual onlyInitializing {
```

[[58](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/AddressResolver.sol#L58)]

```solidity
File: packages/protocol/contracts/common/EssentialContract.sol

95: 		    function __Essential_init(
96: 		        address _owner,
97: 		        address _addressManager
98: 		    )
99: 		        internal
100: 		        virtual
101: 		        onlyInitializing

114: 		    function _authorizeUpgrade(address) internal virtual override onlyOwner { }

116: 		    function _authorizePause(address) internal virtual onlyOwner { }
```

[[95-101](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/EssentialContract.sol#L95-L101), [114](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/EssentialContract.sol#L114), [116](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/EssentialContract.sol#L116)]

```solidity
File: packages/protocol/contracts/L1/TaikoToken.sol

47: 		    function burn(address _from, uint256 _amount) public onlyOwner {

52: 		    function snapshot() public onlyFromOwnerOrNamed("snapshooter") {
```

[[47](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoToken.sol#L47), [52](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoToken.sol#L52)]

```solidity
File: packages/protocol/contracts/L2/CrossChainOwned.sol

60: 		    function __CrossChainOwned_init(
61: 		        address _owner,
62: 		        address _addressManager,
63: 		        uint64 _ownerChainId
64: 		    )
65: 		        internal
66: 		        virtual
67: 		        onlyInitializing
```

[[60-67](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/CrossChainOwned.sol#L60-L67)]

```solidity
File: packages/protocol/contracts/L2/TaikoL2.sol

163: 		    function withdraw(
164: 		        address _token,
165: 		        address _to
166: 		    )
167: 		        external
168: 		        onlyFromOwnerOrNamed("withdrawer")
169: 		        nonReentrant
170: 		        whenNotPaused
```

[[163-170](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L163-L170)]

```solidity
File: packages/protocol/contracts/L2/TaikoL2EIP1559Configurable.sol

25: 		    function setConfigAndExcess(
26: 		        Config memory _newConfig,
27: 		        uint64 _newGasExcess
28: 		    )
29: 		        external
30: 		        virtual
31: 		        onlyOwner
```

[[25-31](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2EIP1559Configurable.sol#L25-L31)]

```solidity
File: packages/protocol/contracts/signal/SignalService.sol

56: 		    function authorize(address _addr, bool _authorize) external onlyOwner {
```

[[56](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L56)]

```solidity
File: packages/protocol/contracts/team/TimelockTokenPool.sol

135: 		    function grant(address _recipient, Grant memory _grant) external onlyOwner {

150: 		    function void(address _recipient) external onlyOwner {
```

[[135](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L135), [150](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L150)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC1155.sol

66: 		    function mint(
67: 		        address _to,
68: 		        uint256 _tokenId,
69: 		        uint256 _amount
70: 		    )
71: 		        public
72: 		        nonReentrant
73: 		        whenNotPaused
74: 		        onlyFromNamed("erc1155_vault")

83: 		    function mintBatch(
84: 		        address _to,
85: 		        uint256[] memory _tokenIds,
86: 		        uint256[] memory _amounts
87: 		    )
88: 		        public
89: 		        nonReentrant
90: 		        whenNotPaused
91: 		        onlyFromNamed("erc1155_vault")

100: 		    function burn(
101: 		        address _account,
102: 		        uint256 _tokenId,
103: 		        uint256 _amount
104: 		    )
105: 		        public
106: 		        nonReentrant
107: 		        whenNotPaused
108: 		        onlyFromNamed("erc1155_vault")
```

[[66-74](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC1155.sol#L66-L74), [83-91](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC1155.sol#L83-L91), [100-108](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC1155.sol#L100-L108)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC20.sol

80: 		    function setSnapshoter(address _snapshooter) external onlyOwner {

85: 		    function snapshot() external onlyOwnerOrSnapshooter {
```

[[80](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20.sol#L80), [85](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20.sol#L85)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC20Base.sol

36: 		    function changeMigrationStatus(
37: 		        address _migratingAddress,
38: 		        bool _migratingInbound
39: 		    )
40: 		        external
41: 		        nonReentrant
42: 		        whenNotPaused
43: 		        onlyFromOwnerOrNamed("erc20_vault")
```

[[36-43](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20Base.sol#L36-L43)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC721.sol

54: 		    function mint(
55: 		        address _account,
56: 		        uint256 _tokenId
57: 		    )
58: 		        public
59: 		        nonReentrant
60: 		        whenNotPaused
61: 		        onlyFromNamed("erc721_vault")

69: 		    function burn(
70: 		        address _account,
71: 		        uint256 _tokenId
72: 		    )
73: 		        public
74: 		        nonReentrant
75: 		        whenNotPaused
76: 		        onlyFromNamed("erc721_vault")
```

[[54-61](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC721.sol#L54-L61), [69-76](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC721.sol#L69-L76)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC20Vault.sol

148: 		    function changeBridgedToken(
149: 		        CanonicalERC20 calldata _ctoken,
150: 		        address _btokenNew
151: 		    )
152: 		        external
153: 		        nonReentrant
154: 		        whenNotPaused
155: 		        onlyOwner
```

[[148-155](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L148-L155)]

```solidity
File: packages/protocol/contracts/verifiers/SgxVerifier.sol

90: 		    function addInstances(address[] calldata _instances)
91: 		        external
92: 		        onlyOwner

100: 		    function deleteInstances(uint256[] calldata _ids)
101: 		        external
102: 		        onlyFromOwnerOrNamed("rollup_watchdog")

139: 		    function verifyProof(
140: 		        Context calldata _ctx,
141: 		        TaikoData.Transition calldata _tran,
142: 		        TaikoData.TierProof calldata _proof
143: 		    )
144: 		        external
145: 		        onlyFromNamed("taiko")
```

[[90-92](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L90-L92), [100-102](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L100-L102), [139-145](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L139-L145)]

```solidity
File: packages/protocol/contracts/L1/provers/Guardians.sol

53: 		    function setGuardians(
54: 		        address[] memory _newGuardians,
55: 		        uint8 _minGuardians
56: 		    )
57: 		        external
58: 		        onlyOwner
59: 		        nonReentrant
```

[[53-59](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L53-L59)]

```solidity
File: packages/protocol/contracts/team/airdrop/MerkleClaimable.sol

45: 		    function setConfig(
46: 		        uint64 _claimStart,
47: 		        uint64 _claimEnd,
48: 		        bytes32 _merkleRoot
49: 		    )
50: 		        external
51: 		        onlyOwner

56: 		    function __MerkleClaimable_init(
57: 		        uint64 _claimStart,
58: 		        uint64 _claimEnd,
59: 		        bytes32 _merkleRoot
60: 		    )
61: 		        internal
62: 		        onlyInitializing
```

[[45-51](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/MerkleClaimable.sol#L45-L51), [56-62](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/MerkleClaimable.sol#L56-L62)]

</details>

---

### [G-24] Caching global variables is more expensive than using the actual variable

It's better to not cache global variables, as their direct usage is cheaper (e.g. `msg.sender`).

_There is 1 instance of this issue._

```solidity
File: packages/protocol/contracts/L1/hooks/AssignmentHook.sol

93: 		        address taikoL1Address = msg.sender;
```

[[93](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L93)]

---

### [G-25] Add `unchecked` blocks for subtractions where the operands cannot underflow

There are some checks to avoid an underflow, so it's safe to use `unchecked` to have some gas savings.

_There are 7 instances of this issue._

<details>
<summary>Expand findings</summary>

```solidity
File: packages/protocol/contracts/L2/TaikoL2.sol

// @audit check on line 275
276: 		                numL1Blocks = _l1BlockId - lastSyncedBlock;
```

[[276](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L276)]

```solidity
File: packages/protocol/contracts/team/TimelockTokenPool.sol

// @audit check on line 257
264: 		        return _amount * uint64(block.timestamp - _start) / _period;
```

[[264](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L264)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol

// @audit check on line 262
265: 		        uint256 lengthDiff = n - expectedLength;
```

[[265](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L265)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol

// @audit check on line 90
93: 		                    mask = ~(2 ** (8 * (32 - shortest + idx)) - 1);
```

[[93](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L93)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/Bytes.sol

// @audit check on line 92
95: 		        return slice(_bytes, _start, _bytes.length - _start);
```

[[95](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/Bytes.sol#L95)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol

// @audit check on line 166
190: 		            uint256 lenOfStrLen = prefix - 0xb7;

// @audit check on line 223
236: 		            uint256 lenOfListLen = prefix - 0xf7;
```

[[190](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L190), [236](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L236)]

</details>

---

### [G-26] Add `unchecked` blocks for divisions where the operands cannot overflow

`uint` divisions can't overflow, while `int` divisions can overflow only in [one specific case](https://docs.soliditylang.org/en/latest/types.html#division).

Consider adding an `unchecked` block to have some [gas savings](https://gist.github.com/DadeKuma/3bc597338ae774b8b3bd43280d55271f).

_There are 13 instances of this issue._

<details>
<summary>Expand findings</summary>

```solidity
File: packages/protocol/contracts/L1/TaikoL1.sol

215: 		            ethDepositMaxFee: 1 ether / 10,
```

[[215](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoL1.sol#L215)]

```solidity
File: packages/protocol/contracts/L2/Lib1559Math.sol

28: 		        return _ethQty(_gasExcess, _adjustmentFactor) / LibFixedPointMath.SCALING_FACTOR
29: 		            / _adjustmentFactor;

28: 		        return _ethQty(_gasExcess, _adjustmentFactor) / LibFixedPointMath.SCALING_FACTOR

41: 		        uint256 input = _gasExcess * LibFixedPointMath.SCALING_FACTOR / _adjustmentFactor;
```

[[28-29](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/Lib1559Math.sol#L28-L29), [28](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/Lib1559Math.sol#L28), [41](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/Lib1559Math.sol#L41)]

```solidity
File: packages/protocol/contracts/team/TimelockTokenPool.sol

197: 		        uint128 _amountUnlocked = amountUnlocked / 1e18; // divide first

264: 		        return _amount * uint64(block.timestamp - _start) / _period;
```

[[197](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L197), [264](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L264)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol

359: 		                ? uint16(bytes2(svnValueBytes)) / 256
```

[[359](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L359)]

```solidity
File: packages/protocol/contracts/L1/gov/TaikoGovernor.sol

124: 		        return 1_000_000_000 ether / 10_000; // 0.01% of Taiko Token
```

[[124](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/gov/TaikoGovernor.sol#L124)]

```solidity
File: packages/protocol/contracts/L1/libs/LibVerifying.sol

262: 		                || _config.ethDepositMaxFee > type(uint96).max / _config.ethDepositMaxCountPerBlock
```

[[262](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L262)]

```solidity
File: packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol

117: 		        uint256 timeBasedAllowance = balance
118: 		            * (block.timestamp.min(claimEnd + withdrawalWindow) - claimEnd) / withdrawalWindow;
```

[[117-118](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol#L117-L118)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol

155: 		            uint256 upperDigit = digits / 16;
```

[[155](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol#L155)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol

39: 		            while (_len / i != 0) {

47: 		                out_[i] = bytes1(uint8((_len / (256 ** (lenLen - i))) % 256));
```

[[39](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol#L39), [47](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol#L47)]

</details>

---

### [G-27] Empty blocks should be removed or emit something

Some functions don't have a body: consider commenting why, or add some logic. Otherwise, refactor the code and remove these functions.

_There is 1 instance of this issue._

```solidity
File: packages/protocol/contracts/bridge/Bridge.sol

70: 		    receive() external payable { }
```

[[70](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L70)]

---

### [G-28] Usage of `uints`/`ints` smaller than 32 bytes (256 bits) incurs overhead

Citing the [documentation](https://docs.soliditylang.org/en/latest/internals/layout_in_storage.html):

> When using elements that are smaller than 32 bytes, your contract’s gas usage may be higher.This is because the EVM operates on 32 bytes at a time.Therefore, if the element is smaller than that, the EVM must use more operations in order to reduce the size of the element from 32 bytes to the desired size.

For example, each operation involving a `uint8` costs an extra ** 22 - 28 gas ** (depending on whether the other operand is also a variable of type `uint8`) as compared to ones involving`uint256`, due to the compiler having to clear the higher bits of the memory word before operating on the`uint8`, as well as the associated stack operations of doing so.

Note that it might be beneficial to use reduced-size types when dealing with storage values because the compiler will pack multiple elements into one storage slot, but if not, it will have the opposite effect.

_There are 322 instances of this issue._

<details>
<summary>Expand findings</summary>

```solidity
File: packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol

36: 		    uint8 internal constant INVALID_EXIT_CODE = 255;
```

[[36](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L36)]

```solidity
File: packages/protocol/contracts/bridge/Bridge.sol

31: 		    uint128 public nextMessageId;

64: 		    modifier sameChain(uint64 _chainId) {

89: 		        uint64 _timestamp = _suspend ? type(uint64).max : uint64(block.timestamp);

168: 		        uint64 receivedAt = proofReceipt[msgHash].receivedAt;

230: 		        uint64 receivedAt = proofReceipt[msgHash].receivedAt;

392: 		    function isDestChainEnabled(uint64 _chainId)

541: 		    function _storeContext(bytes32 _msgHash, address _from, uint64 _srcChainId) private {

559: 		            uint64 srcChainId;

580: 		        uint64 _chainId,
```

[[31](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L31), [64](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L64), [89](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L89), [168](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L168), [230](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L230), [392](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L392), [541](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L541), [559](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L559), [580](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L580)]

```solidity
File: packages/protocol/contracts/bridge/IBridge.sol

19: 		        uint128 id;

24: 		        uint64 srcChainId;

26: 		        uint64 destChainId;

51: 		        uint64 receivedAt;

63: 		        uint64 srcChainId; // Source chain ID.
```

[[19](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/IBridge.sol#L19), [24](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/IBridge.sol#L24), [26](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/IBridge.sol#L26), [51](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/IBridge.sol#L51), [63](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/IBridge.sol#L63)]

```solidity
File: packages/protocol/contracts/common/DefaultResolver.sol

22: 		        uint64 indexed chainId, bytes32 indexed name, address newAddress, address oldAddress

39: 		        uint64 _chainId,

54: 		    function getAddress(uint64 _chainId, bytes32 _name) public view override returns (address) {
```

[[22](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/DefaultResolver.sol#L22), [39](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/DefaultResolver.sol#L39), [54](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/DefaultResolver.sol#L54)]

```solidity
File: packages/protocol/contracts/common/AddressResolver.sol

19: 		    error RESOLVER_ZERO_ADDR(uint64 chainId, bytes32 name);

44: 		        uint64 _chainId,

73: 		        uint64 _chainId,
```

[[19](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/AddressResolver.sol#L19), [44](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/AddressResolver.sol#L44), [73](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/AddressResolver.sol#L73)]

```solidity
File: packages/protocol/contracts/common/EssentialContract.sol

11: 		    uint8 private constant _FALSE = 1;

13: 		    uint8 private constant _TRUE = 2;

21: 		    uint8 private __reentry;

23: 		    uint8 private __paused;

119: 		    function _storeReentryLock(uint8 _reentry) internal virtual {

130: 		    function _loadReentryLock() internal view virtual returns (uint8 reentry_) {
```

[[11](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/EssentialContract.sol#L11), [13](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/EssentialContract.sol#L13), [21](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/EssentialContract.sol#L21), [23](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/EssentialContract.sol#L23), [119](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/EssentialContract.sol#L119), [130](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/EssentialContract.sol#L130)]

```solidity
File: packages/protocol/contracts/common/IDefaultResolver.sol

14: 		    function getAddress(uint64 _chainId, bytes32 _name) external view returns (address);
```

[[14](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/IDefaultResolver.sol#L14)]

```solidity
File: packages/protocol/contracts/common/IAddressResolver.sol

35: 		        uint64 _chainId,
```

[[35](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/IAddressResolver.sol#L35)]

```solidity
File: packages/protocol/contracts/L1/ITaikoL1.sol

27: 		    function proveBlock(uint64 _blockId, bytes calldata _input) external;

31: 		    function verifyBlocks(uint64 _maxBlocksToVerify) external;
```

[[27](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/ITaikoL1.sol#L27), [31](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/ITaikoL1.sol#L31)]

```solidity
File: packages/protocol/contracts/L1/TaikoData.sol

15: 		        uint64 chainId;

20: 		        uint64 blockMaxProposals;

22: 		        uint64 blockRingBufferSize;

24: 		        uint64 maxBlocksToVerifyPerProposal;

26: 		        uint32 blockMaxGasLimit;

28: 		        uint24 blockMaxTxListBytes;

30: 		        uint24 blobExpiry;

39: 		        uint96 livenessBond;

46: 		        uint64 ethDepositMinCountPerBlock;

48: 		        uint64 ethDepositMaxCountPerBlock;

50: 		        uint96 ethDepositMinAmount;

52: 		        uint96 ethDepositMaxAmount;

59: 		        uint8 blockSyncThreshold;

64: 		        uint16 tier;

65: 		        uint128 fee;

69: 		        uint16 tier;

83: 		        uint24 txListByteOffset;

84: 		        uint24 txListByteSize;

101: 		        uint64 id;

102: 		        uint32 gasLimit;

103: 		        uint64 timestamp; // slot 7

104: 		        uint64 l1Height;

105: 		        uint24 txListByteOffset;

106: 		        uint24 txListByteSize;

107: 		        uint16 minTier;

127: 		        uint96 validityBond;

129: 		        uint96 contestBond;

130: 		        uint64 timestamp; // slot 6 (90 bits)

131: 		        uint16 tier;

132: 		        uint8 contestations;

140: 		        uint96 livenessBond;

141: 		        uint64 blockId; // slot 3

142: 		        uint64 proposedAt; // timestamp

143: 		        uint64 proposedIn; // L1 block number

144: 		        uint32 nextTransitionId;

145: 		        uint32 verifiedTransitionId;

152: 		        uint96 amount;

153: 		        uint64 id;

162: 		        uint64 genesisHeight;

163: 		        uint64 genesisTimestamp;

164: 		        uint64 numEthDeposits;

165: 		        uint64 nextEthDepositToProcess;

169: 		        uint64 numBlocks;

170: 		        uint64 lastVerifiedBlockId;

172: 		        uint8 __reserved1;

173: 		        uint16 __reserved2;

174: 		        uint32 __reserved3;

175: 		        uint64 lastUnpausedAt;
```

[[15](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L15), [20](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L20), [22](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L22), [24](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L24), [26](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L26), [28](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L28), [30](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L30), [39](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L39), [46](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L46), [48](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L48), [50](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L50), [52](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L52), [59](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L59), [64](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L64), [65](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L65), [69](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L69), [83](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L83), [84](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L84), [101](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L101), [102](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L102), [103](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L103), [104](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L104), [105](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L105), [106](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L106), [107](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L107), [127](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L127), [129](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L129), [130](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L130), [131](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L131), [132](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L132), [140](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L140), [141](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L141), [142](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L142), [143](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L143), [144](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L144), [145](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L145), [152](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L152), [153](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L153), [162](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L162), [163](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L163), [164](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L164), [165](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L165), [169](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L169), [170](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L170), [172](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L172), [173](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L173), [174](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L174), [175](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L175)]

```solidity
File: packages/protocol/contracts/L1/TaikoEvents.sol

24: 		        uint96 livenessBond,

43: 		        uint16 tier,

44: 		        uint8 contestations

57: 		        uint96 validityBond,

58: 		        uint16 tier

71: 		        uint96 contestBond,

72: 		        uint16 tier
```

[[24](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoEvents.sol#L24), [43](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoEvents.sol#L43), [44](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoEvents.sol#L44), [57](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoEvents.sol#L57), [58](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoEvents.sol#L58), [71](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoEvents.sol#L71), [72](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoEvents.sol#L72)]

```solidity
File: packages/protocol/contracts/L1/TaikoL1.sol

76: 		        uint64 _blockId,

94: 		        uint8 maxBlocksToVerify = LibProving.proveBlock(state, config, this, meta, tran, proof);

100: 		    function verifyBlocks(uint64 _maxBlocksToVerify)

145: 		    function getBlock(uint64 _blockId)

150: 		        uint64 slot;

163: 		        uint64 _blockId,
```

[[76](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoL1.sol#L76), [94](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoL1.sol#L94), [100](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoL1.sol#L100), [145](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoL1.sol#L145), [150](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoL1.sol#L150), [163](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoL1.sol#L163)]

```solidity
File: packages/protocol/contracts/L2/CrossChainOwned.sol

16: 		    uint64 public ownerChainId;

19: 		    uint64 public nextTxId;

26: 		    event TransactionExecuted(uint64 indexed txId, bytes4 indexed selector);

42: 		        (uint64 txId, bytes memory txdata) = abi.decode(_data, (uint64, bytes));

63: 		        uint64 _ownerChainId
```

[[16](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/CrossChainOwned.sol#L16), [19](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/CrossChainOwned.sol#L19), [26](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/CrossChainOwned.sol#L26), [42](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/CrossChainOwned.sol#L42), [63](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/CrossChainOwned.sol#L63)]

```solidity
File: packages/protocol/contracts/L2/TaikoL2.sol

27: 		        uint32 gasTargetPerL1Block;

28: 		        uint8 basefeeAdjustmentQuotient;

35: 		    uint8 public constant BLOCK_SYNC_THRESHOLD = 5;

47: 		    uint64 public gasExcess;

50: 		    uint64 public lastSyncedBlock;

57: 		    event Anchored(bytes32 parentHash, uint64 gasExcess);

74: 		        uint64 _l1ChainId,

75: 		        uint64 _gasExcess

110: 		        uint64 _l1BlockId,

111: 		        uint32 _parentGasUsed

186: 		        uint64 _l1BlockId,

187: 		        uint32 _parentGasUsed

200: 		    function getBlockHash(uint64 _blockId) public view returns (bytes32) {

254: 		        uint64 _l1BlockId,

255: 		        uint32 _parentGasUsed

259: 		        returns (uint256 basefee_, uint64 gasExcess_)
```

[[27](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L27), [28](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L28), [35](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L35), [47](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L47), [50](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L50), [57](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L57), [74](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L74), [75](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L75), [110](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L110), [111](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L111), [186](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L186), [187](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L187), [200](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L200), [254](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L254), [255](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L255), [259](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L259)]

```solidity
File: packages/protocol/contracts/L2/TaikoL2EIP1559Configurable.sol

18: 		    event ConfigAndExcessChanged(Config config, uint64 gasExcess);

27: 		        uint64 _newGasExcess
```

[[18](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2EIP1559Configurable.sol#L18), [27](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2EIP1559Configurable.sol#L27)]

```solidity
File: packages/protocol/contracts/libs/Lib4844.sol

13: 		    uint32 public constant FIELD_ELEMENTS_PER_BLOB = 4096;
```

[[13](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/libs/Lib4844.sol#L13)]

```solidity
File: packages/protocol/contracts/signal/ISignalService.sol

21: 		        uint64 chainId;

22: 		        uint64 blockId;

37: 		        uint64 indexed chainId,

38: 		        uint64 indexed blockId,

69: 		        uint64 _chainId,

71: 		        uint64 _blockId,

85: 		        uint64 _chainId,

106: 		        uint64 _chainId,

108: 		        uint64 _blockId,

123: 		        uint64 _chainId,

125: 		        uint64 _blockId

129: 		        returns (uint64 blockId_, bytes32 chainData_);

138: 		        uint64 _chainId,

140: 		        uint64 _blockId
```

[[21](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/ISignalService.sol#L21), [22](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/ISignalService.sol#L22), [37](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/ISignalService.sol#L37), [38](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/ISignalService.sol#L38), [69](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/ISignalService.sol#L69), [71](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/ISignalService.sol#L71), [85](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/ISignalService.sol#L85), [106](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/ISignalService.sol#L106), [108](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/ISignalService.sol#L108), [123](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/ISignalService.sol#L123), [125](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/ISignalService.sol#L125), [129](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/ISignalService.sol#L129), [138](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/ISignalService.sol#L138), [140](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/ISignalService.sol#L140)]

```solidity
File: packages/protocol/contracts/signal/SignalService.sol

69: 		        uint64 _chainId,

71: 		        uint64 _blockId,

84: 		        uint64 _chainId,

97: 		        uint64 chainId = _chainId;

138: 		        uint64 _chainId,

140: 		        uint64 _blockId,

159: 		        uint64 _chainId,

161: 		        uint64 _blockId

165: 		        returns (uint64 blockId_, bytes32 chainData_)

178: 		        uint64 _chainId,

180: 		        uint64 _blockId

195: 		        uint64 _chainId,

207: 		        uint64 _chainId,

236: 		        uint64 _chainId,

238: 		        uint64 _blockId,

273: 		        uint64 _chainId,

274: 		        uint64 _blockId,
```

[[69](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L69), [71](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L71), [84](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L84), [97](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L97), [138](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L138), [140](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L140), [159](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L159), [161](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L161), [165](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L165), [178](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L178), [180](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L180), [195](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L195), [207](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L207), [236](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L236), [238](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L238), [273](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L273), [274](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L274)]

```solidity
File: packages/protocol/contracts/team/TimelockTokenPool.sol

29: 		        uint128 amount;

31: 		        uint128 costPerToken;

34: 		        uint64 grantStart;

37: 		        uint64 grantCliff;

40: 		        uint32 grantPeriod;

43: 		        uint64 unlockStart;

46: 		        uint64 unlockCliff;

49: 		        uint32 unlockPeriod;

53: 		        uint128 amountWithdrawn;

54: 		        uint128 costPaid;

68: 		    uint128 public totalAmountGranted;

71: 		    uint128 public totalAmountVoided;

74: 		    uint128 public totalAmountWithdrawn;

77: 		    uint128 public totalCostPaid;

92: 		    event Voided(address indexed recipient, uint128 amount);

99: 		    event Withdrawn(address indexed recipient, address to, uint128 amount, uint128 cost);

99: 		    event Withdrawn(address indexed recipient, address to, uint128 amount, uint128 cost);

152: 		        uint128 amountVoided = _voidGrant(r.grant);

180: 		            uint128 amountOwned,

181: 		            uint128 amountUnlocked,

182: 		            uint128 amountWithdrawn,

183: 		            uint128 amountToWithdraw,

184: 		            uint128 costToWithdraw

197: 		        uint128 _amountUnlocked = amountUnlocked / 1e18; // divide first

211: 		        (,,, uint128 amountToWithdraw, uint128 costToWithdraw) = getMyGrantSummary(_recipient);

211: 		        (,,, uint128 amountToWithdraw, uint128 costToWithdraw) = getMyGrantSummary(_recipient);

225: 		    function _voidGrant(Grant storage _grant) private returns (uint128 amountVoided) {

226: 		        uint128 amountOwned = _getAmountOwned(_grant);

235: 		    function _getAmountOwned(Grant memory _grant) private view returns (uint128) {

239: 		    function _getAmountUnlocked(Grant memory _grant) private view returns (uint128) {

246: 		        uint128 _amount,

247: 		        uint64 _start,

248: 		        uint64 _cliff,

249: 		        uint64 _period

253: 		        returns (uint128)

273: 		    function _validateCliff(uint64 _start, uint64 _cliff, uint32 _period) private pure {

273: 		    function _validateCliff(uint64 _start, uint64 _cliff, uint32 _period) private pure {

273: 		    function _validateCliff(uint64 _start, uint64 _cliff, uint32 _period) private pure {
```

[[29](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L29), [31](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L31), [34](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L34), [37](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L37), [40](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L40), [43](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L43), [46](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L46), [49](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L49), [53](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L53), [54](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L54), [68](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L68), [71](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L71), [74](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L74), [77](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L77), [92](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L92), [99](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L99), [99](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L99), [152](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L152), [180](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L180), [181](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L181), [182](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L182), [183](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L183), [184](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L184), [197](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L197), [211](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L211), [211](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L211), [225](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L225), [226](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L226), [235](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L235), [239](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L239), [246](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L246), [247](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L247), [248](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L248), [249](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L249), [253](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L253), [273](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L273), [273](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L273), [273](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L273)]

```solidity
File: packages/protocol/contracts/tokenvault/BaseNFTVault.sol

13: 		        uint64 chainId;

25: 		        uint64 destChainId;

70: 		        uint64 indexed chainId,

90: 		        uint64 destChainId,

126: 		        uint64 srcChainId,
```

[[13](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BaseNFTVault.sol#L13), [25](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BaseNFTVault.sol#L25), [70](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BaseNFTVault.sol#L70), [90](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BaseNFTVault.sol#L90), [126](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BaseNFTVault.sol#L126)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC20.sol

24: 		    uint8 private __srcDecimals;

57: 		        uint8 _decimals,

117: 		        returns (uint8)
```

[[24](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20.sol#L24), [57](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20.sol#L57), [117](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20.sol#L117)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC20Vault.sol

24: 		        uint64 chainId;

26: 		        uint8 decimals;

33: 		        uint64 destChainId;

69: 		        uint8 ctokenDecimal

87: 		        uint8 ctokenDecimal

102: 		        uint64 destChainId,

130: 		        uint64 srcChainId,
```

[[24](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L24), [26](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L26), [33](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L33), [69](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L69), [87](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L87), [102](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L102), [130](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L130)]

```solidity
File: packages/protocol/contracts/verifiers/IVerifier.sol

14: 		        uint64 blockId;
```

[[14](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/IVerifier.sol#L14)]

```solidity
File: packages/protocol/contracts/verifiers/SgxVerifier.sol

26: 		        uint64 validSince;

30: 		    uint64 public constant INSTANCE_EXPIRY = 180 days;

34: 		    uint64 public constant INSTANCE_VALIDITY_DELAY = 1 days;

154: 		        uint32 id = uint32(bytes4(Bytes.slice(_proof.data, 0, 4)));

204: 		        uint64 validSince = uint64(block.timestamp);
```

[[26](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L26), [30](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L30), [34](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L34), [154](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L154), [204](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L204)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/EnclaveIdStruct.sol

10: 		        uint16 isvprodid;

23: 		        uint16 isvsvn;
```

[[10](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/EnclaveIdStruct.sol#L10), [23](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/EnclaveIdStruct.sol#L23)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol

358: 		            uint16 svnValue = svnValueBytes.length < 2
```

[[358](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L358)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/Asn1Decode.sol

189: 		        uint80 ixFirstContentByte;

190: 		        uint80 ixLastContentByte;

196: 		            uint8 lengthbytesLength = uint8(der[ix + 1] & 0x7F);
```

[[189](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/Asn1Decode.sol#L189), [190](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/Asn1Decode.sol#L190), [196](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/Asn1Decode.sol#L196)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol

188: 		    function readUint8(bytes memory self, uint256 idx) internal pure returns (uint8 ret) {

198: 		    function readUint16(bytes memory self, uint256 idx) internal pure returns (uint16 ret) {

211: 		    function readUint32(bytes memory self, uint256 idx) internal pure returns (uint32 ret) {

332: 		        uint8 decoded;
```

[[188](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L188), [198](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L198), [211](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L211), [332](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L332)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol

9: 		        uint16 yrs;

10: 		        uint8 mnths;

11: 		        uint8 dys;

12: 		        uint8 hrs;

13: 		        uint8 mins;

14: 		        uint8 secs;

15: 		        uint8 offset;

35: 		        uint16 year,

36: 		        uint8 month,

37: 		        uint8 day,

38: 		        uint8 hour,

39: 		        uint8 minute,

40: 		        uint8 second

48: 		        for (uint16 i = 1970; i < year; ++i) {

59: 		        for (uint8 i = 1; i < month; ++i) {

71: 		    function isLeapYear(uint16 year) internal pure returns (bool) {
```

[[9](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol#L9), [10](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol#L10), [11](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol#L11), [12](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol#L12), [13](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol#L13), [14](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol#L14), [15](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol#L15), [35](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol#L35), [36](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol#L36), [37](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol#L37), [38](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol#L38), [39](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol#L39), [40](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol#L40), [48](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol#L48), [59](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol#L59), [71](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol#L71)]

```solidity
File: packages/protocol/contracts/L1/hooks/AssignmentHook.sol

20: 		        uint64 expiry;

21: 		        uint64 maxBlockId;

22: 		        uint64 maxProposedIn;

166: 		        uint16 _tierId
```

[[20](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L20), [21](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L21), [22](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L22), [166](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L166)]

```solidity
File: packages/protocol/contracts/L1/libs/LibDepositing.sol

83: 		            uint96 fee = uint96(_config.ethDepositMaxFee.min(block.basefee * _config.ethDepositGas));

84: 		            uint64 j = _state.slotA.nextEthDepositToProcess;

85: 		            uint96 totalFee;

93: 		                uint96 _fee = deposits_[i].amount > fee ? fee : deposits_[i].amount;
```

[[83](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibDepositing.sol#L83), [84](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibDepositing.sol#L84), [85](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibDepositing.sol#L85), [93](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibDepositing.sol#L93)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProposing.sol

34: 		        uint96 livenessBond,
```

[[34](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L34)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProving.sol

36: 		        uint96 validityBond,

37: 		        uint16 tier

50: 		        uint96 contestBond,

51: 		        uint16 tier

100: 		        returns (uint8 maxBlocksToVerify_)

115: 		        uint64 slot = _meta.id % _config.blockRingBufferSize;

129: 		        (uint32 tid, TaikoData.TransitionState storage ts) =

273: 		        uint64 slot

276: 		        returns (uint32 tid_, TaikoData.TransitionState storage ts_)

405: 		        uint32 _tid,
```

[[36](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L36), [37](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L37), [50](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L50), [51](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L51), [100](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L100), [115](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L115), [129](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L129), [273](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L273), [276](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L276), [405](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L405)]

```solidity
File: packages/protocol/contracts/L1/libs/LibUtils.sol

26: 		        uint64 _blockId,

38: 		        uint64 slot = _blockId % _config.blockRingBufferSize;

42: 		        uint32 tid = getTransitionId(_state, blk, slot, _parentHash);

55: 		        uint64 _blockId

59: 		        returns (TaikoData.Block storage blk_, uint64 slot_)

73: 		        uint64 _slot,

78: 		        returns (uint32 tid_)
```

[[26](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibUtils.sol#L26), [38](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibUtils.sol#L38), [42](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibUtils.sol#L42), [55](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibUtils.sol#L55), [59](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibUtils.sol#L59), [73](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibUtils.sol#L73), [78](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibUtils.sol#L78)]

```solidity
File: packages/protocol/contracts/L1/libs/LibVerifying.sol

34: 		        uint16 tier,

35: 		        uint8 contestations

89: 		        uint64 _maxBlocksToVerify

100: 		        uint64 blockId = b.lastVerifiedBlockId;

102: 		        uint64 slot = blockId % _config.blockRingBufferSize;

107: 		        uint32 tid = blk.verifiedTransitionId;

117: 		        uint64 numBlocksVerified;

213: 		                uint64 lastVerifiedBlockId = b.lastVerifiedBlockId + numBlocksVerified;

227: 		        uint64 _lastVerifiedBlockId,

234: 		        (uint64 lastSyncedBlock,) = signalService.getSyncedChainData(
```

[[34](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L34), [35](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L35), [89](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L89), [100](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L100), [102](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L102), [107](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L107), [117](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L117), [213](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L213), [227](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L227), [234](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L234)]

```solidity
File: packages/protocol/contracts/L1/provers/Guardians.sol

27: 		    uint32 public version;

30: 		    uint32 public minGuardians;

37: 		    event GuardiansUpdated(uint32 version, address[] guardians);

55: 		        uint8 _minGuardians
```

[[27](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L27), [30](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L30), [37](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L37), [55](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L55)]

```solidity
File: packages/protocol/contracts/L1/tiers/DevnetTierProvider.sol

20: 		    function getTier(uint16 _tierId) public pure override returns (ITierProvider.Tier memory) {

54: 		    function getMinTier(uint256) public pure override returns (uint16) {
```

[[20](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/tiers/DevnetTierProvider.sol#L20), [54](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/tiers/DevnetTierProvider.sol#L54)]

```solidity
File: packages/protocol/contracts/L1/tiers/ITierProvider.sol

10: 		        uint96 validityBond;

11: 		        uint96 contestBond;

12: 		        uint24 cooldownWindow; // in minutes

13: 		        uint16 provingWindow; // in minutes

14: 		        uint8 maxBlocksToVerifyPerProof;

22: 		    function getTier(uint16 tierId) external view returns (Tier memory);

33: 		    function getMinTier(uint256 rand) external view returns (uint16);

39: 		    uint16 public constant TIER_OPTIMISTIC = 100;

42: 		    uint16 public constant TIER_SGX = 200;

45: 		    uint16 public constant TIER_SGX_ZKVM = 300;

48: 		    uint16 public constant TIER_GUARDIAN = 1000;
```

[[10](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/tiers/ITierProvider.sol#L10), [11](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/tiers/ITierProvider.sol#L11), [12](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/tiers/ITierProvider.sol#L12), [13](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/tiers/ITierProvider.sol#L13), [14](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/tiers/ITierProvider.sol#L14), [22](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/tiers/ITierProvider.sol#L22), [33](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/tiers/ITierProvider.sol#L33), [39](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/tiers/ITierProvider.sol#L39), [42](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/tiers/ITierProvider.sol#L42), [45](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/tiers/ITierProvider.sol#L45), [48](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/tiers/ITierProvider.sol#L48)]

```solidity
File: packages/protocol/contracts/L1/tiers/MainnetTierProvider.sol

20: 		    function getTier(uint16 _tierId) public pure override returns (ITierProvider.Tier memory) {

66: 		    function getMinTier(uint256 _rand) public pure override returns (uint16) {
```

[[20](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/tiers/MainnetTierProvider.sol#L20), [66](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/tiers/MainnetTierProvider.sol#L66)]

```solidity
File: packages/protocol/contracts/L1/tiers/TestnetTierProvider.sol

20: 		    function getTier(uint16 _tierId) public pure override returns (ITierProvider.Tier memory) {

66: 		    function getMinTier(uint256 _rand) public pure override returns (uint16) {
```

[[20](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/tiers/TestnetTierProvider.sol#L20), [66](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/tiers/TestnetTierProvider.sol#L66)]

```solidity
File: packages/protocol/contracts/team/airdrop/ERC20Airdrop.sol

29: 		        uint64 _claimStart,

30: 		        uint64 _claimEnd,

69: 		        (address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) =
```

[[29](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC20Airdrop.sol#L29), [30](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC20Airdrop.sol#L30), [69](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC20Airdrop.sol#L69)]

```solidity
File: packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol

28: 		    uint64 public withdrawalWindow;

56: 		        uint64 _claimStart,

57: 		        uint64 _claimEnd,

61: 		        uint64 _withdrawalWindow
```

[[28](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol#L28), [56](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol#L56), [57](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol#L57), [61](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol#L61)]

```solidity
File: packages/protocol/contracts/team/airdrop/ERC721Airdrop.sol

27: 		        uint64 _claimStart,

28: 		        uint64 _claimEnd,
```

[[27](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC721Airdrop.sol#L27), [28](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC721Airdrop.sol#L28)]

```solidity
File: packages/protocol/contracts/team/airdrop/MerkleClaimable.sol

18: 		    uint64 public claimStart;

21: 		    uint64 public claimEnd;

46: 		        uint64 _claimStart,

47: 		        uint64 _claimEnd,

57: 		        uint64 _claimStart,

58: 		        uint64 _claimEnd,

90: 		    function _setConfig(uint64 _claimStart, uint64 _claimEnd, bytes32 _merkleRoot) private {

90: 		    function _setConfig(uint64 _claimStart, uint64 _claimEnd, bytes32 _merkleRoot) private {
```

[[18](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/MerkleClaimable.sol#L18), [21](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/MerkleClaimable.sol#L21), [46](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/MerkleClaimable.sol#L46), [47](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/MerkleClaimable.sol#L47), [57](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/MerkleClaimable.sol#L57), [58](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/MerkleClaimable.sol#L58), [90](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/MerkleClaimable.sol#L90), [90](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/MerkleClaimable.sol#L90)]

```solidity
File: packages/protocol/contracts/thirdparty/nomad-xyz/ExcessivelySafeCall.sol

29: 		        uint16 _maxCopy,
```

[[29](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/nomad-xyz/ExcessivelySafeCall.sol#L29)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol

106: 		        uint32 totalQuoteSize = 48 // header

249: 		        uint16 isvProdIdPackBE = (enclaveReport.isvProdId >> 8) | (enclaveReport.isvProdId << 8);

250: 		        uint16 isvSvnPackBE = (enclaveReport.isvSvn >> 8) | (enclaveReport.isvSvn << 8);
```

[[106](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol#L106), [249](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol#L249), [250](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol#L250)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Struct.sol

26: 		        uint16 isvProdId;

27: 		        uint16 isvSvn;

34: 		        uint16 parsedDataSize;

39: 		        uint16 certType;

43: 		        uint32 certDataSize;
```

[[26](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Struct.sol#L26), [27](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Struct.sol#L27), [34](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Struct.sol#L34), [39](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Struct.sol#L39), [43](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Struct.sol#L43)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol

30: 		    uint8 internal constant PREFIX_EXTENSION_EVEN = 0;

33: 		    uint8 internal constant PREFIX_EXTENSION_ODD = 1;

36: 		    uint8 internal constant PREFIX_LEAF_EVEN = 2;

39: 		    uint8 internal constant PREFIX_LEAF_ODD = 3;

134: 		                    uint8 branchKey = uint8(key[currentKeyIndex]);

141: 		                uint8 prefix = uint8(path[0]);

142: 		                uint8 offset = 2 - (prefix % 2);
```

[[30](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L30), [33](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L33), [36](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L36), [39](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L39), [134](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L134), [141](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L141), [142](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L142)]

</details>

---

### [G-29] Stack variable cost less while used in emitting event

Using a stack variable instead of a state variable is cheaper when emitting an event.

_There are 7 instances of this issue._

```solidity
File: packages/protocol/contracts/L2/CrossChainOwned.sol

// @audit nextTxId++
53: 		        emit TransactionExecuted(nextTxId++, bytes4(txdata));
```

[[53](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/CrossChainOwned.sol#L53)]

```solidity
File: packages/protocol/contracts/L2/TaikoL2.sol

// @audit gasExcess
157: 		        emit Anchored(blockhash(parentId), gasExcess);
```

[[157](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L157)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC20Base.sol

// @audit migratingAddress
63: 		            emit MigratedTo(migratingAddress, _account, _amount);

// @audit migratingAddress
80: 		            emit MigratedTo(migratingAddress, _account, _amount);
```

[[63](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20Base.sol#L63), [80](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20Base.sol#L80)]

```solidity
File: packages/protocol/contracts/verifiers/SgxVerifier.sol

// @audit instances[idx].addr
109: 		            emit InstanceDeleted(idx, instances[idx].addr);

// @audit nextInstanceId
220: 		            emit InstanceAdded(nextInstanceId, _instances[i], address(0), validSince);
```

[[109](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L109), [220](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L220)]

```solidity
File: packages/protocol/contracts/L1/provers/Guardians.sol

// @audit version
95: 		        emit GuardiansUpdated(version, _newGuardians);
```

[[95](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L95)]

---

### [G-30] Redundant `event` fields can be removed

Some parameters (`block.timestamp` and `block.number`) are added to event information by default so re-adding them wastes gas, as they are already included.

_There is 1 instance of this issue._

```solidity
File: packages/protocol/contracts/verifiers/SgxVerifier.sol

230: 		        emit InstanceAdded(id, newInstance, oldInstance, block.timestamp);
```

[[230](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L230)]

---

### [G-31] Using pre instead of post increments/decrements

Pre increments/decrements (`++i/--i`) are cheaper than post increments/decrements (`i++/i--`): it saves 6 gas per expression.

_There are 7 instances of this issue._

```solidity
File: packages/protocol/contracts/verifiers/SgxVerifier.sol

222: 		            nextInstanceId++;
```

[[222](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L222)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol

46: 		            for (i = 1; i <= lenLen; i++) {

59: 		        for (; i < 32; i++) {

66: 		        for (uint256 j = 0; j < out_.length; j++) {

67: 		            out_[j] = b[i++];

40: 		                lenLen++;
```

[[46](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol#L46), [59](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol#L59), [66](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol#L66), [67](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol#L67), [40](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol#L40)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol

85: 		        for (uint256 i = 0; i < proof.length; i++) {
```

[[85](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L85)]

---

### [G-32] `>=`/`<=` costs less gas than `>`/`<`

The compiler uses opcodes `GT` and `ISZERO` for code that uses `>`, but only requires `LT` for `>=`. A similar behaviour applies for `>`, which uses opcodes `LT` and `ISZERO`, but only requires `GT` for `<=`.

_There are 130 instances of this issue._

<details>
<summary>Expand findings</summary>

```solidity
File: packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol

80: 		        for (uint256 i; i < serialNumBatch.length; ++i) {

95: 		        for (uint256 i; i < serialNumBatch.length; ++i) {

191: 		        for (uint256 i; i < enclaveId.tcbLevels.length; ++i) {

214: 		        for (uint256 i; i < tcb.tcbLevels.length; ++i) {

240: 		        for (uint256 i; i < CPUSVN_LENGTH; ++i) {

241: 		            if (pckCpuSvns[i] < tcbCpuSvns[i]) {

259: 		        for (uint256 i; i < n; ++i) {

280: 		                block.timestamp > certs[i].notBefore && block.timestamp < certs[i].notAfter;

280: 		                block.timestamp > certs[i].notBefore && block.timestamp < certs[i].notAfter;

420: 		            for (uint256 i; i < 3; ++i) {
```

[[80](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L80), [95](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L95), [191](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L191), [214](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L214), [240](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L240), [241](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L241), [259](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L259), [280](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L280), [280](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L280), [420](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L420)]

```solidity
File: packages/protocol/contracts/bridge/Bridge.sol

90: 		        for (uint256 i; i < _msgHashes.length; ++i) {
```

[[90](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L90)]

```solidity
File: packages/protocol/contracts/common/AddressResolver.sol

59: 		        if (block.chainid > type(uint64).max) {
```

[[59](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/AddressResolver.sol#L59)]

```solidity
File: packages/protocol/contracts/L2/Lib1559Math.sol

42: 		        if (input > LibFixedPointMath.MAX_EXP_INPUT) {
```

[[42](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/Lib1559Math.sol#L42)]

```solidity
File: packages/protocol/contracts/L2/TaikoL2.sol

82: 		        if (block.chainid <= 1 || block.chainid > type(uint64).max) {

145: 		        if (_l1BlockId > lastSyncedBlock + BLOCK_SYNC_THRESHOLD) {

234: 		            for (uint256 i; i < 255 && _blockId >= i + 1; ++i) {

262: 		        if (gasExcess > 0) {

275: 		            if (lastSyncedBlock > 0 && _l1BlockId > lastSyncedBlock) {

275: 		            if (lastSyncedBlock > 0 && _l1BlockId > lastSyncedBlock) {

279: 		            if (numL1Blocks > 0) {

281: 		                excess = excess > issuance ? excess - issuance : 1;
```

[[82](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L82), [145](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L145), [234](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L234), [262](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L262), [275](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L275), [275](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L275), [279](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L279), [281](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L281)]

```solidity
File: packages/protocol/contracts/libs/LibMath.sol

13: 		        return _a > _b ? _b : _a;

21: 		        return _a > _b ? _a : _b;
```

[[13](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/libs/LibMath.sol#L13), [21](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/libs/LibMath.sol#L21)]

```solidity
File: packages/protocol/contracts/signal/SignalService.sol

104: 		        for (uint256 i; i < hopProofs.length; ++i) {

120: 		            bool isFullProof = hop.accountProof.length > 0;

247: 		        if (topBlockId[_chainId][_kind] < _blockId) {
```

[[104](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L104), [120](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L120), [247](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L247)]

```solidity
File: packages/protocol/contracts/team/TimelockTokenPool.sol

275: 		            if (_cliff > 0) revert INVALID_GRANT();

277: 		            if (_cliff > 0 && _cliff <= _start) revert INVALID_GRANT();
```

[[275](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L275), [277](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L277)]

```solidity
File: packages/protocol/contracts/tokenvault/BaseNFTVault.sol

145: 		        if (_op.tokenIds.length > MAX_TOKEN_PER_TXN) {
```

[[145](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BaseNFTVault.sol#L145)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC1155Vault.sol

47: 		        for (uint256 i; i < _op.amounts.length; ++i) {

251: 		                for (uint256 i; i < _op.tokenIds.length; ++i) {

269: 		                for (uint256 i; i < _op.tokenIds.length; ++i) {
```

[[47](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L47), [251](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L251), [269](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L269)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC721Vault.sol

34: 		        for (uint256 i; i < _op.tokenIds.length; ++i) {

170: 		            for (uint256 i; i < _tokenIds.length; ++i) {

175: 		            for (uint256 i; i < _tokenIds.length; ++i) {

197: 		                for (uint256 i; i < _op.tokenIds.length; ++i) {

210: 		                for (uint256 i; i < _op.tokenIds.length; ++i) {
```

[[34](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L34), [170](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L170), [175](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L175), [197](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L197), [210](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L210)]

```solidity
File: packages/protocol/contracts/verifiers/SgxVerifier.sol

104: 		        for (uint256 i; i < _ids.length; ++i) {

210: 		        for (uint256 i; i < _instances.length; ++i) {
```

[[104](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L104), [210](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L210)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol

54: 		        for (uint256 i; i < size; ++i) {

56: 		            if (i > 0) {

244: 		        for (uint256 i; i < split.length; ++i) {

323: 		                    if (extnValuePtr.ixl() < extnValueParentPtr.ixl()) {

333: 		            if (tbsPtr.ixl() < tbsParentPtr.ixl()) {

354: 		        for (uint256 i; i < SGX_TCB_CPUSVN_SIZE + 1; ++i) {

358: 		            uint16 svnValue = svnValueBytes.length < 2
```

[[54](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L54), [56](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L56), [244](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L244), [323](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L323), [333](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L333), [354](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L354), [358](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L358)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol

69: 		        if (otherlen < len) {

80: 		        for (uint256 idx = 0; idx < shortest; idx += 32) {

90: 		                if (shortest > 32) {

333: 		        for (uint256 i; i < len; ++i) {
```

[[69](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L69), [80](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L80), [90](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L90), [333](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L333)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol

140: 		        for (uint256 i = 2; i < 2 + paddingLen; ++i) {

152: 		            for (uint256 i; i < digestAlgoWithParamLen; ++i) {

158: 		            for (uint256 i; i < digestAlgoWithParamLen; ++i) {

174: 		        for (uint256 i; i < _sha256.length; ++i) {

273: 		        for (uint256 i = 2; i < 2 + paddingLen; ++i) {

283: 		        for (uint256 i; i < sha1Prefix.length; ++i) {

290: 		        for (uint256 i; i < _sha1.length; ++i) {
```

[[140](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L140), [152](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L152), [158](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L158), [174](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L174), [273](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L273), [283](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L283), [290](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L290)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol

18: 		            if (uint8(x509Time[0]) - 48 < 5) yrs += 2000;

48: 		        for (uint16 i = 1970; i < year; ++i) {

59: 		        for (uint8 i = 1; i < month; ++i) {
```

[[18](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol#L18), [48](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol#L48), [59](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol#L59)]

```solidity
File: packages/protocol/contracts/L1/hooks/AssignmentHook.sol

82: 		            block.timestamp > assignment.expiry

85: 		                || assignment.maxBlockId != 0 && _meta.id > assignment.maxBlockId

86: 		                || assignment.maxProposedIn != 0 && block.number > assignment.maxProposedIn

125: 		        if (address(this).balance > 0) {

172: 		        for (uint256 i; i < _tierFees.length; ++i) {
```

[[82](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L82), [85](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L85), [86](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L86), [125](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L125), [172](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L172)]

```solidity
File: packages/protocol/contracts/L1/libs/LibDepositing.sol

78: 		        if (numPending < _config.ethDepositMinCountPerBlock) {

86: 		            for (uint256 i; i < deposits_.length;) {

93: 		                uint96 _fee = deposits_[i].amount > fee ? fee : deposits_[i].amount;

140: 		                && _state.slotA.numEthDeposits - _state.slotA.nextEthDepositToProcess
141: 		                    < _config.ethDepositRingBufferSize - 1;

150: 		        if (_amount > type(uint96).max) revert L1_INVALID_ETH_DEPOSIT();
```

[[78](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibDepositing.sol#L78), [86](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibDepositing.sol#L86), [93](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibDepositing.sol#L93), [140-141](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibDepositing.sol#L140-L141), [150](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibDepositing.sol#L150)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProposing.sol

171: 		            if (uint256(params.txListByteOffset) + params.txListByteSize > MAX_BYTES_PER_BLOB) {

195: 		        if (meta_.txListByteSize == 0 || meta_.txListByteSize > _config.blockMaxTxListBytes) {

244: 		            for (uint256 i; i < params.hookCalls.length; ++i) {

296: 		        return _state.reusableBlobs[_blobHash] + _config.blobExpiry > block.timestamp;
```

[[171](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L171), [195](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L195), [244](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L244), [296](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L296)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProving.sol

134: 		        if (_proof.tier == 0 || _proof.tier < _meta.minTier || _proof.tier < ts.tier) {

134: 		        if (_proof.tier == 0 || _proof.tier < _meta.minTier || _proof.tier < ts.tier) {

192: 		            bool returnLivenessBond = blk.livenessBond > 0 && _proof.data.length == 32

203: 		        if (_proof.tier > ts.tier) {

381: 		            if (reward > _tier.validityBond) {
```

[[134](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L134), [134](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L134), [192](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L192), [203](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L203), [381](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L381)]

```solidity
File: packages/protocol/contracts/L1/libs/LibUtils.sol

34: 		        if (_blockId < b.lastVerifiedBlockId || _blockId >= b.numBlocks) {
```

[[34](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibUtils.sol#L34)]

```solidity
File: packages/protocol/contracts/L1/libs/LibVerifying.sol

127: 		            while (blockId < b.numBlocks && numBlocksVerified < _maxBlocksToVerify) {

127: 		            while (blockId < b.numBlocks && numBlocksVerified < _maxBlocksToVerify) {

152: 		                        uint256(ITierProvider(tierProvider).getTier(ts.tier).cooldownWindow) * 60
153: 		                            + uint256(ts.timestamp).max(_state.slotB.lastUnpausedAt) > block.timestamp

212: 		            if (numBlocksVerified > 0) {

238: 		        if (_lastVerifiedBlockId > lastSyncedBlock + _config.blockSyncThreshold) {

251: 		                || _config.blockMaxTxListBytes > 128 * 1024 // calldata up to 128K

256: 		            || _config.ethDepositMaxCountPerBlock > 32

257: 		                || _config.ethDepositMaxCountPerBlock < _config.ethDepositMinCountPerBlock

260: 		                || _config.ethDepositMaxAmount > type(uint96).max || _config.ethDepositGas == 0

262: 		                || _config.ethDepositMaxFee > type(uint96).max / _config.ethDepositMaxCountPerBlock
```

[[127](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L127), [127](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L127), [152-153](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L152-L153), [212](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L212), [238](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L238), [251](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L251), [256](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L256), [257](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L257), [260](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L260), [262](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L262)]

```solidity
File: packages/protocol/contracts/L1/provers/Guardians.sol

63: 		        if (_newGuardians.length < MIN_NUM_GUARDIANS || _newGuardians.length > type(uint8).max) {

63: 		        if (_newGuardians.length < MIN_NUM_GUARDIANS || _newGuardians.length > type(uint8).max) {

68: 		        if (_minGuardians < (_newGuardians.length + 1) >> 1 || _minGuardians > _newGuardians.length)

68: 		        if (_minGuardians < (_newGuardians.length + 1) >> 1 || _minGuardians > _newGuardians.length)

74: 		        for (uint256 i; i < guardians.length; ++i) {

80: 		        for (uint256 i = 0; i < _newGuardians.length; ++i) {

133: 		            for (uint256 i; i < guardiansLength; ++i) {
```

[[63](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L63), [63](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L63), [68](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L68), [68](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L68), [74](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L74), [80](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L80), [133](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L133)]

```solidity
File: packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol

40: 		        if (claimEnd > block.timestamp || claimEnd + withdrawalWindow < block.timestamp) {

40: 		        if (claimEnd > block.timestamp || claimEnd + withdrawalWindow < block.timestamp) {

114: 		        if (block.timestamp < claimEnd) return (balance, 0);
```

[[40](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol#L40), [40](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol#L40), [114](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol#L114)]

```solidity
File: packages/protocol/contracts/team/airdrop/ERC721Airdrop.sol

59: 		        for (uint256 i; i < tokenIds.length; ++i) {
```

[[59](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC721Airdrop.sol#L59)]

```solidity
File: packages/protocol/contracts/team/airdrop/MerkleClaimable.sol

35: 		            merkleRoot == 0x0 || claimStart == 0 || claimEnd == 0 || claimStart > block.timestamp

36: 		                || claimEnd < block.timestamp
```

[[35](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/MerkleClaimable.sol#L35), [36](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/MerkleClaimable.sol#L36)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol

153: 		        for (uint256 i; i < encoded.length; ++i) {

218: 		        if (cert.certType < 1 || cert.certType > 5) {

218: 		        if (cert.certType < 1 || cert.certType > 5) {

281: 		        for (uint256 i; i < 3; ++i) {
```

[[153](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol#L153), [218](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol#L218), [218](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol#L218), [281](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol#L281)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol

38: 		            _in.length > 0,

74: 		        while (offset < _in.length) {

153: 		            _in.length > 0,

173: 		                _in.length > strLen,

193: 		                _in.length > lenOfStrLen,

213: 		                strLen > 55,

218: 		                _in.length > lenOfStrLen + strLen,

229: 		                _in.length > listLen,

239: 		                _in.length > lenOfListLen,

259: 		                listLen > 55,

264: 		                _in.length > lenOfListLen + listLen,
```

[[38](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L38), [74](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L74), [153](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L153), [173](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L173), [193](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L193), [213](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L213), [218](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L218), [229](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L229), [239](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L239), [259](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L259), [264](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L264)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol

14: 		        if (_in.length == 1 && uint8(_in[0]) < 128) {

33: 		        if (_len < 56) {

59: 		        for (; i < 32; i++) {

66: 		        for (uint256 j = 0; j < out_.length; j++) {
```

[[14](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol#L14), [33](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol#L33), [59](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol#L59), [66](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol#L66)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol

77: 		        require(_key.length > 0, "MerkleTrie: empty key");

85: 		        for (uint256 i = 0; i < proof.length; i++) {

120: 		                        value_.length > 0,

173: 		                        value_.length > 0,

208: 		        for (uint256 i = 0; i < length;) {

221: 		        id_ = _node.length < 32 ? RLPReader.readRawBytes(_node) : RLPReader.readBytes(_node);

243: 		        uint256 max = (_a.length < _b.length) ? _a.length : _b.length;

244: 		        for (; shared_ < max && _a[shared_] == _b[shared_];) {
```

[[77](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L77), [85](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L85), [120](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L120), [173](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L173), [208](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L208), [221](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L221), [243](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L243), [244](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L244)]

</details>

---

### [G-33] `internal` functions only called once can be inlined to save gas

Consider removing the following internal functions, and put the logic directly where they are called, as they are called only once.

_There are 20 instances of this issue._

<details>
<summary>Expand findings</summary>

```solidity
File: packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol

126: 		    function _attestationTcbIsValid(TCBInfoStruct.TCBStatus status)
```

[[126](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L126)]

```solidity
File: packages/protocol/contracts/common/EssentialContract.sol

109: 		    function __Essential_init(address _owner) internal virtual {
```

[[109](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/EssentialContract.sol#L109)]

```solidity
File: packages/protocol/contracts/libs/LibAddress.sol

42: 		    function sendEther(address _to, uint256 _amount) internal {
```

[[42](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/libs/LibAddress.sol#L42)]

```solidity
File: packages/protocol/contracts/signal/SignalService.sol

206: 		    function _verifyHopProof(
```

[[206](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L206)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC20Base.sol

97: 		    function _mintToken(address _account, uint256 _amount) internal virtual;

99: 		    function _burnToken(address _from, uint256 _amount) internal virtual;
```

[[97](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20Base.sol#L97), [99](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20Base.sol#L99)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol

56: 		    function compare(
```

[[56](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L56)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol

43: 		    function pkcs1Sha256(

212: 		    function pkcs1Sha1(
```

[[43](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L43), [212](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L212)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol

34: 		    function toUnixTimestamp(
```

[[34](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol#L34)]

```solidity
File: packages/protocol/contracts/L1/libs/LibDepositing.sol

122: 		    function canDepositEthToL2(
```

[[122](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibDepositing.sol#L122)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProposing.sol

287: 		    function isBlobReusable(
```

[[287](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L287)]

```solidity
File: packages/protocol/contracts/L1/libs/LibUtils.sol

70: 		    function getTransitionId(
```

[[70](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibUtils.sol#L70)]

```solidity
File: packages/protocol/contracts/team/airdrop/MerkleClaimable.sol

77: 		    function _verifyMerkleProof(
```

[[77](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/MerkleClaimable.sol#L77)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/Bytes.sol

91: 		    function slice(bytes memory _bytes, uint256 _start) internal pure returns (bytes memory) {
```

[[91](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/Bytes.sol#L91)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol

267: 		    function parseCerificationChainBytes(
```

[[267](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol#L267)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol

102: 		    function readList(bytes memory _in) internal pure returns (RLPItem[] memory out_) {

128: 		    function readBytes(bytes memory _in) internal pure returns (bytes memory out_) {
```

[[102](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L102), [128](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L128)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol

13: 		    function writeBytes(bytes memory _in) internal pure returns (bytes memory out_) {
```

[[13](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol#L13)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol

68: 		    function get(
```

[[68](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L68)]

</details>

---

### [G-34] Inline `modifiers` that are only used once, to save gas

Consider removing the following modifiers, and put the logic directly in the function where they are used, as they are used only once.

_There are 5 instances of this issue._

```solidity
File: packages/protocol/contracts/common/EssentialContract.sol

53: 		    modifier whenPaused() {
54: 		        if (!paused()) revert INVALID_PAUSE_STATUS();
55: 		        _;
56: 		    }

58: 		    modifier whenNotPaused() {
59: 		        if (paused()) revert INVALID_PAUSE_STATUS();
60: 		        _;
61: 		    }
```

[[53-56](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/EssentialContract.sol#L53-L56), [58-61](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/EssentialContract.sol#L58-L61)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC20.sol

37: 		    modifier onlyOwnerOrSnapshooter() {
38: 		        if (msg.sender != owner() && msg.sender != snapshooter) {
39: 		            revert BTOKEN_UNAUTHORIZED();
40: 		        }
41: 		        _;
42: 		    }
```

[[37-42](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20.sol#L37-L42)]

```solidity
File: packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol

39: 		    modifier ongoingWithdrawals() {
40: 		        if (claimEnd > block.timestamp || claimEnd + withdrawalWindow < block.timestamp) {
41: 		            revert WITHDRAWALS_NOT_ONGOING();
42: 		        }
43: 		        _;
44: 		    }
```

[[39-44](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol#L39-L44)]

```solidity
File: packages/protocol/contracts/team/airdrop/MerkleClaimable.sol

33: 		    modifier ongoingClaim() {
34: 		        if (
35: 		            merkleRoot == 0x0 || claimStart == 0 || claimEnd == 0 || claimStart > block.timestamp
36: 		                || claimEnd < block.timestamp
37: 		        ) revert CLAIM_NOT_ONGOING();
38: 		        _;
39: 		    }
```

[[33-39](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/MerkleClaimable.sol#L33-L39)]

---

### [G-35] `private` functions only called once can be inlined to save gas

Consider removing the following private functions, and put the logic directly where they are called, as they are called only once.

_There are 41 instances of this issue._

<details>
<summary>Expand findings</summary>

```solidity
File: packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol

162: 		    function _verify(bytes calldata quote) private view returns (bool, bytes memory) {

175: 		    function _verifyQEReportWithIdentity(V3Struct.EnclaveReport memory quoteEnclaveReport)

206: 		    function _checkTcbLevels(

229: 		    function _isCpuSvnHigherOrGreater(

248: 		    function _verifyCertChain(IPEMCertChainLib.ECSha256Certificate[] memory certs)

303: 		    function _enclaveReportSigVerification(
```

[[162](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L162), [175](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L175), [206](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L206), [229](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L229), [248](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L248), [303](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L303)]

```solidity
File: packages/protocol/contracts/bridge/Bridge.sol

555: 		    function _loadContext() private view returns (Context memory) {
```

[[555](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L555)]

```solidity
File: packages/protocol/contracts/L2/Lib1559Math.sol

33: 		    function _ethQty(
```

[[33](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/Lib1559Math.sol#L33)]

```solidity
File: packages/protocol/contracts/signal/SignalService.sol

271: 		    function _cacheChainData(
```

[[271](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L271)]

```solidity
File: packages/protocol/contracts/team/TimelockTokenPool.sol

225: 		    function _voidGrant(Grant storage _grant) private returns (uint128 amountVoided) {

239: 		    function _getAmountUnlocked(Grant memory _grant) private view returns (uint128) {

267: 		    function _validateGrant(Grant memory _grant) private pure {
```

[[225](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L225), [239](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L239), [267](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L267)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC1155Vault.sol

240: 		    function _handleMessage(

288: 		    function _getOrDeployBridgedToken(CanonicalNFT memory _ctoken)

303: 		    function _deployBridgedToken(CanonicalNFT memory _ctoken) private returns (address btoken_) {
```

[[240](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L240), [288](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L288), [303](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L303)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC20Vault.sol

348: 		    function _handleMessage(

391: 		    function _getOrDeployBridgedToken(CanonicalERC20 memory ctoken)

407: 		    function _deployBridgedToken(CanonicalERC20 memory ctoken) private returns (address btoken) {
```

[[348](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L348), [391](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L391), [407](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L407)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC721Vault.sol

187: 		    function _handleMessage(

224: 		    function _getOrDeployBridgedToken(CanonicalNFT memory _ctoken)

240: 		    function _deployBridgedToken(CanonicalNFT memory _ctoken) private returns (address btoken_) {
```

[[187](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L187), [224](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L224), [240](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L240)]

```solidity
File: packages/protocol/contracts/verifiers/SgxVerifier.sol

226: 		    function _replaceInstance(uint256 id, address oldInstance, address newInstance) private {

233: 		    function _isInstanceValid(uint256 id, address instance) private view returns (bool) {
```

[[226](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L226), [233](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L233)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol

216: 		    function _removeHeadersAndFooters(string memory pemData)

269: 		    function _findPckTcbInfo(

341: 		    function _findTcb(
```

[[216](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L216), [269](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L269), [341](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L341)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol

272: 		    function memcpy(uint256 dest, uint256 src, uint256 len) private pure {
```

[[272](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L272)]

```solidity
File: packages/protocol/contracts/L1/hooks/AssignmentHook.sol

164: 		    function _getProverFee(
```

[[164](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L164)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProposing.sol

299: 		    function _isProposerPermitted(
```

[[299](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L299)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProving.sol

269: 		    function _createTransition(

350: 		    function _overrideWithHigherProof(

401: 		    function _checkProverPermission(
```

[[269](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L269), [350](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L350), [401](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L401)]

```solidity
File: packages/protocol/contracts/L1/libs/LibVerifying.sol

224: 		    function _syncChainData(

245: 		    function _isConfigValid(TaikoData.Config memory _config) private view returns (bool) {
```

[[224](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L224), [245](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L245)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol

165: 		    function parseAndVerifyHeader(bytes memory rawHeader)

203: 		    function parseAuthDataAndVerifyCertType(
```

[[165](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol#L165), [203](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol#L203)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol

32: 		    function _writeLength(uint256 _len, uint256 _offset) private pure returns (bytes memory out_) {

55: 		    function _toBinary(uint256 _x) private pure returns (bytes memory out_) {
```

[[32](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol#L32), [55](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol#L55)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol

205: 		    function _parseProof(bytes[] memory _proof) private pure returns (TrieNode[] memory proof_) {

227: 		    function _getNodePath(TrieNode memory _node) private pure returns (bytes memory nibbles_) {

235: 		    function _getSharedNibbleLength(
```

[[205](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L205), [227](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L227), [235](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L235)]

</details>

---

### [G-36] Use multiple revert checks to save gas

Splitting the conditions into two separate checks [saves](https://gist.github.com/IllIllI000/7e25b0fca6bd9d57d9b9bcb9d2018959) 2 gas per split.

_There are 37 instances of this issue._

<details>
<summary>Expand findings</summary>

```solidity
File: packages/protocol/contracts/bridge/Bridge.sol

124: 		        if (_message.srcOwner == address(0) || _message.destOwner == address(0)) {
125: 		            revert B_INVALID_USER();
126: 		        }

260: 		            if (_message.gasLimit == 0 && msg.sender != _message.destOwner) {
261: 		                revert B_PERMISSION_DENIED();
262: 		            }

321: 		        if (_message.gasLimit == 0 || _isLastAttempt) {
322: 		            if (msg.sender != _message.destOwner) revert B_PERMISSION_DENIED();
323: 		        }

405: 		        if (ctx_.msgHash == 0 || ctx_.msgHash == bytes32(PLACEHOLDER)) {
406: 		            revert B_INVALID_CONTEXT();
407: 		        }
```

[[124-126](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L124-L126), [260-262](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L260-L262), [321-323](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L321-L323), [405-407](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L405-L407)]

```solidity
File: packages/protocol/contracts/common/AddressResolver.sol

85: 		        if (!_allowZeroAddress && addr_ == address(0)) {
86: 		            revert RESOLVER_ZERO_ADDR(_chainId, _name);
87: 		        }
```

[[85-87](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/AddressResolver.sol#L85-L87)]

```solidity
File: packages/protocol/contracts/common/EssentialContract.sol

42: 		        if (msg.sender != owner() && msg.sender != resolve(_name, true)) revert RESOLVER_DENIED();
```

[[42](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/EssentialContract.sol#L42)]

```solidity
File: packages/protocol/contracts/L2/CrossChainOwned.sol

46: 		        if (ctx.srcChainId != ownerChainId || ctx.from != owner()) {
47: 		            revert XCO_PERMISSION_DENIED();
48: 		        }

70: 		        if (_ownerChainId == 0 || _ownerChainId == block.chainid) {
71: 		            revert XCO_INVALID_OWNER_CHAINID();
72: 		        }
```

[[46-48](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/CrossChainOwned.sol#L46-L48), [70-72](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/CrossChainOwned.sol#L70-L72)]

```solidity
File: packages/protocol/contracts/L2/TaikoL2.sol

82: 		        if (block.chainid <= 1 || block.chainid > type(uint64).max) {
83: 		            revert L2_INVALID_CHAIN_ID();
84: 		        }

116: 		        if (
117: 		            _l1BlockHash == 0 || _l1StateRoot == 0 || _l1BlockId == 0
118: 		                || (block.number != 1 && _parentGasUsed == 0)
119: 		        ) {
120: 		            revert L2_INVALID_PARAM();
121: 		        }

141: 		        if (!skipFeeCheck() && block.basefee != basefee) {
142: 		            revert L2_BASEFEE_MISMATCH();
143: 		        }
```

[[82-84](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L82-L84), [116-121](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L116-L121), [141-143](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L141-L143)]

```solidity
File: packages/protocol/contracts/libs/Lib4844.sol

57: 		        if (uint256(first) != FIELD_ELEMENTS_PER_BLOB || uint256(second) != BLS_MODULUS) {
58: 		            revert EVAL_FAILED_2();
59: 		        }
```

[[57-59](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/libs/Lib4844.sol#L57-L59)]

```solidity
File: packages/protocol/contracts/signal/SignalService.sol

114: 		                if (hop.chainId == 0 || hop.chainId == block.chainid) {
115: 		                    revert SS_INVALID_MID_HOP_CHAINID();
116: 		                }

131: 		        if (value == 0 || value != _loadSignalValue(address(this), signal)) {
132: 		            revert SS_SIGNAL_NOT_FOUND();
133: 		        }
```

[[114-116](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L114-L116), [131-133](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L131-L133)]

```solidity
File: packages/protocol/contracts/team/TimelockTokenPool.sol

274: 		        if (_start == 0 || _period == 0) {
275: 		            if (_cliff > 0) revert INVALID_GRANT();
276: 		        } else {
277: 		            if (_cliff > 0 && _cliff <= _start) revert INVALID_GRANT();
278: 		            if (_cliff >= _start + _period) revert INVALID_GRANT();
279: 		        }

277: 		            if (_cliff > 0 && _cliff <= _start) revert INVALID_GRANT();
```

[[274-279](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L274-L279), [277](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L277)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC20.sol

38: 		        if (msg.sender != owner() && msg.sender != snapshooter) {
39: 		            revert BTOKEN_UNAUTHORIZED();
40: 		        }
```

[[38-40](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20.sol#L38-L40)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC20Base.sol

45: 		        if (_migratingAddress == migratingAddress && _migratingInbound == migratingInbound) {
46: 		            revert BB_INVALID_PARAMS();
47: 		        }
```

[[45-47](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20Base.sol#L45-L47)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC1155Vault.sol

108: 		        if (to == address(0) || to == address(this)) revert VAULT_INVALID_TO();
```

[[108](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L108)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC20Vault.sol

158: 		        if (_btokenNew == address(0) || bridgedToCanonical[_btokenNew].addr != address(0)) {
159: 		            revert VAULT_INVALID_NEW_BTOKEN();
160: 		        }

174: 		            if (
175: 		                ctoken.decimals != _ctoken.decimals
176: 		                    || keccak256(bytes(ctoken.symbol)) != keccak256(bytes(_ctoken.symbol))
177: 		                    || keccak256(bytes(ctoken.name)) != keccak256(bytes(_ctoken.name))
178: 		            ) revert VAULT_CTOKEN_MISMATCH();

267: 		        if (to == address(0) || to == address(this)) revert VAULT_INVALID_TO();
```

[[158-160](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L158-L160), [174-178](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L174-L178), [267](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L267)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC721Vault.sol

91: 		        if (to == address(0) || to == address(this)) revert VAULT_INVALID_TO();
```

[[91](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L91)]

```solidity
File: packages/protocol/contracts/tokenvault/LibBridgedToken.sol

20: 		        if (
21: 		            _srcToken == address(0) || _srcChainId == 0 || _srcChainId == block.chainid
22: 		                || bytes(_symbol).length == 0 || bytes(_name).length == 0
23: 		        ) {
24: 		            revert BTOKEN_INVALID_PARAMS();
25: 		        }
```

[[20-25](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/LibBridgedToken.sol#L20-L25)]

```solidity
File: packages/protocol/contracts/L1/hooks/AssignmentHook.sol

81: 		        if (
82: 		            block.timestamp > assignment.expiry
83: 		                || assignment.metaHash != 0 && _blk.metaHash != assignment.metaHash
84: 		                || assignment.parentMetaHash != 0 && _meta.parentMetaHash != assignment.parentMetaHash
85: 		                || assignment.maxBlockId != 0 && _meta.id > assignment.maxBlockId
86: 		                || assignment.maxProposedIn != 0 && block.number > assignment.maxProposedIn
87: 		        ) {
88: 		            revert HOOK_ASSIGNMENT_EXPIRED();
89: 		        }
```

[[81-89](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L81-L89)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProposing.sol

108: 		        if (params.parentMetaHash != 0 && parentMetaHash != params.parentMetaHash) {
109: 		            revert L1_UNEXPECTED_PARENT();
110: 		        }

195: 		        if (meta_.txListByteSize == 0 || meta_.txListByteSize > _config.blockMaxTxListBytes) {
196: 		            revert L1_TXLIST_SIZE();
197: 		        }
```

[[108-110](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L108-L110), [195-197](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L195-L197)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProving.sol

105: 		        if (_tran.parentHash == 0 || _tran.blockHash == 0 || _tran.stateRoot == 0) {
106: 		            revert L1_INVALID_TRANSITION();
107: 		        }

111: 		        if (_meta.id <= b.lastVerifiedBlockId || _meta.id >= b.numBlocks) {
112: 		            revert L1_INVALID_BLOCK_ID();
113: 		        }

121: 		        if (blk.blockId != _meta.id || blk.metaHash != keccak256(abi.encode(_meta))) {
122: 		            revert L1_BLOCK_MISMATCH();
123: 		        }

134: 		        if (_proof.tier == 0 || _proof.tier < _meta.minTier || _proof.tier < ts.tier) {
135: 		            revert L1_INVALID_TIER();
136: 		        }

419: 		        if (_tid == 1 && _ts.tier == 0 && inProvingWindow) {
420: 		            if (!isAssignedPover) revert L1_NOT_ASSIGNED_PROVER();
421: 		        } else {
422: 		            // Disallow the same address to prove the block so that we can detect that the
423: 		            // assigned prover should not receive his liveness bond back
424: 		            if (isAssignedPover) revert L1_ASSIGNED_PROVER_NOT_ALLOWED();
425: 		        }
```

[[105-107](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L105-L107), [111-113](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L111-L113), [121-123](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L121-L123), [134-136](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L134-L136), [419-425](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L419-L425)]

```solidity
File: packages/protocol/contracts/L1/libs/LibUtils.sol

34: 		        if (_blockId < b.lastVerifiedBlockId || _blockId >= b.numBlocks) {
35: 		            revert L1_INVALID_BLOCK_ID();
36: 		        }
```

[[34-36](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibUtils.sol#L34-L36)]

```solidity
File: packages/protocol/contracts/L1/provers/Guardians.sol

63: 		        if (_newGuardians.length < MIN_NUM_GUARDIANS || _newGuardians.length > type(uint8).max) {
64: 		            revert INVALID_GUARDIAN_SET();
65: 		        }

68: 		        if (_minGuardians < (_newGuardians.length + 1) >> 1 || _minGuardians > _newGuardians.length)
69: 		        {
70: 		            revert INVALID_MIN_GUARDIANS();
71: 		        }
```

[[63-65](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L63-L65), [68-71](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L68-L71)]

```solidity
File: packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol

40: 		        if (claimEnd > block.timestamp || claimEnd + withdrawalWindow < block.timestamp) {
41: 		            revert WITHDRAWALS_NOT_ONGOING();
42: 		        }
```

[[40-42](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol#L40-L42)]

```solidity
File: packages/protocol/contracts/team/airdrop/MerkleClaimable.sol

34: 		        if (
35: 		            merkleRoot == 0x0 || claimStart == 0 || claimEnd == 0 || claimStart > block.timestamp
36: 		                || claimEnd < block.timestamp
37: 		        ) revert CLAIM_NOT_ONGOING();
```

[[34-37](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/MerkleClaimable.sol#L34-L37)]

</details>

---

### [G-37] `abi.encode()` is less efficient than `abi.encodepacked()` for non-address arguments

Consider refactoring the code by using `abi.encodepacked` instead of `abi.encode`, as the former is cheaper when used with non-address arguments.

_There are 16 instances of this issue._

<details>
<summary>Expand findings</summary>

```solidity
File: packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol

482: 		        retData = abi.encodePacked(sha256(abi.encode(v3quote)), tcbStatus);
```

[[482](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L482)]

```solidity
File: packages/protocol/contracts/bridge/Bridge.sol

450: 		        return keccak256(abi.encode("TAIKO_MESSAGE", _message));
```

[[450](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L450)]

```solidity
File: packages/protocol/contracts/signal/SignalService.sol

186: 		        return keccak256(abi.encode(_chainId, _kind, _blockId));
```

[[186](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L186)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC1155Vault.sol

281: 		            this.onMessageInvocation, abi.encode(ctoken_, _user, _op.to, _op.tokenIds, _op.amounts)
```

[[281](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L281)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC20Vault.sol

384: 		            this.onMessageInvocation, abi.encode(ctoken_, _user, _to, balanceChange_)
```

[[384](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L384)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC721Vault.sol

217: 		            this.onMessageInvocation, abi.encode(ctoken_, _user, _op.to, _op.tokenIds)
```

[[217](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L217)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/SigVerifyLib.sol

136: 		        bytes memory args = abi.encode(sha256(tbs), r, s, gx, gy);
```

[[136](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/SigVerifyLib.sol#L136)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProposing.sol

126: 		                depositsHash: keccak256(abi.encode(deposits_)),

213: 		            metaHash: keccak256(abi.encode(meta_)),
```

[[126](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L126), [213](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L213)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProving.sol

121: 		        if (blk.blockId != _meta.id || blk.metaHash != keccak256(abi.encode(_meta))) {
```

[[121](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L121)]

```solidity
File: packages/protocol/contracts/L1/provers/GuardianProver.sol

46: 		        bytes32 hash = keccak256(abi.encode(_meta, _tran));

51: 		            ITaikoL1(resolve("taiko", false)).proveBlock(_meta.id, abi.encode(_meta, _tran, _proof));
```

[[46](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/GuardianProver.sol#L46), [51](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/GuardianProver.sol#L51)]

```solidity
File: packages/protocol/contracts/team/airdrop/ERC20Airdrop.sol

60: 		        _verifyClaim(abi.encode(user, amount), proof);
```

[[60](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC20Airdrop.sol#L60)]

```solidity
File: packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol

80: 		        _verifyClaim(abi.encode(user, amount), proof);
```

[[80](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol#L80)]

```solidity
File: packages/protocol/contracts/team/airdrop/ERC721Airdrop.sol

56: 		        _verifyClaim(abi.encode(user, tokenIds), proof);
```

[[56](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC721Airdrop.sol#L56)]

```solidity
File: packages/protocol/contracts/team/airdrop/MerkleClaimable.sol

68: 		        bytes32 hash = keccak256(abi.encode("CLAIM_TAIKO_AIRDROP", data));
```

[[68](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/MerkleClaimable.sol#L68)]

</details>

---

### [G-38] Unused named return variables without optimizer waste gas

Consider changing the variable to be an unnamed one, since the variable is never assigned, nor is it returned by name. If the optimizer is not turned on, leaving the code as it is will also waste gas for the stack variable.

_There are 20 instances of this issue._

<details>
<summary>Expand findings</summary>

```solidity
File: packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol

// @audit bool valid
130: 		        returns (bool valid)

// @audit bool
178: 		        returns (bool, EnclaveIdStruct.EnclaveIdStatus status)

// @audit bool
212: 		        returns (bool, TCBInfoStruct.TCBStatus status)
```

[[130](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L130), [178](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L178), [212](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L212)]

```solidity
File: packages/protocol/contracts/bridge/Bridge.sol

// @audit uint256 invocationDelay_, uint256 invocationExtraDelay_
421: 		        returns (uint256 invocationDelay_, uint256 invocationExtraDelay_)
```

[[421](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L421)]

```solidity
File: packages/protocol/contracts/common/AddressResolver.sol

// @audit address payable
37: 		        returns (address payable)

// @audit address payable
51: 		        returns (address payable)
```

[[37](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/AddressResolver.sol#L37), [51](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/AddressResolver.sol#L51)]

```solidity
File: packages/protocol/contracts/libs/LibAddress.sol

// @audit
52: 		        returns (bool result_)
```

[[52](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/libs/LibAddress.sol#L52)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol

// @audit
46: 		        returns (bool success, bytes[] memory certs)

// @audit
80: 		        returns (bool success, ECSha256Certificate memory cert)

// @audit bool success, bytes memory extracted, uint256 endIndex
219: 		        returns (bool success, bytes memory extracted, uint256 endIndex)

// @audit
258: 		        returns (bytes memory output)

// @audit uint256 pcesvn, uint256[] memory cpusvns
277: 		            bool success,
```

[[46](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L46), [80](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L80), [219](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L219), [258](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L258), [277](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L277)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol

// @audit uint8 ret
188: 		    function readUint8(bytes memory self, uint256 idx) internal pure returns (uint8 ret) {
```

[[188](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L188)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/SigVerifyLib.sol

// @audit bool sigValid
120: 		        returns (bool sigValid)
```

[[120](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/SigVerifyLib.sol#L120)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProving.sol

// @audit uint8 maxBlocksToVerify_
100: 		        returns (uint8 maxBlocksToVerify_)
```

[[100](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L100)]

```solidity
File: packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol

// @audit
107: 		        returns (uint256 balance, uint256 withdrawableAmount)
```

[[107](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol#L107)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol

// @audit
27: 		        returns (bool success, V3Struct.ParsedV3QuoteStruct memory v3ParsedQuote)

// @audit
168: 		        returns (bool success, V3Struct.Header memory header)

// @audit
209: 		        returns (bool success, V3Struct.ECDSAQuoteV3AuthData memory authDataV3)
```

[[27](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol#L27), [168](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol#L168), [209](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol#L209)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol

// @audit uint256 offset_, uint256 length_, RLPItemType type_
147: 		        returns (uint256 offset_, uint256 length_, RLPItemType type_)
```

[[147](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L147)]

</details>

---

### [G-39] Consider pre-calculating the address of `address(this)` to save gas

Use Foundry's [`script.sol`](https://book.getfoundry.sh/reference/forge-std/compute-create-address) or Solady's [`LibRlp.sol`](https://github.com/Vectorized/solady/blob/main/src/utils/LibRLP.sol) to save the value in a constant, which will avoid having to spend gas to push the value on the stack every time it's used.

_There are 40 instances of this issue._

<details>
<summary>Expand findings</summary>

```solidity
File: packages/protocol/contracts/bridge/Bridge.sol

174: 		            if (!ISignalService(signalService).isSignalSent(address(this), msgHash)) {

196: 		                _storeContext(msgHash, address(this), _message.srcChainId);

270: 		                _message.to == address(0) || _message.to == address(this)

343: 		            _app: address(this),

486: 		        assert(_message.from != address(this));
```

[[174](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L174), [196](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L196), [270](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L270), [343](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L343), [486](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L486)]

```solidity
File: packages/protocol/contracts/L1/TaikoToken.sol

61: 		        if (_to == address(this)) revert TKO_INVALID_ADDR();

79: 		        if (_to == address(this)) revert TKO_INVALID_ADDR();
```

[[61](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoToken.sol#L61), [79](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoToken.sol#L79)]

```solidity
File: packages/protocol/contracts/L2/CrossChainOwned.sol

50: 		        (bool success,) = address(this).call(txdata);
```

[[50](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/CrossChainOwned.sol#L50)]

```solidity
File: packages/protocol/contracts/L2/TaikoL2.sol

174: 		            _to.sendEther(address(this).balance);

176: 		            IERC20(_token).safeTransfer(_to, IERC20(_token).balanceOf(address(this)));
```

[[174](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L174), [176](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L176)]

```solidity
File: packages/protocol/contracts/signal/SignalService.sol

112: 		                signalService = address(this);

131: 		        if (value == 0 || value != _loadSignalValue(address(this), signal)) {

149: 		        return _loadSignalValue(address(this), signal) == _chainData;

171: 		            chainData_ = _loadSignalValue(address(this), signal);

245: 		        _sendSignal(address(this), signal_, _chainData);
```

[[112](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L112), [131](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L131), [149](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L149), [171](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L171), [245](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L245)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC1155.sol

137: 		        if (_to == address(this)) revert BTOKEN_CANNOT_RECEIVE();
```

[[137](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC1155.sol#L137)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC20.sol

147: 		        if (_to == address(this)) revert BTOKEN_CANNOT_RECEIVE();
```

[[147](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20.sol#L147)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC721.sol

125: 		        if (_to == address(this)) revert BTOKEN_CANNOT_RECEIVE();
```

[[125](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC721.sol#L125)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC1155Vault.sol

108: 		        if (to == address(0) || to == address(this)) revert VAULT_INVALID_TO();

226: 		            IERC1155(token).safeBatchTransferFrom(address(this), to, tokenIds, amounts, "");

272: 		                        to: address(this),
```

[[108](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L108), [226](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L226), [272](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L272)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC20Vault.sol

267: 		        if (to == address(0) || to == address(this)) revert VAULT_INVALID_TO();

378: 		            uint256 _balance = t.balanceOf(address(this));

379: 		            t.safeTransferFrom({ from: msg.sender, to: address(this), value: _amount });

380: 		            balanceChange_ = t.balanceOf(address(this)) - _balance;
```

[[267](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L267), [378](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L378), [379](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L379), [380](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L380)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC721Vault.sol

91: 		        if (to == address(0) || to == address(this)) revert VAULT_INVALID_TO();

171: 		                IERC721(token_).safeTransferFrom(address(this), _to, _tokenIds[i]);

211: 		                    t.safeTransferFrom(_user, address(this), _op.tokenIds[i]);
```

[[91](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L91), [171](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L171), [211](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L211)]

```solidity
File: packages/protocol/contracts/verifiers/SgxVerifier.sol

186: 		                address(this),
```

[[186](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L186)]

```solidity
File: packages/protocol/contracts/L1/hooks/AssignmentHook.sol

125: 		        if (address(this).balance > 0) {

126: 		            taikoL1Address.sendEther(address(this).balance);

151: 		                address(this),
```

[[125](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L125), [126](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L126), [151](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L151)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProposing.sol

238: 		            uint256 tkoBalance = tko.balanceOf(address(this));

253: 		                IHook(params.hookCalls[i].hook).onBlockProposed{ value: address(this).balance }(

260: 		            if (address(this).balance != 0) {

261: 		                msg.sender.sendEther(address(this).balance);

268: 		            if (tko.balanceOf(address(this)) != tkoBalance + _config.livenessBond) {
```

[[238](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L238), [253](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L253), [260](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L260), [261](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L261), [268](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L268)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProving.sol

242: 		                tko.transferFrom(msg.sender, address(this), tier.contestBond);

384: 		                _tko.transferFrom(msg.sender, address(this), _tier.validityBond - reward);
```

[[242](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L242), [384](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L384)]

```solidity
File: packages/protocol/contracts/tokenvault/adapters/USDCAdapter.sol

48: 		        usdc.transferFrom(_from, address(this), _amount);
```

[[48](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/adapters/USDCAdapter.sol#L48)]

</details>

---

### [G-40] Consider using Solady's `FixedPointMathLib`

Saves gas, and works to avoid unnecessary [overflows](https://github.com/Vectorized/solady/blob/6cce088e69d6e46671f2f622318102bd5db77a65/src/utils/FixedPointMathLib.sol#L267).

_There are 4 instances of this issue._

```solidity
File: packages/protocol/contracts/L2/Lib1559Math.sol

41: 		        uint256 input = _gasExcess * LibFixedPointMath.SCALING_FACTOR / _adjustmentFactor;
```

[[41](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/Lib1559Math.sol#L41)]

```solidity
File: packages/protocol/contracts/team/TimelockTokenPool.sol

264: 		        return _amount * uint64(block.timestamp - _start) / _period;
```

[[264](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L264)]

```solidity
File: packages/protocol/contracts/L1/libs/LibVerifying.sol

247: 		            _config.chainId <= 1 || _config.chainId == block.chainid //
248: 		                || _config.blockMaxProposals == 1
249: 		                || _config.blockRingBufferSize <= _config.blockMaxProposals + 1
250: 		                || _config.blockMaxGasLimit == 0 || _config.blockMaxTxListBytes == 0
251: 		                || _config.blockMaxTxListBytes > 128 * 1024 // calldata up to 128K
252: 		                || _config.livenessBond == 0 || _config.ethDepositRingBufferSize <= 1
253: 		                || _config.ethDepositMinCountPerBlock == 0
254: 		            // Audit recommendation, and gas tested. Processing 32 deposits (as initially set in
255: 		            // TaikoL1.sol) costs 72_502 gas.
256: 		            || _config.ethDepositMaxCountPerBlock > 32
257: 		                || _config.ethDepositMaxCountPerBlock < _config.ethDepositMinCountPerBlock
258: 		                || _config.ethDepositMinAmount == 0
259: 		                || _config.ethDepositMaxAmount <= _config.ethDepositMinAmount
260: 		                || _config.ethDepositMaxAmount > type(uint96).max || _config.ethDepositGas == 0
261: 		                || _config.ethDepositMaxFee == 0
262: 		                || _config.ethDepositMaxFee > type(uint96).max / _config.ethDepositMaxCountPerBlock
```

[[247-262](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L247-L262)]

```solidity
File: packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol

117: 		        uint256 timeBasedAllowance = balance
118: 		            * (block.timestamp.min(claimEnd + withdrawalWindow) - claimEnd) / withdrawalWindow;
```

[[117-118](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol#L117-L118)]

---

### [G-41] Reduce deployment costs by tweaking contracts' metadata

When solidity generates the bytecode for the smart contract to be deployed, it appends metadata about the compilation at the end of the bytecode.

By default, the solidity compiler appends metadata at the end of the “actual” initcode, which gets stored to the blockchain when the constructor finishes executing.

Consider tweaking the metadata to avoid this unnecessary allocation. A full guide can be found [here](https://www.rareskills.io/post/solidity-metadata).

_There are 86 instances of this issue._

<details>
<summary>Expand findings</summary>

```solidity
File: packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol

22: 		contract AutomataDcapV3Attestation is IAttestation {
```

[[22](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L22)]

```solidity
File: packages/protocol/contracts/bridge/Bridge.sol

16: 		contract Bridge is EssentialContract, IBridge {
```

[[16](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L16)]

```solidity
File: packages/protocol/contracts/bridge/IBridge.sol

8: 		interface IBridge {

160: 		interface IRecallableSender {

174: 		interface IMessageInvocable {
```

[[8](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/IBridge.sol#L8), [160](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/IBridge.sol#L160), [174](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/IBridge.sol#L174)]

```solidity
File: packages/protocol/contracts/common/DefaultResolver.sol

10: 		contract DefaultResolver is EssentialContract, IDefaultResolver {
```

[[10](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/DefaultResolver.sol#L10)]

```solidity
File: packages/protocol/contracts/common/AddressResolver.sol

11: 		abstract contract AddressResolver is IAddressResolver, Initializable {
```

[[11](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/AddressResolver.sol#L11)]

```solidity
File: packages/protocol/contracts/common/EssentialContract.sol

10: 		abstract contract EssentialContract is UUPSUpgradeable, Ownable2StepUpgradeable, AddressResolver {
```

[[10](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/EssentialContract.sol#L10)]

```solidity
File: packages/protocol/contracts/common/IDefaultResolver.sol

7: 		interface IDefaultResolver {
```

[[7](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/IDefaultResolver.sol#L7)]

```solidity
File: packages/protocol/contracts/common/IAddressResolver.sol

13: 		interface IAddressResolver {
```

[[13](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/IAddressResolver.sol#L13)]

```solidity
File: packages/protocol/contracts/L1/ITaikoL1.sol

8: 		interface ITaikoL1 {
```

[[8](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/ITaikoL1.sol#L8)]

```solidity
File: packages/protocol/contracts/L1/TaikoData.sol

8: 		library TaikoData {
```

[[8](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoData.sol#L8)]

```solidity
File: packages/protocol/contracts/L1/TaikoErrors.sol

11: 		abstract contract TaikoErrors {
```

[[11](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoErrors.sol#L11)]

```solidity
File: packages/protocol/contracts/L1/TaikoEvents.sol

13: 		abstract contract TaikoEvents {
```

[[13](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoEvents.sol#L13)]

```solidity
File: packages/protocol/contracts/L1/TaikoL1.sol

22: 		contract TaikoL1 is EssentialContract, ITaikoL1, TaikoEvents, TaikoErrors {
```

[[22](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoL1.sol#L22)]

```solidity
File: packages/protocol/contracts/L1/TaikoToken.sol

15: 		contract TaikoToken is EssentialContract, ERC20SnapshotUpgradeable, ERC20VotesUpgradeable {
```

[[15](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoToken.sol#L15)]

```solidity
File: packages/protocol/contracts/L2/CrossChainOwned.sol

14: 		abstract contract CrossChainOwned is EssentialContract, IMessageInvocable {
```

[[14](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/CrossChainOwned.sol#L14)]

```solidity
File: packages/protocol/contracts/L2/Lib1559Math.sol

10: 		library Lib1559Math {
```

[[10](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/Lib1559Math.sol#L10)]

```solidity
File: packages/protocol/contracts/L2/TaikoL2.sol

21: 		contract TaikoL2 is CrossChainOwned {
```

[[21](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L21)]

```solidity
File: packages/protocol/contracts/L2/TaikoL2EIP1559Configurable.sol

9: 		contract TaikoL2EIP1559Configurable is TaikoL2 {
```

[[9](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2EIP1559Configurable.sol#L9)]

```solidity
File: packages/protocol/contracts/libs/Lib4844.sol

8: 		library Lib4844 {
```

[[8](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/libs/Lib4844.sol#L8)]

```solidity
File: packages/protocol/contracts/libs/LibAddress.sol

13: 		library LibAddress {
```

[[13](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/libs/LibAddress.sol#L13)]

```solidity
File: packages/protocol/contracts/libs/LibMath.sol

7: 		library LibMath {
```

[[7](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/libs/LibMath.sol#L7)]

```solidity
File: packages/protocol/contracts/libs/LibTrieProof.sol

15: 		library LibTrieProof {
```

[[15](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/libs/LibTrieProof.sol#L15)]

```solidity
File: packages/protocol/contracts/signal/ISignalService.sol

12: 		interface ISignalService {
```

[[12](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/ISignalService.sol#L12)]

```solidity
File: packages/protocol/contracts/signal/LibSignals.sol

6: 		library LibSignals {
```

[[6](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/LibSignals.sol#L6)]

```solidity
File: packages/protocol/contracts/signal/SignalService.sol

14: 		contract SignalService is EssentialContract, ISignalService {
```

[[14](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L14)]

```solidity
File: packages/protocol/contracts/team/TimelockTokenPool.sol

25: 		contract TimelockTokenPool is EssentialContract {
```

[[25](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L25)]

```solidity
File: packages/protocol/contracts/tokenvault/BaseNFTVault.sol

9: 		abstract contract BaseNFTVault is BaseVault {
```

[[9](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BaseNFTVault.sol#L9)]

```solidity
File: packages/protocol/contracts/tokenvault/BaseVault.sol

12: 		abstract contract BaseVault is
```

[[12](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BaseVault.sol#L12)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC1155.sol

14: 		contract BridgedERC1155 is EssentialContract, IERC1155MetadataURIUpgradeable, ERC1155Upgradeable {
```

[[14](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC1155.sol#L14)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC20.sol

15: 		contract BridgedERC20 is
```

[[15](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20.sol#L15)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC20Base.sol

9: 		abstract contract BridgedERC20Base is EssentialContract, IBridgedERC20 {
```

[[9](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20Base.sol#L9)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC721.sol

12: 		contract BridgedERC721 is EssentialContract, ERC721Upgradeable {
```

[[12](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC721.sol#L12)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC1155Vault.sol

16: 		interface IERC1155NameAndSymbol {

29: 		contract ERC1155Vault is BaseNFTVault, ERC1155ReceiverUpgradeable {
```

[[16](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L16), [29](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L29)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC20Vault.sol

18: 		contract ERC20Vault is BaseVault {
```

[[18](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L18)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC721Vault.sol

16: 		contract ERC721Vault is BaseNFTVault, IERC721Receiver {
```

[[16](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L16)]

```solidity
File: packages/protocol/contracts/tokenvault/IBridgedERC20.sol

10: 		interface IBridgedERC20 {
```

[[10](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/IBridgedERC20.sol#L10)]

```solidity
File: packages/protocol/contracts/tokenvault/LibBridgedToken.sol

8: 		library LibBridgedToken {
```

[[8](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/LibBridgedToken.sol#L8)]

```solidity
File: packages/protocol/contracts/verifiers/GuardianVerifier.sol

10: 		contract GuardianVerifier is EssentialContract, IVerifier {
```

[[10](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/GuardianVerifier.sol#L10)]

```solidity
File: packages/protocol/contracts/verifiers/IVerifier.sol

9: 		interface IVerifier {
```

[[9](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/IVerifier.sol#L9)]

```solidity
File: packages/protocol/contracts/verifiers/SgxVerifier.sol

19: 		contract SgxVerifier is EssentialContract, IVerifier {
```

[[19](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L19)]

```solidity
File: packages/protocol/contracts/automata-attestation/interfaces/IAttestation.sol

8: 		interface IAttestation {
```

[[8](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/interfaces/IAttestation.sol#L8)]

```solidity
File: packages/protocol/contracts/automata-attestation/interfaces/ISigVerifyLib.sol

6: 		interface ISigVerifyLib {
```

[[6](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/interfaces/ISigVerifyLib.sol#L6)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/EnclaveIdStruct.sol

6: 		library EnclaveIdStruct {
```

[[6](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/EnclaveIdStruct.sol#L6)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol

12: 		contract PEMCertChainLib is IPEMCertChainLib {
```

[[12](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L12)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/TCBInfoStruct.sol

6: 		library TCBInfoStruct {
```

[[6](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/TCBInfoStruct.sol#L6)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/Asn1Decode.sol

12: 		library NodePtr {

38: 		library Asn1Decode {
```

[[12](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/Asn1Decode.sol#L12), [38](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/Asn1Decode.sol#L38)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol

8: 		library BytesUtils {
```

[[8](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L8)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol

34: 		library RsaVerify {
```

[[34](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L34)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/SHA1.sol

10: 		library SHA1 {
```

[[10](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/SHA1.sol#L10)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/SigVerifyLib.sol

15: 		contract SigVerifyLib is ISigVerifyLib {
```

[[15](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/SigVerifyLib.sol#L15)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol

7: 		library X509DateUtils {
```

[[7](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol#L7)]

```solidity
File: packages/protocol/contracts/L1/gov/TaikoGovernor.sol

16: 		contract TaikoGovernor is
```

[[16](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/gov/TaikoGovernor.sol#L16)]

```solidity
File: packages/protocol/contracts/L1/gov/TaikoTimelockController.sol

9: 		contract TaikoTimelockController is EssentialContract, TimelockControllerUpgradeable {
```

[[9](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/gov/TaikoTimelockController.sol#L9)]

```solidity
File: packages/protocol/contracts/L1/hooks/AssignmentHook.sol

14: 		contract AssignmentHook is EssentialContract, IHook {
```

[[14](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L14)]

```solidity
File: packages/protocol/contracts/L1/hooks/IHook.sol

8: 		interface IHook {
```

[[8](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/IHook.sol#L8)]

```solidity
File: packages/protocol/contracts/L1/libs/LibDepositing.sol

12: 		library LibDepositing {
```

[[12](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibDepositing.sol#L12)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProposing.sol

15: 		library LibProposing {
```

[[15](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L15)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProving.sol

16: 		library LibProving {
```

[[16](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L16)]

```solidity
File: packages/protocol/contracts/L1/libs/LibUtils.sol

9: 		library LibUtils {
```

[[9](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibUtils.sol#L9)]

```solidity
File: packages/protocol/contracts/L1/libs/LibVerifying.sol

16: 		library LibVerifying {
```

[[16](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L16)]

```solidity
File: packages/protocol/contracts/L1/provers/GuardianProver.sol

10: 		contract GuardianProver is Guardians {
```

[[10](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/GuardianProver.sol#L10)]

```solidity
File: packages/protocol/contracts/L1/provers/Guardians.sol

9: 		abstract contract Guardians is EssentialContract {
```

[[9](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L9)]

```solidity
File: packages/protocol/contracts/L1/tiers/DevnetTierProvider.sol

10: 		contract DevnetTierProvider is EssentialContract, ITierProvider {
```

[[10](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/tiers/DevnetTierProvider.sol#L10)]

```solidity
File: packages/protocol/contracts/L1/tiers/ITierProvider.sol

7: 		interface ITierProvider {

37: 		library LibTiers {
```

[[7](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/tiers/ITierProvider.sol#L7), [37](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/tiers/ITierProvider.sol#L37)]

```solidity
File: packages/protocol/contracts/L1/tiers/MainnetTierProvider.sol

10: 		contract MainnetTierProvider is EssentialContract, ITierProvider {
```

[[10](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/tiers/MainnetTierProvider.sol#L10)]

```solidity
File: packages/protocol/contracts/L1/tiers/TestnetTierProvider.sol

10: 		contract TestnetTierProvider is EssentialContract, ITierProvider {
```

[[10](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/tiers/TestnetTierProvider.sol#L10)]

```solidity
File: packages/protocol/contracts/team/airdrop/ERC20Airdrop.sol

11: 		contract ERC20Airdrop is MerkleClaimable {
```

[[11](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC20Airdrop.sol#L11)]

```solidity
File: packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol

12: 		contract ERC20Airdrop2 is MerkleClaimable {
```

[[12](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol#L12)]

```solidity
File: packages/protocol/contracts/team/airdrop/ERC721Airdrop.sol

9: 		contract ERC721Airdrop is MerkleClaimable {
```

[[9](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC721Airdrop.sol#L9)]

```solidity
File: packages/protocol/contracts/team/airdrop/MerkleClaimable.sol

10: 		abstract contract MerkleClaimable is EssentialContract {
```

[[10](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/MerkleClaimable.sol#L10)]

```solidity
File: packages/protocol/contracts/thirdparty/nomad-xyz/ExcessivelySafeCall.sol

5: 		library ExcessivelySafeCall {
```

[[5](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/nomad-xyz/ExcessivelySafeCall.sol#L5)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/Bytes.sol

6: 		library Bytes {
```

[[6](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/Bytes.sol#L6)]

```solidity
File: packages/protocol/contracts/tokenvault/adapters/USDCAdapter.sol

8: 		interface IUSDC {

28: 		contract USDCAdapter is BridgedERC20Base {
```

[[8](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/adapters/USDCAdapter.sol#L8), [28](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/adapters/USDCAdapter.sol#L28)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/interfaces/IPEMCertChainLib.sol

6: 		interface IPEMCertChainLib {
```

[[6](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/interfaces/IPEMCertChainLib.sol#L6)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol

11: 		library V3Parser {
```

[[11](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol#L11)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Struct.sol

6: 		library V3Struct {
```

[[6](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Struct.sol#L6)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol

9: 		library RLPReader {
```

[[9](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L9)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol

9: 		library RLPWriter {
```

[[9](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol#L9)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol

11: 		library MerkleTrie {
```

[[11](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L11)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/trie/SecureMerkleTrie.sol

9: 		library SecureMerkleTrie {
```

[[9](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/SecureMerkleTrie.sol#L9)]

</details>

---

### [G-42] Emitting constants wastes gas

Every event parameter costs `Glogdata` (**8 gas**) per byte. You can avoid this extra cost, in cases where you're emitting a constant, by creating a second version of the event, which doesn't have the parameter (and have users look to the contract's variables for its value instead), and using the new event in the cases shown below.

_There are 4 instances of this issue._

```solidity
File: packages/protocol/contracts/bridge/Bridge.sol

// @audit true
210: 		            emit MessageReceived(msgHash, _message, true);

// @audit false
303: 		            emit MessageReceived(msgHash, _message, false);
```

[[210](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L210), [303](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L303)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProving.sol

// @audit 0
230: 		                emit TransitionProved({
231: 		                    blockId: blk.blockId,
232: 		                    tran: _tran,
233: 		                    prover: msg.sender,
234: 		                    validityBond: 0,
235: 		                    tier: _proof.tier
236: 		                });
```

[[230-236](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L230-L236)]

```solidity
File: packages/protocol/contracts/L1/libs/LibVerifying.sol

// @audit 0, 0, 0, 0
73: 		        emit BlockVerified({
74: 		            blockId: 0,
75: 		            assignedProver: address(0),
76: 		            prover: address(0),
77: 		            blockHash: _genesisBlockHash,
78: 		            stateRoot: 0,
79: 		            tier: 0,
80: 		            contestations: 0
81: 		        });
```

[[73-81](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L73-L81)]

---

### [G-43] Update OpenZeppelin dependency to save gas

Every release contains new gas optimizations, use the latest version to take advantage of this.

_There are 54 instances of this issue._

<details>
<summary>Expand findings</summary>

```solidity
File: packages/protocol/contracts/bridge/Bridge.sol

4: 		import "@openzeppelin/contracts/utils/Address.sol";
```

[[4](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L4)]

```solidity
File: packages/protocol/contracts/common/AddressResolver.sol

4: 		import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
```

[[4](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/AddressResolver.sol#L4)]

```solidity
File: packages/protocol/contracts/common/EssentialContract.sol

4: 		import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

5: 		import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
```

[[4](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/EssentialContract.sol#L4), [5](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/EssentialContract.sol#L5)]

```solidity
File: packages/protocol/contracts/L1/TaikoToken.sol

4: 		import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

5: 		import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20SnapshotUpgradeable.sol";

6: 		import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
```

[[4](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoToken.sol#L4), [5](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoToken.sol#L5), [6](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoToken.sol#L6)]

```solidity
File: packages/protocol/contracts/L2/CrossChainOwned.sol

4: 		import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
```

[[4](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/CrossChainOwned.sol#L4)]

```solidity
File: packages/protocol/contracts/L2/TaikoL2.sol

4: 		import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

5: 		import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
```

[[4](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L4), [5](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L5)]

```solidity
File: packages/protocol/contracts/libs/LibAddress.sol

4: 		import "@openzeppelin/contracts/utils/Address.sol";

5: 		import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

6: 		import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

7: 		import "@openzeppelin/contracts/interfaces/IERC1271.sol";
```

[[4](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/libs/LibAddress.sol#L4), [5](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/libs/LibAddress.sol#L5), [6](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/libs/LibAddress.sol#L6), [7](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/libs/LibAddress.sol#L7)]

```solidity
File: packages/protocol/contracts/signal/SignalService.sol

4: 		import "@openzeppelin/contracts/utils/math/SafeCast.sol";
```

[[4](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L4)]

```solidity
File: packages/protocol/contracts/team/TimelockTokenPool.sol

4: 		import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

5: 		import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

6: 		import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
```

[[4](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L4), [5](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L5), [6](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L6)]

```solidity
File: packages/protocol/contracts/tokenvault/BaseVault.sol

4: 		import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";

5: 		import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
```

[[4](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BaseVault.sol#L4), [5](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BaseVault.sol#L5)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC1155.sol

4: 		import "@openzeppelin/contracts/utils/Strings.sol";

5: 		import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";

6: 		import
7: 		    "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/IERC1155MetadataURIUpgradeable.sol";
```

[[4](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC1155.sol#L4), [5](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC1155.sol#L5), [6-7](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC1155.sol#L6-L7)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC20.sol

4: 		import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

5: 		import "@openzeppelin/contracts/utils/Strings.sol";

6: 		import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20SnapshotUpgradeable.sol";

7: 		import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
```

[[4](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20.sol#L4), [5](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20.sol#L5), [6](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20.sol#L6), [7](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20.sol#L7)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC721.sol

4: 		import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

5: 		import "@openzeppelin/contracts/utils/Strings.sol";
```

[[4](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC721.sol#L4), [5](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC721.sol#L5)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC1155Vault.sol

4: 		import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

5: 		import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155ReceiverUpgradeable.sol";
```

[[4](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L4), [5](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L5)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC20Vault.sol

4: 		import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

5: 		import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

6: 		import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
```

[[4](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L4), [5](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L5), [6](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L6)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC721Vault.sol

4: 		import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

5: 		import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
```

[[4](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L4), [5](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L5)]

```solidity
File: packages/protocol/contracts/tokenvault/LibBridgedToken.sol

4: 		import "@openzeppelin/contracts/utils/Strings.sol";
```

[[4](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/LibBridgedToken.sol#L4)]

```solidity
File: packages/protocol/contracts/verifiers/SgxVerifier.sol

4: 		import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
```

[[4](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L4)]

```solidity
File: packages/protocol/contracts/L1/gov/TaikoGovernor.sol

4: 		import "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";

5: 		import
6: 		    "@openzeppelin/contracts-upgradeable/governance/compatibility/GovernorCompatibilityBravoUpgradeable.sol";

7: 		import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesUpgradeable.sol";

8: 		import
9: 		    "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesQuorumFractionUpgradeable.sol";

10: 		import
11: 		    "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorTimelockControlUpgradeable.sol";
```

[[4](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/gov/TaikoGovernor.sol#L4), [5-6](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/gov/TaikoGovernor.sol#L5-L6), [7](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/gov/TaikoGovernor.sol#L7), [8-9](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/gov/TaikoGovernor.sol#L8-L9), [10-11](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/gov/TaikoGovernor.sol#L10-L11)]

```solidity
File: packages/protocol/contracts/L1/gov/TaikoTimelockController.sol

4: 		import "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
```

[[4](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/gov/TaikoTimelockController.sol#L4)]

```solidity
File: packages/protocol/contracts/L1/hooks/AssignmentHook.sol

4: 		import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

5: 		import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
```

[[4](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L4), [5](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L5)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProposing.sol

4: 		import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
```

[[4](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L4)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProving.sol

4: 		import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
```

[[4](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L4)]

```solidity
File: packages/protocol/contracts/L1/libs/LibVerifying.sol

4: 		import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
```

[[4](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L4)]

```solidity
File: packages/protocol/contracts/team/airdrop/ERC20Airdrop.sol

4: 		import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

5: 		import "@openzeppelin/contracts/governance/utils/IVotes.sol";
```

[[4](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC20Airdrop.sol#L4), [5](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC20Airdrop.sol#L5)]

```solidity
File: packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol

4: 		import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
```

[[4](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol#L4)]

```solidity
File: packages/protocol/contracts/team/airdrop/ERC721Airdrop.sol

4: 		import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
```

[[4](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC721Airdrop.sol#L4)]

```solidity
File: packages/protocol/contracts/team/airdrop/MerkleClaimable.sol

4: 		import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
```

[[4](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/MerkleClaimable.sol#L4)]

</details>

---

### [G-44] Function names can be optimized

Function that are `public`/`external` and `public` state variable names can be optimized to save gas.

Method IDs that have two leading zero bytes can save **128 gas** each during deployment, and renaming functions to have lower method IDs will save **22 gas** per call, per sorted position shifted. [Reference](https://blog.emn178.cc/en/post/solidity-gas-optimization-function-name/)

_There are 56 instances of this issue._

<details>
<summary>Expand findings</summary>

```solidity
File: packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol

22: 		contract AutomataDcapV3Attestation is IAttestation {
```

[[22](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L22)]

```solidity
File: packages/protocol/contracts/bridge/Bridge.sol

16: 		contract Bridge is EssentialContract, IBridge {
```

[[16](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L16)]

```solidity
File: packages/protocol/contracts/bridge/IBridge.sol

8: 		interface IBridge {

160: 		interface IRecallableSender {

174: 		interface IMessageInvocable {
```

[[8](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/IBridge.sol#L8), [160](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/IBridge.sol#L160), [174](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/IBridge.sol#L174)]

```solidity
File: packages/protocol/contracts/common/DefaultResolver.sol

10: 		contract DefaultResolver is EssentialContract, IDefaultResolver {
```

[[10](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/DefaultResolver.sol#L10)]

```solidity
File: packages/protocol/contracts/common/AddressResolver.sol

11: 		abstract contract AddressResolver is IAddressResolver, Initializable {
```

[[11](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/AddressResolver.sol#L11)]

```solidity
File: packages/protocol/contracts/common/EssentialContract.sol

10: 		abstract contract EssentialContract is UUPSUpgradeable, Ownable2StepUpgradeable, AddressResolver {
```

[[10](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/EssentialContract.sol#L10)]

```solidity
File: packages/protocol/contracts/common/IDefaultResolver.sol

7: 		interface IDefaultResolver {
```

[[7](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/IDefaultResolver.sol#L7)]

```solidity
File: packages/protocol/contracts/common/IAddressResolver.sol

13: 		interface IAddressResolver {
```

[[13](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/IAddressResolver.sol#L13)]

```solidity
File: packages/protocol/contracts/L1/ITaikoL1.sol

8: 		interface ITaikoL1 {
```

[[8](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/ITaikoL1.sol#L8)]

```solidity
File: packages/protocol/contracts/L1/TaikoL1.sol

22: 		contract TaikoL1 is EssentialContract, ITaikoL1, TaikoEvents, TaikoErrors {
```

[[22](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoL1.sol#L22)]

```solidity
File: packages/protocol/contracts/L1/TaikoToken.sol

15: 		contract TaikoToken is EssentialContract, ERC20SnapshotUpgradeable, ERC20VotesUpgradeable {
```

[[15](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoToken.sol#L15)]

```solidity
File: packages/protocol/contracts/L2/CrossChainOwned.sol

14: 		abstract contract CrossChainOwned is EssentialContract, IMessageInvocable {
```

[[14](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/CrossChainOwned.sol#L14)]

```solidity
File: packages/protocol/contracts/L2/TaikoL2.sol

21: 		contract TaikoL2 is CrossChainOwned {
```

[[21](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L21)]

```solidity
File: packages/protocol/contracts/L2/TaikoL2EIP1559Configurable.sol

9: 		contract TaikoL2EIP1559Configurable is TaikoL2 {
```

[[9](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2EIP1559Configurable.sol#L9)]

```solidity
File: packages/protocol/contracts/signal/ISignalService.sol

12: 		interface ISignalService {
```

[[12](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/ISignalService.sol#L12)]

```solidity
File: packages/protocol/contracts/signal/SignalService.sol

14: 		contract SignalService is EssentialContract, ISignalService {
```

[[14](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L14)]

```solidity
File: packages/protocol/contracts/team/TimelockTokenPool.sol

25: 		contract TimelockTokenPool is EssentialContract {
```

[[25](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L25)]

```solidity
File: packages/protocol/contracts/tokenvault/BaseVault.sol

12: 		abstract contract BaseVault is
```

[[12](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BaseVault.sol#L12)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC1155.sol

14: 		contract BridgedERC1155 is EssentialContract, IERC1155MetadataURIUpgradeable, ERC1155Upgradeable {
```

[[14](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC1155.sol#L14)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC20.sol

15: 		contract BridgedERC20 is
```

[[15](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20.sol#L15)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC20Base.sol

9: 		abstract contract BridgedERC20Base is EssentialContract, IBridgedERC20 {
```

[[9](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20Base.sol#L9)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC721.sol

12: 		contract BridgedERC721 is EssentialContract, ERC721Upgradeable {
```

[[12](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC721.sol#L12)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC1155Vault.sol

16: 		interface IERC1155NameAndSymbol {

29: 		contract ERC1155Vault is BaseNFTVault, ERC1155ReceiverUpgradeable {
```

[[16](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L16), [29](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L29)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC20Vault.sol

18: 		contract ERC20Vault is BaseVault {
```

[[18](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L18)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC721Vault.sol

16: 		contract ERC721Vault is BaseNFTVault, IERC721Receiver {
```

[[16](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L16)]

```solidity
File: packages/protocol/contracts/tokenvault/IBridgedERC20.sol

10: 		interface IBridgedERC20 {
```

[[10](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/IBridgedERC20.sol#L10)]

```solidity
File: packages/protocol/contracts/verifiers/GuardianVerifier.sol

10: 		contract GuardianVerifier is EssentialContract, IVerifier {
```

[[10](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/GuardianVerifier.sol#L10)]

```solidity
File: packages/protocol/contracts/verifiers/IVerifier.sol

9: 		interface IVerifier {
```

[[9](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/IVerifier.sol#L9)]

```solidity
File: packages/protocol/contracts/verifiers/SgxVerifier.sol

19: 		contract SgxVerifier is EssentialContract, IVerifier {
```

[[19](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L19)]

```solidity
File: packages/protocol/contracts/automata-attestation/interfaces/IAttestation.sol

8: 		interface IAttestation {
```

[[8](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/interfaces/IAttestation.sol#L8)]

```solidity
File: packages/protocol/contracts/automata-attestation/interfaces/ISigVerifyLib.sol

6: 		interface ISigVerifyLib {
```

[[6](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/interfaces/ISigVerifyLib.sol#L6)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol

12: 		contract PEMCertChainLib is IPEMCertChainLib {
```

[[12](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L12)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/SigVerifyLib.sol

15: 		contract SigVerifyLib is ISigVerifyLib {
```

[[15](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/SigVerifyLib.sol#L15)]

```solidity
File: packages/protocol/contracts/L1/gov/TaikoGovernor.sol

16: 		contract TaikoGovernor is
```

[[16](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/gov/TaikoGovernor.sol#L16)]

```solidity
File: packages/protocol/contracts/L1/gov/TaikoTimelockController.sol

9: 		contract TaikoTimelockController is EssentialContract, TimelockControllerUpgradeable {
```

[[9](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/gov/TaikoTimelockController.sol#L9)]

```solidity
File: packages/protocol/contracts/L1/hooks/AssignmentHook.sol

14: 		contract AssignmentHook is EssentialContract, IHook {
```

[[14](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L14)]

```solidity
File: packages/protocol/contracts/L1/hooks/IHook.sol

8: 		interface IHook {
```

[[8](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/IHook.sol#L8)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProving.sol

16: 		library LibProving {
```

[[16](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L16)]

```solidity
File: packages/protocol/contracts/L1/libs/LibUtils.sol

9: 		library LibUtils {
```

[[9](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibUtils.sol#L9)]

```solidity
File: packages/protocol/contracts/L1/libs/LibVerifying.sol

16: 		library LibVerifying {
```

[[16](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L16)]

```solidity
File: packages/protocol/contracts/L1/provers/GuardianProver.sol

10: 		contract GuardianProver is Guardians {
```

[[10](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/GuardianProver.sol#L10)]

```solidity
File: packages/protocol/contracts/L1/provers/Guardians.sol

9: 		abstract contract Guardians is EssentialContract {
```

[[9](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L9)]

```solidity
File: packages/protocol/contracts/L1/tiers/DevnetTierProvider.sol

10: 		contract DevnetTierProvider is EssentialContract, ITierProvider {
```

[[10](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/tiers/DevnetTierProvider.sol#L10)]

```solidity
File: packages/protocol/contracts/L1/tiers/ITierProvider.sol

7: 		interface ITierProvider {
```

[[7](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/tiers/ITierProvider.sol#L7)]

```solidity
File: packages/protocol/contracts/L1/tiers/MainnetTierProvider.sol

10: 		contract MainnetTierProvider is EssentialContract, ITierProvider {
```

[[10](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/tiers/MainnetTierProvider.sol#L10)]

```solidity
File: packages/protocol/contracts/L1/tiers/TestnetTierProvider.sol

10: 		contract TestnetTierProvider is EssentialContract, ITierProvider {
```

[[10](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/tiers/TestnetTierProvider.sol#L10)]

```solidity
File: packages/protocol/contracts/team/airdrop/ERC20Airdrop.sol

11: 		contract ERC20Airdrop is MerkleClaimable {
```

[[11](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC20Airdrop.sol#L11)]

```solidity
File: packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol

12: 		contract ERC20Airdrop2 is MerkleClaimable {
```

[[12](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol#L12)]

```solidity
File: packages/protocol/contracts/team/airdrop/ERC721Airdrop.sol

9: 		contract ERC721Airdrop is MerkleClaimable {
```

[[9](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC721Airdrop.sol#L9)]

```solidity
File: packages/protocol/contracts/team/airdrop/MerkleClaimable.sol

10: 		abstract contract MerkleClaimable is EssentialContract {
```

[[10](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/MerkleClaimable.sol#L10)]

```solidity
File: packages/protocol/contracts/tokenvault/adapters/USDCAdapter.sol

8: 		interface IUSDC {

28: 		contract USDCAdapter is BridgedERC20Base {
```

[[8](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/adapters/USDCAdapter.sol#L8), [28](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/adapters/USDCAdapter.sol#L28)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/interfaces/IPEMCertChainLib.sol

6: 		interface IPEMCertChainLib {
```

[[6](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/interfaces/IPEMCertChainLib.sol#L6)]

</details>

---

### [G-45] Avoid zero transfers calls

Emit any transfer events if the EIP requires it, but avoid doing the actual call when the amount is zero.

_There are 10 instances of this issue._

```solidity
File: packages/protocol/contracts/team/TimelockTokenPool.sol

219: 		        IERC20(taikoToken).transferFrom(sharedVault, _to, amountToWithdraw);
```

[[219](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L219)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProving.sol

196: 		                tko.transfer(blk.assignedProver, blk.livenessBond);

242: 		                tko.transferFrom(msg.sender, address(this), tier.contestBond);

367: 		                _tko.transfer(_ts.prover, _ts.validityBond + reward);

371: 		                _tko.transfer(_ts.contester, _ts.contestBond + reward);

382: 		                _tko.transfer(msg.sender, reward - _tier.validityBond);

384: 		                _tko.transferFrom(msg.sender, address(this), _tier.validityBond - reward);
```

[[196](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L196), [242](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L242), [367](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L367), [371](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L371), [382](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L382), [384](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L384)]

```solidity
File: packages/protocol/contracts/L1/libs/LibVerifying.sol

189: 		                tko.transfer(ts.prover, bondToReturn);
```

[[189](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L189)]

```solidity
File: packages/protocol/contracts/team/airdrop/ERC20Airdrop.sol

63: 		        IERC20(token).transferFrom(vault, user, amount);
```

[[63](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC20Airdrop.sol#L63)]

```solidity
File: packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol

91: 		        IERC20(token).transferFrom(vault, user, amount);
```

[[91](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol#L91)]

---

### [G-46] Using `delete` instead of setting mapping/struct to 0 saves gas

Avoid an assignment by deleting the value instead of setting it to zero, as it's [cheaper](https://gist.github.com/DadeKuma/ea874815202fc77e9d81f81a047c1e5e).

_There are 10 instances of this issue._

```solidity
File: packages/protocol/contracts/team/TimelockTokenPool.sol

231: 		        _grant.grantStart = 0;

232: 		        _grant.grantPeriod = 0;
```

[[231](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L231), [232](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L232)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol

336: 		                tbsPtr = 0; // exit
```

[[336](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L336)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProposing.sol

190: 		            meta_.txListByteOffset = 0;
```

[[190](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L190)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProving.sol

197: 		                blk.livenessBond = 0;

300: 		            ts_.blockHash = 0;

301: 		            ts_.stateRoot = 0;

302: 		            ts_.validityBond = 0;

306: 		            ts_.tier = 0;

307: 		            ts_.contestations = 0;
```

[[197](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L197), [300](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L300), [301](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L301), [302](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L302), [306](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L306), [307](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L307)]

---

### [G-47] Using `bool` for storage incurs overhead

Booleans are more expensive than `uint256` or any type that takes up a full word because each write operation emits an extra SLOAD to first read the slot's contents, replace the bits taken up by the boolean, and then write back.

This is the compiler's defense against contract upgrades and pointer aliasing, and it cannot be disabled. Use `uint256(0) and uint256(1)` for `true/false` to avoid a Gwarmaccess (**100 gas**) for the extra `SLOAD`.

_There are 10 instances of this issue._

<details>
<summary>Expand findings</summary>

```solidity
File: packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol

38: 		    bool private _checkLocalEnclaveReport;

39: 		    mapping(bytes32 enclave => bool trusted) private _trustedUserMrEnclave;

40: 		    mapping(bytes32 signer => bool trusted) private _trustedUserMrSigner;

47: 		    mapping(uint256 idx => mapping(bytes serialNum => bool revoked)) private _serialNumIsRevoked;
```

[[38](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L38), [39](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L39), [40](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L40), [47](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L47)]

```solidity
File: packages/protocol/contracts/bridge/Bridge.sol

42: 		    mapping(address addr => bool banned) public addressBanned;
```

[[42](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L42)]

```solidity
File: packages/protocol/contracts/signal/SignalService.sol

21: 		    mapping(address addr => bool authorized) public isAuthorized;
```

[[21](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L21)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC20Base.sol

14: 		    bool public migratingInbound;
```

[[14](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20Base.sol#L14)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC20Vault.sol

52: 		    mapping(address btoken => bool blacklisted) public btokenBlacklist;
```

[[52](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L52)]

```solidity
File: packages/protocol/contracts/verifiers/SgxVerifier.sol

55: 		    mapping(address instanceAddress => bool alreadyAttested) public addressRegistered;
```

[[55](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L55)]

```solidity
File: packages/protocol/contracts/team/airdrop/MerkleClaimable.sol

12: 		    mapping(bytes32 hash => bool claimed) public isClaimed;
```

[[12](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/MerkleClaimable.sol#L12)]

</details>

---

### [G-48] Mappings are cheaper to use than storage arrays

When using storage arrays, solidity adds an internal lookup of the array's length (a **Gcoldsload 2100 gas**) to ensure you don't read past the array's end.

You can avoid this lookup by using a mapping and storing the number of entries in a separate storage variable. In cases where you have sentinel values (e.g. 'zero' means invalid), you can avoid length checks.

_There are 36 instances of this issue._

<details>
<summary>Expand findings</summary>

```solidity
File: packages/protocol/contracts/bridge/Bridge.sol

48: 		    uint256[43] private __gap;
```

[[48](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L48)]

```solidity
File: packages/protocol/contracts/common/DefaultResolver.sol

14: 		    uint256[49] private __gap;
```

[[14](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/DefaultResolver.sol#L14)]

```solidity
File: packages/protocol/contracts/common/AddressResolver.sol

14: 		    uint256[49] private __gap;
```

[[14](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/AddressResolver.sol#L14)]

```solidity
File: packages/protocol/contracts/common/EssentialContract.sol

25: 		    uint256[49] private __gap;
```

[[25](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/EssentialContract.sol#L25)]

```solidity
File: packages/protocol/contracts/L1/TaikoL1.sol

26: 		    uint256[50] private __gap;
```

[[26](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoL1.sol#L26)]

```solidity
File: packages/protocol/contracts/L1/TaikoToken.sol

16: 		    uint256[50] private __gap;
```

[[16](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoToken.sol#L16)]

```solidity
File: packages/protocol/contracts/L2/CrossChainOwned.sol

21: 		    uint256[49] private __gap;
```

[[21](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/CrossChainOwned.sol#L21)]

```solidity
File: packages/protocol/contracts/L2/TaikoL2.sol

52: 		    uint256[47] private __gap;
```

[[52](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L52)]

```solidity
File: packages/protocol/contracts/L2/TaikoL2EIP1559Configurable.sol

13: 		    uint256[49] private __gap;
```

[[13](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2EIP1559Configurable.sol#L13)]

```solidity
File: packages/protocol/contracts/signal/SignalService.sol

23: 		    uint256[48] private __gap;
```

[[23](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L23)]

```solidity
File: packages/protocol/contracts/team/TimelockTokenPool.sol

82: 		    uint128[44] private __gap;
```

[[82](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L82)]

```solidity
File: packages/protocol/contracts/tokenvault/BaseNFTVault.sol

61: 		    uint256[48] private __gap;
```

[[61](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BaseNFTVault.sol#L61)]

```solidity
File: packages/protocol/contracts/tokenvault/BaseVault.sol

18: 		    uint256[50] private __gap;
```

[[18](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BaseVault.sol#L18)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC1155.sol

27: 		    uint256[46] private __gap;
```

[[27](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC1155.sol#L27)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC20.sol

32: 		    uint256[47] private __gap;
```

[[32](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20.sol#L32)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC20Base.sol

16: 		    uint256[49] private __gap;
```

[[16](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20Base.sol#L16)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC721.sol

19: 		    uint256[48] private __gap;
```

[[19](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC721.sol#L19)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC1155Vault.sol

32: 		    uint256[50] private __gap;
```

[[32](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L32)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC20Vault.sol

54: 		    uint256[47] private __gap;
```

[[54](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L54)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC721Vault.sol

19: 		    uint256[50] private __gap;
```

[[19](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L19)]

```solidity
File: packages/protocol/contracts/verifiers/GuardianVerifier.sol

11: 		    uint256[50] private __gap;
```

[[11](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/GuardianVerifier.sol#L11)]

```solidity
File: packages/protocol/contracts/verifiers/SgxVerifier.sol

57: 		    uint256[47] private __gap;
```

[[57](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L57)]

```solidity
File: packages/protocol/contracts/L1/gov/TaikoGovernor.sol

23: 		    uint256[50] private __gap;
```

[[23](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/gov/TaikoGovernor.sol#L23)]

```solidity
File: packages/protocol/contracts/L1/gov/TaikoTimelockController.sol

10: 		    uint256[50] private __gap;
```

[[10](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/gov/TaikoTimelockController.sol#L10)]

```solidity
File: packages/protocol/contracts/L1/hooks/AssignmentHook.sol

40: 		    uint256[50] private __gap;
```

[[40](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L40)]

```solidity
File: packages/protocol/contracts/L1/provers/GuardianProver.sol

11: 		    uint256[50] private __gap;
```

[[11](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/GuardianProver.sol#L11)]

```solidity
File: packages/protocol/contracts/L1/provers/Guardians.sol

23: 		    address[] public guardians;

32: 		    uint256[46] private __gap;
```

[[23](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L23), [32](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L32)]

```solidity
File: packages/protocol/contracts/L1/tiers/DevnetTierProvider.sol

11: 		    uint256[50] private __gap;
```

[[11](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/tiers/DevnetTierProvider.sol#L11)]

```solidity
File: packages/protocol/contracts/L1/tiers/MainnetTierProvider.sol

11: 		    uint256[50] private __gap;
```

[[11](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/tiers/MainnetTierProvider.sol#L11)]

```solidity
File: packages/protocol/contracts/L1/tiers/TestnetTierProvider.sol

11: 		    uint256[50] private __gap;
```

[[11](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/tiers/TestnetTierProvider.sol#L11)]

```solidity
File: packages/protocol/contracts/team/airdrop/ERC20Airdrop.sol

18: 		    uint256[48] private __gap;
```

[[18](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC20Airdrop.sol#L18)]

```solidity
File: packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol

30: 		    uint256[45] private __gap;
```

[[30](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol#L30)]

```solidity
File: packages/protocol/contracts/team/airdrop/ERC721Airdrop.sol

16: 		    uint256[48] private __gap;
```

[[16](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC721Airdrop.sol#L16)]

```solidity
File: packages/protocol/contracts/team/airdrop/MerkleClaimable.sol

23: 		    uint256[47] private __gap;
```

[[23](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/MerkleClaimable.sol#L23)]

```solidity
File: packages/protocol/contracts/tokenvault/adapters/USDCAdapter.sol

32: 		    uint256[49] private __gap;
```

[[32](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/adapters/USDCAdapter.sol#L32)]

</details>

---

### [G-49] Bytes constants are more efficient than string constants

If a string can fit in 32 bytes is it better to use `bytes32` instead of `string`, as it is cheaper.

```solidity
// @audit avoid this
string constant stringVariable = "LessThan32Bytes";

// @audit as this is cheaper
bytes32 constant stringVariable = "LessThan32Bytes";
```

_There are 5 instances of this issue._

```solidity
File: packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol

17: 		    string internal constant HEADER = "-----BEGIN CERTIFICATE-----";

18: 		    string internal constant FOOTER = "-----END CERTIFICATE-----";

22: 		    string internal constant PCK_COMMON_NAME = "Intel SGX PCK Certificate";

23: 		    string internal constant PLATFORM_ISSUER_NAME = "Intel SGX PCK Platform CA";

24: 		    string internal constant PROCESSOR_ISSUER_NAME = "Intel SGX PCK Processor CA";
```

[[17](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L17), [18](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L18), [22](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L22), [23](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L23), [24](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L24)]

---

### [G-50] Constructors can be marked `payable`

`payable` functions cost less gas to execute, since the compiler does not have to add extra checks to ensure that a payment wasn't provided.

A `constructor` can safely be marked as `payable`, since only the deployer would be able to pass funds, and the project itself would not pass any funds.

_There are 3 instances of this issue._

```solidity
File: packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol

54: 		    constructor(address sigVerifyLibAddr, address pemCertLibAddr) {
```

[[54](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L54)]

```solidity
File: packages/protocol/contracts/common/EssentialContract.sol

64: 		    constructor() {
```

[[64](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/EssentialContract.sol#L64)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/SigVerifyLib.sol

20: 		    constructor(address es256Verifier) {
```

[[20](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/SigVerifyLib.sol#L20)]

---

### [G-51] Inverting the `if` condition wastes gas

Flipping the `true` and `false` blocks instead saves 3 gas.

_There are 2 instances of this issue._

```solidity
File: packages/protocol/contracts/bridge/Bridge.sol

209: 		        } else if (!isMessageProven) {
210: 		            emit MessageReceived(msgHash, _message, true);
211: 		        } else {
212: 		            revert B_INVOCATION_TOO_EARLY();
213: 		        }

302: 		        } else if (!isMessageProven) {
303: 		            emit MessageReceived(msgHash, _message, false);
304: 		        } else {
305: 		            revert B_INVOCATION_TOO_EARLY();
306: 		        }
```

[[209-213](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L209-L213), [302-306](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L302-L306)]

---

### [G-52] Long revert strings

Considering refactoring the revert message to fit in 32 bytes to avoid using more than one memory slot.

_There are 27 instances of this issue._

<details>
<summary>Expand findings</summary>

```solidity
File: packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol

87: 		        require(
88: 		            v3Quote.v3AuthData.certification.certType == 5,
89: 		            "certType must be 5: Concatenated PCK Cert Chain (PEM formatted)"
90: 		        );
```

[[87-90](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol#L87-L90)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol

37: 		        require(
38: 		            _in.length > 0,
39: 		            "RLPReader: length of an RLP item must be greater than zero to be decodable"
40: 		        );

56: 		        require(
57: 		            itemType == RLPItemType.LIST_ITEM,
58: 		            "RLPReader: decoded item type for list is not a list item"
59: 		        );

61: 		        require(
62: 		            listOffset + listLength == _in.length,
63: 		            "RLPReader: list item has an invalid data remainder"
64: 		        );

112: 		        require(
113: 		            itemType == RLPItemType.DATA_ITEM,
114: 		            "RLPReader: decoded item type for bytes is not a data item"
115: 		        );

117: 		        require(
118: 		            _in.length == itemOffset + itemLength,
119: 		            "RLPReader: bytes value contains an invalid remainder"
120: 		        );

152: 		        require(
153: 		            _in.length > 0,
154: 		            "RLPReader: length of an RLP item must be greater than zero to be decodable"
155: 		        );

172: 		            require(
173: 		                _in.length > strLen,
174: 		                "RLPReader: length of content must be greater than string length (short string)"
175: 		            );

182: 		            require(
183: 		                strLen != 1 || firstByteOfContent >= 0x80,
184: 		                "RLPReader: invalid prefix, single byte < 0x80 are not prefixed (short string)"
185: 		            );

192: 		            require(
193: 		                _in.length > lenOfStrLen,
194: 		                "RLPReader: length of content must be > than length of string length (long string)"
195: 		            );

202: 		            require(
203: 		                firstByteOfContent != 0x00,
204: 		                "RLPReader: length of content must not have any leading zeros (long string)"
205: 		            );

212: 		            require(
213: 		                strLen > 55,
214: 		                "RLPReader: length of content must be greater than 55 bytes (long string)"
215: 		            );

217: 		            require(
218: 		                _in.length > lenOfStrLen + strLen,
219: 		                "RLPReader: length of content must be greater than total length (long string)"
220: 		            );

228: 		            require(
229: 		                _in.length > listLen,
230: 		                "RLPReader: length of content must be greater than list length (short list)"
231: 		            );

238: 		            require(
239: 		                _in.length > lenOfListLen,
240: 		                "RLPReader: length of content must be > than length of list length (long list)"
241: 		            );

248: 		            require(
249: 		                firstByteOfContent != 0x00,
250: 		                "RLPReader: length of content must not have any leading zeros (long list)"
251: 		            );

258: 		            require(
259: 		                listLen > 55,
260: 		                "RLPReader: length of content must be greater than 55 bytes (long list)"
261: 		            );

263: 		            require(
264: 		                _in.length > lenOfListLen + listLen,
265: 		                "RLPReader: length of content must be greater than total length (long list)"
266: 		            );
```

[[37-40](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L37-L40), [56-59](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L56-L59), [61-64](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L61-L64), [112-115](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L112-L115), [117-120](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L117-L120), [152-155](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L152-L155), [172-175](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L172-L175), [182-185](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L182-L185), [192-195](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L192-L195), [202-205](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L202-L205), [212-215](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L212-L215), [217-220](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L217-L220), [228-231](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L228-L231), [238-241](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L238-L241), [248-251](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L248-L251), [258-261](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L258-L261), [263-266](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L263-L266)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol

89: 		            require(currentKeyIndex <= key.length, "MerkleTrie: key index exceeds total key length");

99: 		                require(
100: 		                    Bytes.equal(abi.encodePacked(keccak256(currentNode.encoded)), currentNodeID),
101: 		                    "MerkleTrie: invalid large internal hash"
102: 		                );

105: 		                require(
106: 		                    Bytes.equal(currentNode.encoded, currentNodeID),
107: 		                    "MerkleTrie: invalid internal node hash"
108: 		                );

119: 		                    require(
120: 		                        value_.length > 0,
121: 		                        "MerkleTrie: value length must be greater than zero (branch)"
122: 		                    );

125: 		                    require(
126: 		                        i == proof.length - 1,
127: 		                        "MerkleTrie: value node must be last node in proof (branch)"
128: 		                    );

150: 		                require(
151: 		                    pathRemainder.length == sharedNibbleLength,
152: 		                    "MerkleTrie: path remainder must share all nibbles with key"
153: 		                );

162: 		                    require(
163: 		                        keyRemainder.length == sharedNibbleLength,
164: 		                        "MerkleTrie: key remainder must be identical to path remainder"
165: 		                    );

172: 		                    require(
173: 		                        value_.length > 0,
174: 		                        "MerkleTrie: value length must be greater than zero (leaf)"
175: 		                    );

178: 		                    require(
179: 		                        i == proof.length - 1,
180: 		                        "MerkleTrie: value node must be last node in proof (leaf)"
181: 		                    );
```

[[89](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L89), [99-102](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L99-L102), [105-108](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L105-L108), [119-122](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L119-L122), [125-128](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L125-L128), [150-153](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L150-L153), [162-165](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L162-L165), [172-175](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L172-L175), [178-181](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L178-L181)]

</details>

---

### [G-53] Nesting `if` statements that use `&&` saves gas

Using the `&&` operator on a single `if` [costs more gas](https://gist.github.com/DadeKuma/931ce6794a050201ec6544dbcc31316c) than using two nested `if`.

_There are 23 instances of this issue._

<details>
<summary>Expand findings</summary>

```solidity
File: packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol

220: 		            if (pceSvnIsHigherOrGreater && cpuSvnsAreHigherOrGreater) {
```

[[220](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L220)]

```solidity
File: packages/protocol/contracts/bridge/Bridge.sol

250: 		        if (invocationDelay != 0 && msg.sender != proofReceipt[msgHash].preferredExecutor) {

260: 		            if (_message.gasLimit == 0 && msg.sender != _message.destOwner) {

439: 		        } else if (block.chainid >= 32_300 && block.chainid <= 32_400) {

491: 		            _message.data.length >= 4 // msg can be empty
492: 		                && bytes4(_message.data) != IMessageInvocable.onMessageInvocation.selector
493: 		                && _message.to.isContract()
```

[[250](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L250), [260](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L260), [439](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L439), [491-493](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L491-L493)]

```solidity
File: packages/protocol/contracts/common/AddressResolver.sol

85: 		        if (!_allowZeroAddress && addr_ == address(0)) {
```

[[85](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/AddressResolver.sol#L85)]

```solidity
File: packages/protocol/contracts/common/EssentialContract.sol

42: 		        if (msg.sender != owner() && msg.sender != resolve(_name, true)) revert RESOLVER_DENIED();
```

[[42](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/EssentialContract.sol#L42)]

```solidity
File: packages/protocol/contracts/L2/TaikoL2.sol

117: 		            _l1BlockHash == 0 || _l1StateRoot == 0 || _l1BlockId == 0
118: 		                || (block.number != 1 && _parentGasUsed == 0)

141: 		        if (!skipFeeCheck() && block.basefee != basefee) {

275: 		            if (lastSyncedBlock > 0 && _l1BlockId > lastSyncedBlock) {
```

[[117-118](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L117-L118), [141](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L141), [275](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L275)]

```solidity
File: packages/protocol/contracts/signal/SignalService.sol

285: 		        if (cacheStateRoot && _isFullProof && !_isLastHop) {

293: 		        if (cacheSignalRoot && (_isFullProof || !_isLastHop)) {
```

[[285](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L285), [293](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L293)]

```solidity
File: packages/protocol/contracts/team/TimelockTokenPool.sol

277: 		            if (_cliff > 0 && _cliff <= _start) revert INVALID_GRANT();
```

[[277](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L277)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC20.sol

38: 		        if (msg.sender != owner() && msg.sender != snapshooter) {
```

[[38](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20.sol#L38)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC20Base.sol

45: 		        if (_migratingAddress == migratingAddress && _migratingInbound == migratingInbound) {
```

[[45](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20Base.sol#L45)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol

135: 		                (notBeforeTag != 0x17 && notBeforeTag == 0x18)
136: 		                    || (notAfterTag != 0x17 && notAfterTag != 0x18)
```

[[135-136](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L135-L136)]

```solidity
File: packages/protocol/contracts/L1/hooks/AssignmentHook.sol

82: 		            block.timestamp > assignment.expiry
83: 		                || assignment.metaHash != 0 && _blk.metaHash != assignment.metaHash
84: 		                || assignment.parentMetaHash != 0 && _meta.parentMetaHash != assignment.parentMetaHash
85: 		                || assignment.maxBlockId != 0 && _meta.id > assignment.maxBlockId
86: 		                || assignment.maxProposedIn != 0 && block.number > assignment.maxProposedIn

120: 		        if (input.tip != 0 && block.coinbase != address(0)) {
```

[[82-86](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L82-L86), [120](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L120)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProposing.sol

108: 		        if (params.parentMetaHash != 0 && parentMetaHash != params.parentMetaHash) {

164: 		                if (_config.blobReuseEnabled && params.cacheBlobForReuse) {

310: 		            if (proposerOne != address(0) && msg.sender != proposerOne) {
```

[[108](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L108), [164](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L164), [310](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L310)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProving.sol

419: 		        if (_tid == 1 && _ts.tier == 0 && inProvingWindow) {
```

[[419](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L419)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol

14: 		        if (_in.length == 1 && uint8(_in[0]) < 128) {
```

[[14](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol#L14)]

</details>

---

### [G-54] Counting down when iterating, saves gas

Counting down saves **6 gas** per loop, since checks for zero are more efficient than checks against any other value.

_There are 45 instances of this issue._

<details>
<summary>Expand findings</summary>

```solidity
File: packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol

80: 		        for (uint256 i; i < serialNumBatch.length; ++i) {

95: 		        for (uint256 i; i < serialNumBatch.length; ++i) {

191: 		        for (uint256 i; i < enclaveId.tcbLevels.length; ++i) {

214: 		        for (uint256 i; i < tcb.tcbLevels.length; ++i) {

240: 		        for (uint256 i; i < CPUSVN_LENGTH; ++i) {

259: 		        for (uint256 i; i < n; ++i) {

420: 		            for (uint256 i; i < 3; ++i) {
```

[[80](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L80), [95](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L95), [191](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L191), [214](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L214), [240](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L240), [259](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L259), [420](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L420)]

```solidity
File: packages/protocol/contracts/bridge/Bridge.sol

90: 		        for (uint256 i; i < _msgHashes.length; ++i) {
```

[[90](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L90)]

```solidity
File: packages/protocol/contracts/L2/TaikoL2.sol

234: 		            for (uint256 i; i < 255 && _blockId >= i + 1; ++i) {
```

[[234](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L234)]

```solidity
File: packages/protocol/contracts/signal/SignalService.sol

104: 		        for (uint256 i; i < hopProofs.length; ++i) {
```

[[104](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L104)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC1155Vault.sol

47: 		        for (uint256 i; i < _op.amounts.length; ++i) {

251: 		                for (uint256 i; i < _op.tokenIds.length; ++i) {

269: 		                for (uint256 i; i < _op.tokenIds.length; ++i) {
```

[[47](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L47), [251](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L251), [269](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L269)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC721Vault.sol

34: 		        for (uint256 i; i < _op.tokenIds.length; ++i) {

170: 		            for (uint256 i; i < _tokenIds.length; ++i) {

175: 		            for (uint256 i; i < _tokenIds.length; ++i) {

197: 		                for (uint256 i; i < _op.tokenIds.length; ++i) {

210: 		                for (uint256 i; i < _op.tokenIds.length; ++i) {
```

[[34](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L34), [170](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L170), [175](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L175), [197](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L197), [210](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L210)]

```solidity
File: packages/protocol/contracts/verifiers/SgxVerifier.sol

104: 		        for (uint256 i; i < _ids.length; ++i) {

210: 		        for (uint256 i; i < _instances.length; ++i) {
```

[[104](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L104), [210](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L210)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol

54: 		        for (uint256 i; i < size; ++i) {

244: 		        for (uint256 i; i < split.length; ++i) {

354: 		        for (uint256 i; i < SGX_TCB_CPUSVN_SIZE + 1; ++i) {
```

[[54](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L54), [244](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L244), [354](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L354)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol

333: 		        for (uint256 i; i < len; ++i) {
```

[[333](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L333)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol

140: 		        for (uint256 i = 2; i < 2 + paddingLen; ++i) {

152: 		            for (uint256 i; i < digestAlgoWithParamLen; ++i) {

158: 		            for (uint256 i; i < digestAlgoWithParamLen; ++i) {

174: 		        for (uint256 i; i < _sha256.length; ++i) {

273: 		        for (uint256 i = 2; i < 2 + paddingLen; ++i) {

283: 		        for (uint256 i; i < sha1Prefix.length; ++i) {

290: 		        for (uint256 i; i < _sha1.length; ++i) {
```

[[140](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L140), [152](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L152), [158](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L158), [174](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L174), [273](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L273), [283](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L283), [290](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L290)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol

48: 		        for (uint16 i = 1970; i < year; ++i) {

59: 		        for (uint8 i = 1; i < month; ++i) {
```

[[48](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol#L48), [59](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol#L59)]

```solidity
File: packages/protocol/contracts/L1/hooks/AssignmentHook.sol

172: 		        for (uint256 i; i < _tierFees.length; ++i) {
```

[[172](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L172)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProposing.sol

244: 		            for (uint256 i; i < params.hookCalls.length; ++i) {
```

[[244](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L244)]

```solidity
File: packages/protocol/contracts/L1/provers/Guardians.sol

74: 		        for (uint256 i; i < guardians.length; ++i) {

80: 		        for (uint256 i = 0; i < _newGuardians.length; ++i) {

133: 		            for (uint256 i; i < guardiansLength; ++i) {
```

[[74](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L74), [80](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L80), [133](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L133)]

```solidity
File: packages/protocol/contracts/team/airdrop/ERC721Airdrop.sol

59: 		        for (uint256 i; i < tokenIds.length; ++i) {
```

[[59](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC721Airdrop.sol#L59)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol

153: 		        for (uint256 i; i < encoded.length; ++i) {

281: 		        for (uint256 i; i < 3; ++i) {
```

[[153](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol#L153), [281](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol#L281)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol

46: 		            for (i = 1; i <= lenLen; i++) {

59: 		        for (; i < 32; i++) {

66: 		        for (uint256 j = 0; j < out_.length; j++) {
```

[[46](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol#L46), [59](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol#L59), [66](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol#L66)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol

85: 		        for (uint256 i = 0; i < proof.length; i++) {
```

[[85](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L85)]

</details>

---

### [G-55] `do-while` is cheaper than `for`-loops when the initial check can be skipped

Example:

```solidity
for (uint256 i; i < len; ++i){ ... } -> do { ...; ++i } while (i < len);
```

_There are 49 instances of this issue._

<details>
<summary>Expand findings</summary>

```solidity
File: packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol

80: 		        for (uint256 i; i < serialNumBatch.length; ++i) {

95: 		        for (uint256 i; i < serialNumBatch.length; ++i) {

191: 		        for (uint256 i; i < enclaveId.tcbLevels.length; ++i) {

214: 		        for (uint256 i; i < tcb.tcbLevels.length; ++i) {

240: 		        for (uint256 i; i < CPUSVN_LENGTH; ++i) {

259: 		        for (uint256 i; i < n; ++i) {

420: 		            for (uint256 i; i < 3; ++i) {
```

[[80](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L80), [95](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L95), [191](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L191), [214](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L214), [240](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L240), [259](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L259), [420](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L420)]

```solidity
File: packages/protocol/contracts/bridge/Bridge.sol

90: 		        for (uint256 i; i < _msgHashes.length; ++i) {
```

[[90](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L90)]

```solidity
File: packages/protocol/contracts/L2/TaikoL2.sol

234: 		            for (uint256 i; i < 255 && _blockId >= i + 1; ++i) {
```

[[234](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L234)]

```solidity
File: packages/protocol/contracts/signal/SignalService.sol

104: 		        for (uint256 i; i < hopProofs.length; ++i) {
```

[[104](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L104)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC1155Vault.sol

47: 		        for (uint256 i; i < _op.amounts.length; ++i) {

251: 		                for (uint256 i; i < _op.tokenIds.length; ++i) {

269: 		                for (uint256 i; i < _op.tokenIds.length; ++i) {
```

[[47](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L47), [251](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L251), [269](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L269)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC721Vault.sol

34: 		        for (uint256 i; i < _op.tokenIds.length; ++i) {

170: 		            for (uint256 i; i < _tokenIds.length; ++i) {

175: 		            for (uint256 i; i < _tokenIds.length; ++i) {

197: 		                for (uint256 i; i < _op.tokenIds.length; ++i) {

210: 		                for (uint256 i; i < _op.tokenIds.length; ++i) {
```

[[34](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L34), [170](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L170), [175](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L175), [197](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L197), [210](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L210)]

```solidity
File: packages/protocol/contracts/verifiers/SgxVerifier.sol

104: 		        for (uint256 i; i < _ids.length; ++i) {

210: 		        for (uint256 i; i < _instances.length; ++i) {
```

[[104](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L104), [210](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L210)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol

54: 		        for (uint256 i; i < size; ++i) {

244: 		        for (uint256 i; i < split.length; ++i) {

354: 		        for (uint256 i; i < SGX_TCB_CPUSVN_SIZE + 1; ++i) {
```

[[54](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L54), [244](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L244), [354](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L354)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol

80: 		        for (uint256 idx = 0; idx < shortest; idx += 32) {

333: 		        for (uint256 i; i < len; ++i) {
```

[[80](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L80), [333](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L333)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol

140: 		        for (uint256 i = 2; i < 2 + paddingLen; ++i) {

152: 		            for (uint256 i; i < digestAlgoWithParamLen; ++i) {

158: 		            for (uint256 i; i < digestAlgoWithParamLen; ++i) {

174: 		        for (uint256 i; i < _sha256.length; ++i) {

273: 		        for (uint256 i = 2; i < 2 + paddingLen; ++i) {

283: 		        for (uint256 i; i < sha1Prefix.length; ++i) {

290: 		        for (uint256 i; i < _sha1.length; ++i) {
```

[[140](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L140), [152](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L152), [158](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L158), [174](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L174), [273](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L273), [283](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L283), [290](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L290)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol

48: 		        for (uint16 i = 1970; i < year; ++i) {

59: 		        for (uint8 i = 1; i < month; ++i) {
```

[[48](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol#L48), [59](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol#L59)]

```solidity
File: packages/protocol/contracts/L1/hooks/AssignmentHook.sol

172: 		        for (uint256 i; i < _tierFees.length; ++i) {
```

[[172](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L172)]

```solidity
File: packages/protocol/contracts/L1/libs/LibDepositing.sol

86: 		            for (uint256 i; i < deposits_.length;) {
```

[[86](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibDepositing.sol#L86)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProposing.sol

244: 		            for (uint256 i; i < params.hookCalls.length; ++i) {
```

[[244](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L244)]

```solidity
File: packages/protocol/contracts/L1/provers/Guardians.sol

74: 		        for (uint256 i; i < guardians.length; ++i) {

80: 		        for (uint256 i = 0; i < _newGuardians.length; ++i) {

133: 		            for (uint256 i; i < guardiansLength; ++i) {
```

[[74](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L74), [80](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L80), [133](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L133)]

```solidity
File: packages/protocol/contracts/team/airdrop/ERC721Airdrop.sol

59: 		        for (uint256 i; i < tokenIds.length; ++i) {
```

[[59](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC721Airdrop.sol#L59)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol

153: 		        for (uint256 i; i < encoded.length; ++i) {

281: 		        for (uint256 i; i < 3; ++i) {
```

[[153](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol#L153), [281](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol#L281)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol

46: 		            for (i = 1; i <= lenLen; i++) {

59: 		        for (; i < 32; i++) {

66: 		        for (uint256 j = 0; j < out_.length; j++) {
```

[[46](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol#L46), [59](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol#L59), [66](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol#L66)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol

85: 		        for (uint256 i = 0; i < proof.length; i++) {

208: 		        for (uint256 i = 0; i < length;) {

244: 		        for (; shared_ < max && _a[shared_] == _b[shared_];) {
```

[[85](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L85), [208](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L208), [244](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L244)]

</details>

---

### [G-56] Lack of `unchecked` in loops

Use `unchecked` to increment the loop variable as it can save gas:

```solidity
for(uint256 i; i < length;) {
	unchecked{
		++i;
	}
}
```

_There are 39 instances of this issue._

<details>
<summary>Expand findings</summary>

```solidity
File: packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol

80: 		        for (uint256 i; i < serialNumBatch.length; ++i) {

95: 		        for (uint256 i; i < serialNumBatch.length; ++i) {

191: 		        for (uint256 i; i < enclaveId.tcbLevels.length; ++i) {

214: 		        for (uint256 i; i < tcb.tcbLevels.length; ++i) {

240: 		        for (uint256 i; i < CPUSVN_LENGTH; ++i) {

259: 		        for (uint256 i; i < n; ++i) {

420: 		            for (uint256 i; i < 3; ++i) {
```

[[80](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L80), [95](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L95), [191](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L191), [214](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L214), [240](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L240), [259](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L259), [420](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L420)]

```solidity
File: packages/protocol/contracts/bridge/Bridge.sol

90: 		        for (uint256 i; i < _msgHashes.length; ++i) {
```

[[90](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L90)]

```solidity
File: packages/protocol/contracts/signal/SignalService.sol

104: 		        for (uint256 i; i < hopProofs.length; ++i) {
```

[[104](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L104)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC1155Vault.sol

47: 		        for (uint256 i; i < _op.amounts.length; ++i) {
```

[[47](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L47)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC721Vault.sol

34: 		        for (uint256 i; i < _op.tokenIds.length; ++i) {

170: 		            for (uint256 i; i < _tokenIds.length; ++i) {

175: 		            for (uint256 i; i < _tokenIds.length; ++i) {
```

[[34](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L34), [170](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L170), [175](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L175)]

```solidity
File: packages/protocol/contracts/verifiers/SgxVerifier.sol

104: 		        for (uint256 i; i < _ids.length; ++i) {

210: 		        for (uint256 i; i < _instances.length; ++i) {
```

[[104](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L104), [210](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L210)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol

54: 		        for (uint256 i; i < size; ++i) {

244: 		        for (uint256 i; i < split.length; ++i) {

354: 		        for (uint256 i; i < SGX_TCB_CPUSVN_SIZE + 1; ++i) {
```

[[54](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L54), [244](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L244), [354](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L354)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol

333: 		        for (uint256 i; i < len; ++i) {
```

[[333](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol#L333)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol

140: 		        for (uint256 i = 2; i < 2 + paddingLen; ++i) {

152: 		            for (uint256 i; i < digestAlgoWithParamLen; ++i) {

158: 		            for (uint256 i; i < digestAlgoWithParamLen; ++i) {

174: 		        for (uint256 i; i < _sha256.length; ++i) {

273: 		        for (uint256 i = 2; i < 2 + paddingLen; ++i) {

283: 		        for (uint256 i; i < sha1Prefix.length; ++i) {

290: 		        for (uint256 i; i < _sha1.length; ++i) {
```

[[140](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L140), [152](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L152), [158](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L158), [174](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L174), [273](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L273), [283](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L283), [290](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol#L290)]

```solidity
File: packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol

48: 		        for (uint16 i = 1970; i < year; ++i) {

59: 		        for (uint8 i = 1; i < month; ++i) {
```

[[48](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol#L48), [59](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol#L59)]

```solidity
File: packages/protocol/contracts/L1/hooks/AssignmentHook.sol

172: 		        for (uint256 i; i < _tierFees.length; ++i) {
```

[[172](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L172)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProposing.sol

244: 		            for (uint256 i; i < params.hookCalls.length; ++i) {
```

[[244](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L244)]

```solidity
File: packages/protocol/contracts/L1/provers/Guardians.sol

74: 		        for (uint256 i; i < guardians.length; ++i) {

80: 		        for (uint256 i = 0; i < _newGuardians.length; ++i) {
```

[[74](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L74), [80](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L80)]

```solidity
File: packages/protocol/contracts/team/airdrop/ERC721Airdrop.sol

59: 		        for (uint256 i; i < tokenIds.length; ++i) {
```

[[59](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/airdrop/ERC721Airdrop.sol#L59)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol

153: 		        for (uint256 i; i < encoded.length; ++i) {

281: 		        for (uint256 i; i < 3; ++i) {
```

[[153](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol#L153), [281](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol#L281)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol

46: 		            for (i = 1; i <= lenLen; i++) {

59: 		        for (; i < 32; i++) {

66: 		        for (uint256 j = 0; j < out_.length; j++) {
```

[[46](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol#L46), [59](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol#L59), [66](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol#L66)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol

85: 		        for (uint256 i = 0; i < proof.length; i++) {
```

[[85](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L85)]

</details>

---

### [G-57] `uint` comparison with zero can be cheaper

Checking for `!= 0` is cheaper than `> 0` for unsigned integers.

_There are 15 instances of this issue._

<details>
<summary>Expand findings</summary>

```solidity
File: packages/protocol/contracts/L2/TaikoL2.sol

262: 		        if (gasExcess > 0) {

275: 		            if (lastSyncedBlock > 0 && _l1BlockId > lastSyncedBlock) {

279: 		            if (numL1Blocks > 0) {
```

[[262](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L262), [275](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L275), [279](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L279)]

```solidity
File: packages/protocol/contracts/signal/SignalService.sol

120: 		            bool isFullProof = hop.accountProof.length > 0;
```

[[120](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L120)]

```solidity
File: packages/protocol/contracts/team/TimelockTokenPool.sol

275: 		            if (_cliff > 0) revert INVALID_GRANT();

277: 		            if (_cliff > 0 && _cliff <= _start) revert INVALID_GRANT();
```

[[275](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L275), [277](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L277)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol

56: 		            if (i > 0) {
```

[[56](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L56)]

```solidity
File: packages/protocol/contracts/L1/hooks/AssignmentHook.sol

125: 		        if (address(this).balance > 0) {
```

[[125](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L125)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProving.sol

192: 		            bool returnLivenessBond = blk.livenessBond > 0 && _proof.data.length == 32
```

[[192](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L192)]

```solidity
File: packages/protocol/contracts/L1/libs/LibVerifying.sol

212: 		            if (numBlocksVerified > 0) {
```

[[212](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L212)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol

38: 		            _in.length > 0,

153: 		            _in.length > 0,
```

[[38](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L38), [153](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol#L153)]

```solidity
File: packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol

77: 		        require(_key.length > 0, "MerkleTrie: empty key");

120: 		                        value_.length > 0,

173: 		                        value_.length > 0,
```

[[77](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L77), [120](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L120), [173](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol#L173)]

</details>

---

### [G-58] Use assembly to check for `address(0)`

[A simple zero address check](https://medium.com/@kalexotsu/solidity-assembly-checking-if-an-address-is-0-efficiently-d2bfe071331) can be written in assembly to save some gas.

_There are 74 instances of this issue._

<details>
<summary>Expand findings</summary>

```solidity
File: packages/protocol/contracts/bridge/Bridge.sol

124: 		        if (_message.srcOwner == address(0) || _message.destOwner == address(0)) {

124: 		        if (_message.srcOwner == address(0) || _message.destOwner == address(0)) {

124: 		        if (_message.srcOwner == address(0) || _message.destOwner == address(0)) {

270: 		                _message.to == address(0) || _message.to == address(this)
271: 		                    || _message.to == signalService || addressBanned[_message.to]

270: 		                _message.to == address(0) || _message.to == address(this)
271: 		                    || _message.to == signalService || addressBanned[_message.to]

270: 		                _message.to == address(0) || _message.to == address(this)

270: 		                _message.to == address(0) || _message.to == address(this)

291: 		                _message.refundTo == address(0) ? _message.destOwner : _message.refundTo;

398: 		        enabled_ = destBridge_ != address(0);

398: 		        enabled_ = destBridge_ != address(0);
```

[[124](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L124), [124](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L124), [124](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L124), [270-271](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L270-L271), [270-271](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L270-L271), [270](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L270), [270](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L270), [291](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L291), [398](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L398), [398](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L398)]

```solidity
File: packages/protocol/contracts/common/AddressResolver.sol

81: 		        if (addressManager == address(0)) revert RESOLVER_INVALID_MANAGER();

85: 		        if (!_allowZeroAddress && addr_ == address(0)) {

85: 		        if (!_allowZeroAddress && addr_ == address(0)) {
```

[[81](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/AddressResolver.sol#L81), [85](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/AddressResolver.sol#L85), [85](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/AddressResolver.sol#L85)]

```solidity
File: packages/protocol/contracts/common/EssentialContract.sol

105: 		        if (_addressManager == address(0)) revert ZERO_ADDR_MANAGER();

110: 		        _transferOwnership(_owner == address(0) ? msg.sender : _owner);
```

[[105](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/EssentialContract.sol#L105), [110](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/EssentialContract.sol#L110)]

```solidity
File: packages/protocol/contracts/L2/TaikoL2.sol

172: 		        if (_to == address(0)) revert L2_INVALID_PARAM();

173: 		        if (_token == address(0)) {
```

[[172](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L172), [173](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L173)]

```solidity
File: packages/protocol/contracts/libs/LibAddress.sol

24: 		        if (_to == address(0)) revert ETH_TRANSFER_FAILED();
```

[[24](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/libs/LibAddress.sol#L24)]

```solidity
File: packages/protocol/contracts/signal/SignalService.sol

36: 		        if (_app == address(0)) revert SS_INVALID_SENDER();
```

[[36](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/signal/SignalService.sol#L36)]

```solidity
File: packages/protocol/contracts/team/TimelockTokenPool.sol

121: 		        if (_taikoToken == address(0)) revert INVALID_PARAM();

124: 		        if (_costToken == address(0)) revert INVALID_PARAM();

127: 		        if (_sharedVault == address(0)) revert INVALID_PARAM();

136: 		        if (_recipient == address(0)) revert INVALID_PARAM();

169: 		        if (_to == address(0)) revert INVALID_PARAM();
```

[[121](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L121), [124](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L124), [127](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L127), [136](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L136), [169](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L169)]

```solidity
File: packages/protocol/contracts/tokenvault/BaseNFTVault.sol

149: 		        if (_op.token == address(0)) revert VAULT_INVALID_TOKEN();
```

[[149](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BaseNFTVault.sol#L149)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC20Base.sol

102: 		        return migratingAddress != address(0) && !migratingInbound;

102: 		        return migratingAddress != address(0) && !migratingInbound;
```

[[102](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20Base.sol#L102), [102](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20Base.sol#L102)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC1155Vault.sol

64: 		            destOwner: _op.destOwner != address(0) ? _op.destOwner : msg.sender,

108: 		        if (to == address(0) || to == address(this)) revert VAULT_INVALID_TO();

108: 		        if (to == address(0) || to == address(this)) revert VAULT_INVALID_TO();

249: 		            if (bridgedToCanonical[_op.token].addr != address(0)) {

293: 		        if (btoken_ == address(0)) {
```

[[64](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L64), [108](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L108), [108](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L108), [249](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L249), [293](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L293)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC20Vault.sol

158: 		        if (_btokenNew == address(0) || bridgedToCanonical[_btokenNew].addr != address(0)) {

158: 		        if (_btokenNew == address(0) || bridgedToCanonical[_btokenNew].addr != address(0)) {

158: 		        if (_btokenNew == address(0) || bridgedToCanonical[_btokenNew].addr != address(0)) {

170: 		        if (btokenOld_ != address(0)) {

215: 		        if (_op.token == address(0)) revert VAULT_INVALID_TOKEN();

227: 		            destOwner: _op.destOwner != address(0) ? _op.destOwner : msg.sender,

267: 		        if (to == address(0) || to == address(this)) revert VAULT_INVALID_TO();

267: 		        if (to == address(0) || to == address(this)) revert VAULT_INVALID_TO();

358: 		        if (bridgedToCanonical[_token].addr != address(0)) {

397: 		        if (btoken == address(0)) {
```

[[158](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L158), [158](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L158), [158](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L158), [170](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L170), [215](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L215), [227](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L227), [267](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L267), [267](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L267), [358](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L358), [397](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L397)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC721Vault.sol

50: 		            destOwner: _op.destOwner != address(0) ? _op.destOwner : msg.sender,

91: 		        if (to == address(0) || to == address(this)) revert VAULT_INVALID_TO();

91: 		        if (to == address(0) || to == address(this)) revert VAULT_INVALID_TO();

195: 		            if (bridgedToCanonical[_op.token].addr != address(0)) {

230: 		        if (btoken_ == address(0)) {
```

[[50](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L50), [91](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L91), [91](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L91), [195](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L195), [230](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L230)]

```solidity
File: packages/protocol/contracts/tokenvault/LibBridgedToken.sol

21: 		            _srcToken == address(0) || _srcChainId == 0 || _srcChainId == block.chainid
22: 		                || bytes(_symbol).length == 0 || bytes(_name).length == 0

21: 		            _srcToken == address(0) || _srcChainId == 0 || _srcChainId == block.chainid
22: 		                || bytes(_symbol).length == 0 || bytes(_name).length == 0

21: 		            _srcToken == address(0) || _srcChainId == 0 || _srcChainId == block.chainid

21: 		            _srcToken == address(0) || _srcChainId == 0 || _srcChainId == block.chainid

21: 		            _srcToken == address(0) || _srcChainId == 0 || _srcChainId == block.chainid
```

[[21-22](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/LibBridgedToken.sol#L21-L22), [21-22](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/LibBridgedToken.sol#L21-L22), [21](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/LibBridgedToken.sol#L21), [21](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/LibBridgedToken.sol#L21), [21](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/LibBridgedToken.sol#L21)]

```solidity
File: packages/protocol/contracts/verifiers/SgxVerifier.sol

107: 		            if (instances[idx].addr == address(0)) revert SGX_INVALID_INSTANCE();

124: 		        if (automataDcapAttestation == address(0)) {

215: 		            if (_instances[i] == address(0)) revert SGX_INVALID_INSTANCE();

234: 		        if (instance == address(0)) return false;
```

[[107](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L107), [124](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L124), [215](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L215), [234](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L234)]

```solidity
File: packages/protocol/contracts/L1/hooks/AssignmentHook.sol

109: 		        if (assignment.feeToken == address(0)) {

120: 		        if (input.tip != 0 && block.coinbase != address(0)) {

120: 		        if (input.tip != 0 && block.coinbase != address(0)) {
```

[[109](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L109), [120](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L120), [120](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/hooks/AssignmentHook.sol#L120)]

```solidity
File: packages/protocol/contracts/L1/libs/LibDepositing.sol

44: 		        address recipient_ = _recipient == address(0) ? msg.sender : _recipient;
```

[[44](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibDepositing.sol#L44)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProposing.sol

81: 		        if (params.assignedProver == address(0)) {

85: 		        if (params.coinbase == address(0)) {

310: 		            if (proposerOne != address(0) && msg.sender != proposerOne) {

310: 		            if (proposerOne != address(0) && msg.sender != proposerOne) {

316: 		        return proposer == address(0) || msg.sender == proposer;

316: 		        return proposer == address(0) || msg.sender == proposer;
```

[[81](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L81), [85](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L85), [310](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L310), [310](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L310), [316](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L316), [316](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProposing.sol#L316)]

```solidity
File: packages/protocol/contracts/L1/libs/LibProving.sol

163: 		            if (verifier != address(0)) {

224: 		                assert(ts.validityBond == 0 && ts.contestBond == 0 && ts.contester == address(0));

224: 		                assert(ts.validityBond == 0 && ts.contestBond == 0 && ts.contester == address(0));

239: 		                if (ts.contester != address(0)) revert L1_ALREADY_CONTESTED();

363: 		        if (_ts.contester != address(0)) {
```

[[163](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L163), [224](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L224), [224](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L224), [239](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L239), [363](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibProving.sol#L363)]

```solidity
File: packages/protocol/contracts/L1/libs/LibVerifying.sol

145: 		                if (ts.contester != address(0)) {

148: 		                    if (tierProvider == address(0)) {
```

[[145](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L145), [148](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/libs/LibVerifying.sol#L148)]

```solidity
File: packages/protocol/contracts/L1/provers/Guardians.sol

82: 		            if (guardian == address(0)) revert INVALID_GUARDIAN();
```

[[82](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/provers/Guardians.sol#L82)]

</details>

---

### [G-59] Use scratch space for building calldata with assembly

If an external call's calldata can fit into two or fewer words, use the scratch space to build the calldata, rather than allowing Solidity to do a memory expansion.

_There are 333 instances of this issue._

<details>
<summary>Expand findings</summary>

```solidity
File: packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol

167: 		            V3Parser.parseInput(quote, address(pemCertLib));

313: 		        bytes32 expectedAuthDataHash = bytes32(qeEnclaveReport.reportData.substring(0, 32));

321: 		                V3Parser.packQEReport(authDataV3.pckSignedQeReport);

378: 		        ) = V3Parser.validateParsedInput(v3quote);

424: 		                (certDecodedSuccessfully, parsedQuoteCerts[i]) = pemCertLib.decodeCert(
425: 		                    authDataV3.certification.decodedCertDataArray[i], isPckCert
426: 		                );

437: 		            bool tcbConfigured = LibString.eq(parsedFmspc, fetchedTcbInfo.fmspc);

443: 		            bool pceidMatched = LibString.eq(pckCert.pck.sgxExtension.pceid, fetchedTcbInfo.pceid);
```

[[167](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L167), [313](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L313), [321](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L321), [378](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L378), [424-426](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L424-L426), [437](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L437), [443](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol#L443)]

```solidity
File: packages/protocol/contracts/bridge/Bridge.sol

150: 		        ISignalService(resolve("signal_service", false)).sendSignal(msgHash_);

174: 		            if (!ISignalService(signalService).isSignalSent(address(this), msgHash)) {

195: 		            if (_message.from.supportsInterface(type(IRecallableSender).interfaceId)) {

206: 		                _message.srcOwner.sendEther(_message.value);

295: 		                refundTo.sendEther(_message.fee + refundAmount);

298: 		                msg.sender.sendEther(_message.fee);

299: 		                refundTo.sendEther(refundAmount);

342: 		        return ISignalService(resolve("signal_service", false)).isSignalSent({
343: 		            _app: address(this),
344: 		            _signal: hashMessage(_message)
345: 		        });

493: 		                && _message.to.isContract()

522: 		            ISignalService(resolve("signal_service", false)).sendSignal(
523: 		                signalForFailedMessage(_msgHash)
524: 		            );

591: 		        (success_,) = _signalService.staticcall(data);
```

[[150](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L150), [174](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L174), [195](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L195), [206](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L206), [295](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L295), [298](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L298), [299](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L299), [342-345](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L342-L345), [493](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L493), [522-524](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L522-L524), [591](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/bridge/Bridge.sol#L591)]

```solidity
File: packages/protocol/contracts/common/AddressResolver.sol

83: 		        addr_ = payable(IDefaultResolver(addressManager).getAddress(_chainId, _name));
```

[[83](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/common/AddressResolver.sol#L83)]

```solidity
File: packages/protocol/contracts/L1/TaikoL1.sol

113: 		        LibProving.pauseProving(state, _pause);
```

[[113](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L1/TaikoL1.sol#L113)]

```solidity
File: packages/protocol/contracts/L2/CrossChainOwned.sol

45: 		        IBridge.Context memory ctx = IBridge(msg.sender).context();

50: 		        (bool success,) = address(this).call(txdata);
```

[[45](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/CrossChainOwned.sol#L45), [50](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/CrossChainOwned.sol#L50)]

```solidity
File: packages/protocol/contracts/L2/Lib1559Math.sol

45: 		        return uint256(LibFixedPointMath.exp(int256(input)));
```

[[45](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/Lib1559Math.sol#L45)]

```solidity
File: packages/protocol/contracts/L2/TaikoL2.sol

174: 		            _to.sendEther(address(this).balance);

176: 		            IERC20(_token).safeTransfer(_to, IERC20(_token).balanceOf(address(this)));

176: 		            IERC20(_token).safeTransfer(_to, IERC20(_token).balanceOf(address(this)));

284: 		            gasExcess_ = uint64(excess.min(type(uint64).max));

290: 		            basefee_ = Lib1559Math.basefee(
291: 		                gasExcess_, uint256(_config.basefeeAdjustmentQuotient) * _config.gasTargetPerL1Block
292: 		            );
```

[[174](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L174), [176](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L176), [176](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L176), [284](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L284), [290-292](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/L2/TaikoL2.sol#L290-L292)]

```solidity
File: packages/protocol/contracts/libs/Lib4844.sol

43: 		        (bool ok, bytes memory ret) = POINT_EVALUATION_PRECOMPILE_ADDRESS.staticcall(
44: 		            abi.encodePacked(_blobHash, _x, _y, _commitment, _pointProof)
45: 		        );
```

[[43-45](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/libs/Lib4844.sol#L43-L45)]

```solidity
File: packages/protocol/contracts/libs/LibAddress.sol

54: 		        if (!Address.isContract(_addr)) return false;

56: 		        try IERC165(_addr).supportsInterface(_interfaceId) returns (bool _result) {

70: 		        if (Address.isContract(_addr)) {

71: 		            return IERC1271(_addr).isValidSignature(_hash, _sig) == _EIP1271_MAGICVALUE;

73: 		            return ECDSA.recover(_hash, _sig) == _addr;
```

[[54](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/libs/LibAddress.sol#L54), [56](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/libs/LibAddress.sol#L56), [70](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/libs/LibAddress.sol#L70), [71](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/libs/LibAddress.sol#L71), [73](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/libs/LibAddress.sol#L73)]

```solidity
File: packages/protocol/contracts/libs/LibTrieProof.sol

52: 		            RLPReader.RLPItem[] memory accountState = RLPReader.readList(rlpAccount);

55: 		                bytes32(RLPReader.readBytes(accountState[_ACCOUNT_FIELD_INDEX_STORAGE_HASH]));

61: 		            bytes.concat(_slot), RLPWriter.writeUint(uint256(_value)), _storageProof, storageRoot_

61: 		            bytes.concat(_slot), RLPWriter.writeUint(uint256(_value)), _storageProof, storageRoot_
```

[[52](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/libs/LibTrieProof.sol#L52), [55](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/libs/LibTrieProof.sol#L55), [61](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/libs/LibTrieProof.sol#L61), [61](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/libs/LibTrieProof.sol#L61)]

```solidity
File: packages/protocol/contracts/team/TimelockTokenPool.sol

171: 		        address recipient = ECDSA.recover(hash, _sig);
```

[[171](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/team/TimelockTokenPool.sol#L171)]

```solidity
File: packages/protocol/contracts/tokenvault/BaseVault.sol

53: 		        ctx_ = IBridge(msg.sender).context();

64: 		        ctx_ = IBridge(msg.sender).context();
```

[[53](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BaseVault.sol#L53), [64](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BaseVault.sol#L64)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC1155.sol

54: 		        __ERC1155_init(LibBridgedToken.buildURI(_srcToken, _srcChainId));

116: 		        return LibBridgedToken.buildName(__name, srcChainId);

122: 		        return LibBridgedToken.buildSymbol(__symbol);
```

[[54](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC1155.sol#L54), [116](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC1155.sol#L116), [122](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC1155.sol#L122)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC20.sol

97: 		        return LibBridgedToken.buildName(super.name(), srcChainId);

108: 		        return LibBridgedToken.buildSymbol(super.symbol());
```

[[97](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20.sol#L97), [108](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20.sol#L108)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC20Base.sol

82: 		            IBridgedERC20(migratingAddress).mint(_account, _amount);
```

[[82](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC20Base.sol#L82)]

```solidity
File: packages/protocol/contracts/tokenvault/BridgedERC721.sol

88: 		        return LibBridgedToken.buildName(super.name(), srcChainId);

94: 		        return LibBridgedToken.buildSymbol(super.symbol());

110: 		                LibBridgedToken.buildURI(srcToken, srcChainId), Strings.toString(_tokenId)

110: 		                LibBridgedToken.buildURI(srcToken, srcChainId), Strings.toString(_tokenId)
```

[[88](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC721.sol#L88), [94](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC721.sol#L94), [110](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC721.sol#L110), [110](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/BridgedERC721.sol#L110)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC1155Vault.sol

51: 		        if (!_op.token.supportsInterface(ERC1155_INTERFACE_ID)) {

112: 		        to.sendEther(msg.value);

146: 		        message.srcOwner.sendEther(message.value);

200: 		            || BaseVault.supportsInterface(interfaceId);

263: 		                try t.name() returns (string memory _name) {

266: 		                try t.symbol() returns (string memory _symbol) {
```

[[51](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L51), [112](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L112), [146](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L146), [200](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L200), [263](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L263), [266](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC1155Vault.sol#L266)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC20Vault.sol

164: 		        if (IBridgedERC20(_btokenNew).owner() != owner()) {

184: 		            IBridgedERC20(btokenOld_).changeMigrationStatus(_btokenNew, false);

185: 		            IBridgedERC20(_btokenNew).changeMigrationStatus(btokenOld_, true);

271: 		        to.sendEther(msg.value);

304: 		        _message.srcOwner.sendEther(_message.value);

330: 		            IERC20(token_).safeTransfer(_to, _amount);

333: 		            IBridgedERC20(token_).mint(_to, _amount);

360: 		            IBridgedERC20(_token).burn(msg.sender, _amount);

368: 		                decimals: meta.decimals(),

369: 		                symbol: meta.symbol(),

370: 		                name: meta.name()

378: 		            uint256 _balance = t.balanceOf(address(this));

380: 		            balanceChange_ = t.balanceOf(address(this)) - _balance;
```

[[164](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L164), [184](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L184), [185](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L185), [271](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L271), [304](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L304), [330](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L330), [333](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L333), [360](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L360), [368](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L368), [369](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L369), [370](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L370), [378](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L378), [380](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC20Vault.sol#L380)]

```solidity
File: packages/protocol/contracts/tokenvault/ERC721Vault.sol

38: 		        if (!_op.token.supportsInterface(ERC721_INTERFACE_ID)) {

95: 		        to.sendEther(msg.value);

129: 		        _message.srcOwner.sendEther(_message.value);

176: 		                BridgedERC721(token_).mint(_to, _tokenIds[i]);

198: 		                    BridgedERC721(_op.token).burn(_user, _op.tokenIds[i]);

206: 		                    symbol: t.symbol(),

207: 		                    name: t.name()
```

[[38](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L38), [95](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L95), [129](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L129), [176](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L176), [198](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L198), [206](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L206), [207](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/ERC721Vault.sol#L207)]

```solidity
File: packages/protocol/contracts/tokenvault/LibBridgedToken.sol

36: 		        return string.concat("Bridged ", _name, unicode" (⭀", Strings.toString(_srcChainId), ")");

40: 		        return string.concat(_symbol, ".t");

56: 		                Strings.toHexString(uint160(_srcToken), 20),

58: 		                Strings.toString(_srcChainId),
```

[[36](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/LibBridgedToken.sol#L36), [40](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/LibBridgedToken.sol#L40), [56](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/LibBridgedToken.sol#L56), [58](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/tokenvault/LibBridgedToken.sol#L58)]

```solidity
File: packages/protocol/contracts/verifiers/SgxVerifier.sol

128: 		        (bool verified,) = IAttestation(automataDcapAttestation).verifyParsedQuote(_attestation);

156: 		        bytes memory signature = Bytes.slice(_proof.data, 24);

159: 		            ECDSA.recover(getSignedHash(_tran, newInstance, _ctx.prover, _ctx.metaHash), signature);

185: 		                ITaikoL1(taikoL1).getConfig().chainId,
```

[[128](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L128), [156](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L156), [159](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L159), [185](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/verifiers/SgxVerifier.sol#L185)]

```solidity
File: packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol

82: 		        uint256 root = der.root();

85: 		        uint256 tbsParentPtr = der.firstChildOf(root);

88: 		        uint256 tbsPtr = der.firstChildOf(tbsParentPtr);

104: 		        tbsPtr = der.nextSiblingOf(tbsPtr);

107: 		            bytes memory serialNumBytes = der.bytesAt(tbsPtr);

111: 		        tbsPtr = der.nextSiblingOf(tbsPtr);

112: 		        tbsPtr = der.nextSiblingOf(tbsPtr);

115: 		            uint256 issuerPtr = der.firstChildOf(tbsPtr);

116: 		            issuerPtr = der.firstChildOf(issuerPtr);

117: 		            issuerPtr = der.firstChildOf(issuerPtr);

118: 		            issuerPtr = der.nextSiblingOf(issuerPtr);

119: 		            cert.pck.issuerName = string(der.bytesAt(issuerPtr));

120: 		            bool issuerNameIsValid = LibString.eq(cert.pck.issuerName, PLATFORM_ISSUER_NAME)

121: 		                || LibString.eq(cert.pck.issuerName, PROCESSOR_ISSUER_NAME);

127: 		        tbsPtr = der.nextSiblingOf(tbsPtr);

130: 		            uint256 notBeforePtr = der.firstChildOf(tbsPtr);

131: 		            uint256 notAfterPtr = der.nextSiblingOf(notBeforePtr);

132: 		            bytes1 notBeforeTag = der[notBeforePtr.ixs()];

133: 		            bytes1 notAfterTag = der[notAfterPtr.ixs()];

140: 		            cert.notBefore = X509DateUtils.toTimestamp(der.bytesAt(notBeforePtr));

140: 		            cert.notBefore = X509DateUtils.toTimestamp(der.bytesAt(notBeforePtr));

141: 		            cert.notAfter = X509DateUtils.toTimestamp(der.bytesAt(notAfterPtr));

141: 		            cert.notAfter = X509DateUtils.toTimestamp(der.bytesAt(notAfterPtr));

144: 		        tbsPtr = der.nextSiblingOf(tbsPtr);

147: 		            uint256 subjectPtr = der.firstChildOf(tbsPtr);

148: 		            subjectPtr = der.firstChildOf(subjectPtr);

149: 		            subjectPtr = der.firstChildOf(subjectPtr);

150: 		            subjectPtr = der.nextSiblingOf(subjectPtr);

151: 		            cert.pck.commonName = string(der.bytesAt(subjectPtr));

152: 		            if (!LibString.eq(cert.pck.commonName, PCK_COMMON_NAME)) {

157: 		        tbsPtr = der.nextSiblingOf(tbsPtr);

161: 		            uint256 subjectPublicKeyInfoPtr = der.firstChildOf(tbsPtr);

162: 		            subjectPublicKeyInfoPtr = der.nextSiblingOf(subjectPublicKeyInfoPtr);

166: 		            uint256 sigPtr = der.nextSiblingOf(tbsParentPtr);

167: 		            sigPtr = der.nextSiblingOf(sigPtr);

171: 		            sigPtr = NodePtr.getPtr(sigPtr.ixs() + 3, sigPtr.ixf() + 3, sigPtr.ixl());

171: 		            sigPtr = NodePtr.getPtr(sigPtr.ixs() + 3, sigPtr.ixf() + 3, sigPtr.ixl());

171: 		            sigPtr = NodePtr.getPtr(sigPtr.ixs() + 3, sigPtr.ixf() + 3, sigPtr.ixl());

173: 		            sigPtr = der.firstChildOf(sigPtr);

174: 		            bytes memory sigX = _trimBytes(der.bytesAt(sigPtr), 32);

176: 		            sigPtr = der.nextSiblingOf(sigPtr);

177: 		            bytes memory sigY = _trimBytes(der.bytesAt(sigPtr), 32);

179: 		            cert.tbsCertificate = der.allBytesAt(tbsParentPtr);

180: 		            cert.pubKey = _trimBytes(der.bytesAt(subjectPublicKeyInfoPtr), 64);

186: 		            tbsPtr = der.nextSiblingOf(tbsPtr);

189: 		            if (der[tbsPtr.ixs()] != 0xA3) {

193: 		            tbsPtr = der.firstChildOf(tbsPtr);

194: 		            tbsPtr = der.firstChildOf(tbsPtr);

208: 		            cert.pck.sgxExtension.pceid = LibString.toHexStringNoPrefix(pceidBytes);

209: 		            cert.pck.sgxExtension.fmspc = LibString.toHexStringNoPrefix(fmspcBytes);

222: 		        uint256 beginPos = LibString.indexOf(pemData, HEADER);

223: 		        uint256 endPos = LibString.indexOf(pemData, FOOTER);

241: 		        string[] memory split = LibString.split(contentSlice, string(delimiter));

245: 		            contentStr = LibString.concat(contentStr, split[i]);

266: 		        output = input.substring(lengthDiff, expectedLength);

287: 		            uint256 internalPtr = der.firstChildOf(tbsPtr);

288: 		            if (der[internalPtr.ixs()] != 0x06) {

292: 		            if (BytesUtils.compareBytes(der.bytesAt(internalPtr), SGX_EXTENSION_OID)) {

292: 		            if (BytesUtils.compareBytes(der.bytesAt(internalPtr), SGX_EXTENSION_OID)) {

294: 		                internalPtr = der.nextSiblingOf(internalPtr);

295: 		                uint256 extnValueParentPtr = der.rootOfOctetStringAt(internalPtr);

296: 		                uint256 extnValuePtr = der.firstChildOf(extnValueParentPtr);

302: 		                    uint256 extnValueOidPtr = der.firstChildOf(extnValuePtr);

303: 		                    if (der[extnValueOidPtr.ixs()] != 0x06) {

306: 		                    if (BytesUtils.compareBytes(der.bytesAt(extnValueOidPtr), TCB_OID)) {

306: 		                    if (BytesUtils.compareBytes(der.bytesAt(extnValueOidPtr), TCB_OID)) {

310: 		                    if (BytesUtils.compareBytes(der.bytesAt(extnValueOidPtr), PCEID_OID)) {

310: 		                    if (BytesUtils.compareBytes(der.bytesAt(extnValueOidPtr), PCEID_OID)) {

312: 		                        uint256 pceidPtr = der.nextSiblingOf(extnValueOidPtr);

313: 		                        pceidBytes = der.bytesAt(pceidPtr);

316: 		                    if (BytesUtils.compareBytes(der.bytesAt(extnValueOidPtr), FMSPC_OID)) {

316: 		                    if (BytesUtils.compareBytes(der.bytesAt(extnValueOidPtr), FMSPC_OID)) {

318: 		                        uint256 fmspcPtr = der.nextSiblingOf(extnValueOidPtr);

319: 		                        fmspcBytes = der.bytesAt(fmspcPtr);

323: 		                    if (extnValuePtr.ixl() < extnValueParentPtr.ixl()) {

323: 		                    if (extnValuePtr.ixl() < extnValueParentPtr.ixl()) {

324: 		                        extnValuePtr = der.nextSiblingOf(extnValuePtr);

333: 		            if (tbsPtr.ixl() < tbsParentPtr.ixl()) {

333: 		            if (tbsPtr.ixl() < tbsParentPtr.ixl()) {

334: 		                tbsPtr = der.nextSiblingOf(tbsPtr);

350: 		        uint256 tcbPtr = der.nextSiblingOf(oidPtr);

352: 		        uint256 svnParentPtr = der.firstChildOf(tcbPtr);

355: 		            uint256 svnPtr = der.firstChildOf(svnParentPtr); // OID

356: 		            uint256 svnValuePtr = der.nextSiblingOf(svnPtr); // value

357: 		            bytes memory svnValueBytes = der.bytesAt(svnValuePtr);

361: 		            if (BytesUtils.compareBytes(der.bytesAt(svnPtr), PCESVN_OID)) {

361: 		            if (BytesUtils.compareBytes(der.bytesAt(svnPtr), PCESVN_OID)) {

371: 		            svnParentPtr = der.nextSiblingOf(svnParentPtr);
```

[[82](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L82), [85](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L85), [88](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L88), [104](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L104), [107](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L107), [111](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L111), [112](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L112), [115](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L115), [116](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L116), [117](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L117), [118](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L118), [119](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L119), [120](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L120), [121](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L121), [127](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L127), [130](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L130), [131](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L131), [132](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L132), [133](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L133), [140](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L140), [140](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L140), [141](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L141), [141](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L141), [144](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L144), [147](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L147), [148](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L148), [149](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L149), [150](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L150), [151](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L151), [152](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L152), [157](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L157), [161](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L161), [162](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L162), [166](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L166), [167](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L167), [171](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L171), [171](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L171), [171](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L171), [173](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L173), [174](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L174), [176](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L176), [177](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L177), [179](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L179), [180](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L180), [186](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L186), [189](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L189), [193](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L193), [194](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L194), [208](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L208), [209](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L209), [222](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L222), [223](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L223), [241](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L241), [245](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L245), [266](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L266), [287](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L287), [288](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L288), [292](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L292), [292](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L292), [294](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L294), [295](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L295), [296](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L296), [302](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L302), [303](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L303), [306](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L306), [306](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a472322322705133b11/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol#L306), [310](https://github.com/code-423n4/2024-03-taiko/blob/f58384f44dbf4c6535264a47232232

</details>

**[dantaik (Taiko) confirmed and commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/344#issuecomment-2036531972):**

> Appreciate the feedback, some suggestions have been taken, as shown in https://github.com/taikoxyz/taiko-mono/pull/16627.

---

# Audit Analysis

For this audit, 22 analysis reports were submitted by wardens. An analysis report examines the codebase as a whole, providing observations and advice on such topics as architecture, mechanism, or approach. The [report highlighted below](https://github.com/code-423n4/2024-03-taiko-findings/issues/253) by **kaveyjoe** received the top score from the judge.

_The following wardens also submitted reports: [MrPotatoMagic](https://github.com/code-423n4/2024-03-taiko-findings/issues/380), [yongskiws](https://github.com/code-423n4/2024-03-taiko-findings/issues/379), [fouzantanveer](https://github.com/code-423n4/2024-03-taiko-findings/issues/350), [0xepley](https://github.com/code-423n4/2024-03-taiko-findings/issues/317), [Sathish9098](https://github.com/code-423n4/2024-03-taiko-findings/issues/313), [hassanshakeel13](https://github.com/code-423n4/2024-03-taiko-findings/issues/303), [popeye](https://github.com/code-423n4/2024-03-taiko-findings/issues/244), [joaovwfreire](https://github.com/code-423n4/2024-03-taiko-findings/issues/216), [aariiif](https://github.com/code-423n4/2024-03-taiko-findings/issues/158), [Myd](https://github.com/code-423n4/2024-03-taiko-findings/issues/145), [roguereggiant](https://github.com/code-423n4/2024-03-taiko-findings/issues/89), [cheatc0d3](https://github.com/code-423n4/2024-03-taiko-findings/issues/369), [JCK](https://github.com/code-423n4/2024-03-taiko-findings/issues/356), [hunter_w3b](https://github.com/code-423n4/2024-03-taiko-findings/issues/316), [pavankv](https://github.com/code-423n4/2024-03-taiko-findings/issues/290), [LinKenji](https://github.com/code-423n4/2024-03-taiko-findings/issues/275), [0xbrett8571](https://github.com/code-423n4/2024-03-taiko-findings/issues/272), [clara](https://github.com/code-423n4/2024-03-taiko-findings/issues/236), [albahaca](https://github.com/code-423n4/2024-03-taiko-findings/issues/225), [emerald7017](https://github.com/code-423n4/2024-03-taiko-findings/issues/157), and [foxb868](https://github.com/code-423n4/2024-03-taiko-findings/issues/142)._

## 1. Introduction

An Ethereum-equivalent ZK-Rollup allows for scaling Ethereum without sacrificing security or compatibility. Advancements in Zero-Knowledge Proof cryptography and its application towards proving Ethereum Virtual Machine (EVM) execution have led to a flourishing of ZK-EVMs, now with further design decisions to choose from. Taiko aims to be a decentralized ZK-Rollup, prioritizing Ethereum-equivalence. Supporting all existing Ethereum applications, tooling, and infrastructure is the primary goal and benefit of this path. Besides the maximally compatible ZK-EVM component, which proves the correctness of EVM computation on the rollup, Taiko must implement a layer-2 blockchain architecture to support it.

Taiko aims to be a fully Ethereum-equivalent ZK-Rollup. aim to scale Ethereum in a manner that emulates Ethereum itself at a technical level, and a principles level.

**Taiko consists of three main parts**:

- the ZK-EVM circuits (for proof generation)
- the L2 rollup node (for managing the rollup chain)
- the protocol on L1 (for connecting these two parts together for rollup protocol verification).
  Blocks in the Taiko L2 blockchain consist of collections of transactions that are executed sequentially. New blocks can be appended to the chain to update its state, which can be calculated by following the protocol rules for the execution of the transactions.

### 1.1 How Does Taiko Work?

Taiko operates by utilizing a Zero Knowledge Rollup (ZK-Rollup) mechanism, specifically designed to scale the Ethereum blockchain without compromising its foundational features of security, censorship resistance, and permissionless access. Here's a breakdown of how Taiko functions:

- Zero Knowledge Proofs (ZKPs): Taiko leverages ZKPs to validate transactions confidentially, reducing data processing on Ethereum's mainnet. This efficiency cuts costs and increases transaction speed.
- Integration with Ethereum L1: Unlike rollups that use a centralized sequencer, Taiko's transactions are sequenced by Ethereum's Layer 1 validators. This method, called based sequencing, ensures that Taiko inherits Ethereum's security and decentralization properties.
- Smart Contracts and Governance: Taiko operates through smart contracts on Ethereum, detailing its protocol. Governance, including protocol updates, is managed by the Taiko DAO, ensuring community-driven decisions.
- Open Source and Compatibility: As an open-source platform, Taiko allows developers to deploy dApps seamlessly, maintaining Ethereum's ease of use and accessibility.
- Decentralized Validation: Taiko supports a decentralized model for proposers and validators, enhancing network security and integrity. Ethereum L1 validators also play a pivotal role, emphasizing decentralization.
- Community-Driven Governance: The Taiko DAO, driven by TKO token holders, oversees significant protocol decisions. This governance model promotes inclusivity and community engagement.

In essence, Taiko's approach, built on zero knowledge proofs and closely integrated with Ethereum's infrastructure, offers a scalable and secure solution while adhering to Ethereum’s foundational values. Its commitment to open-source development and community governance aligns well with the ethos of the wider Ethereum community.

### 1.2 Mechanism of Taiko

**Mechanism of action of Taiko**
Taiko's operating mechanism is based on the cooperation of three main subjects:

Proposer: Responsible for creating blocks from user transactions at layer 2 and proposing to Ethereum.
Prover: Create zk-Snark proofs to check the validity of transactions from layer 2, blocks proposed by the Proposer.
Node runner: Executes transactions in the network. Both the proposer and the prover must run a node to fulfill a role in the network.
Taiko's transaction confirmation process takes place as follows:
Users make transactions on layer 2 Taiko.

Proposer creates block rollup, synthesizes transactions from users at layer 2 and proposes to Ethereum.
Prover creates valid proof, proving the correctness of the block just submitted.
The block will then mark complete on the chain. The block status changes from green to yellow after being validated.

## 2. Architecture and protocol overview

_Note: to view the provided image, please see the original submission [here](https://github.com/code-423n4/2024-03-taiko-findings/issues/253)._

- Block execution is deterministic once the block is appended to the proposed block list in the TaikoL1 contract. Once registered, the protocol ensures that all block properties are immutable. This makes the block execution deterministic: the post-block state can now be calculated by anyone. As such, the block is immediately verified. This also ensures that no one knows more about the latest state than anyone else, which would create an unfair advantage.
- Block metadata is validated when the block is proposed. The prover has no impact on how the block is executed and what the post-block state is;
- The proof can be generated after the block is checked for validity and its parent block’s state is known
- As all proposed blocks are deterministic, they can be proven in parallel, because all intermediate states between blocks are known and unique. Once a proof is submitted for the block and its parent block, we call the block on-chain verified.

**1 . Block proposal**

- Anyone can run a Taiko sequencer. It monitors the Taiko network mempool for signed and submitted txs.
- The sequencer determines the tx order in the block.
- When a block is built, the proposing sequencer submits a proposeBlock transaction (block = transaction list + metadata) directly to Ethereum through the TaikoL1 contract. There is no consensus among L2 nodes, but there is some networking between L2 nodes (syncing, sharing transactions, etc.) However, the order of Taiko blocks on Ethereum (L1) is determined by the Ethereum node.
- All Taiko nodes connect to Ethereum nodes and subscribe to Ethereum's block events. When a Taiko block proposal is confirmed, the block is appended to a queue on L1 in a TaikoL1 contract. Taiko nodes can then download these blocks and execute valid transactions in each block. Taiko nodes track which L2 blocks are verified by subscribing to another TaikoL1 event on Ethereum.

**2. Block validation**

- The block consists of a transaction list (txList) and metadata. The txList of an L2 block will eventually (when EIP-4844 is live) be part of a blob in the L1 Consensus Layer (CL).
- txList is not directly accessible to L1 contracts. Therefore, a ZKP shall prove that the chosen txList is a slice of the given blob data.
- Block validity criteria that all blocks need to respect: K_maxBobSize, K_BlockMaxTxs, K_BlockMaxGasLimit and config.anchorTxGasLimit
- Once the block is proposed, the Taiko client checks if the block is decoded into a list of transactions
- Taiko client validates each enclosed transaction and generates a tracelog for each transaction for the prover to use as witness data. If a tx is invalid, it will be dropped.
- The first transaction in the Taiko L2 block is always an anchoring transaction, which verifies the 256 hashes of the latest blocks, the L2 chain ID and the EIP-1559 base fee

**3. Block proving**

- Anyone can run a prover.
- Proof can be prepared if all valid txs have been executed; and the parent block’s state is known. The proof proves the change in the block state.
- The block can be verified once the parent block is verified; and there is a valid ZKP proving the transition from the parent state to the current block’s state.
- only the first proof will be accepted for any given block transition (fork choice).
- The address receiving the reward is coupled with the proof, preventing it from being stolen by other provers.

**Sequencer design (sequencers are called proposers in Taiko)**

- Based sequencing/L1-sequencing: as an Ethereum-equivalent rollup, Taiko can reuse Ethereum L1 validators to drive the sequencing of Taiko blocks, inheriting L1 liveness and decentralization. This is also called "based sequencing", or a "based rollup". More info on this: https://ethresear.ch/t/based-rollups-superpowers-from-l1-sequencing/15016
- Based sequencing inherits the decentralization of L1 and naturally reuses L1 searcher-builder-proposer infrastructure. L1 searchers and block builders are incentivised to extract rollup MEV by including rollup blocks within their L1 bundles and L1 blocks. This then incentivises L1 proposers to include rollup blocks on the L1.
  Details:

- L2 sequencers (proposers) deliver L2 blocks (as bundles) directly to L1 builders (they act like the searchers in the L1 PBS setup). Builders take L2 blocks as regular bundles (similarly as they get L1 bundles from searchers)
- L2 sequencers will earn some MEV (here MEV includes (i) L2 block fees and (ii) MEV from txs reorgs etc.) - this is their motivation to be proposers. In the same manner as on L1, in the chain of searcher >> builder >> proposer, the proposer gets most MEV but searchers still get some share to make profits. It works the same way for L2 sequencers.
- As mentioned anyone can propose a block anytime (there are no time slots on Taiko like on Ethereum the 12-second slots)
- L2 sequencers build blocks and they compete for the most lucrative txs. Multiple blocks are proposed in parallel based on the same L2 mempool. These blocks are sent to the L1 builders as bundles, and it may happen that some transactions are included in multiple bundles proposed by L2 sequencers.
- When the L1 builders choose which L2 block to accept – they run simulations to find the most profitable bundle. If some txs in the L2 block were already taken by another builder and proposed by the Ethereum validator (this means that block already reached finality), then they are not counted in the current bundle anymore but get excluded from it. However the other L2 blocks proposed should still be valuable enough to be selected and included by an L1 builder within negligible time.
- Theoretically it could happen that most of the txs in a proposed L2 block were already included by L1 builders through other L2 blocks, and thus it is not anymore profitable, but this is expected to be a very rare, marginal case.

**Fee structure**

L2 tx fee = L2 EIP-1559* base fee + L1 tx fee + prover fee + proposer fee*

_Note: to view the provided image, please see the original submission [here](https://github.com/code-423n4/2024-03-taiko-findings/issues/253)._

L2 EIP-1559 fee = L2 EIP-1559 tip (goes to the proposer) + L2 EIP-1559 base fee (goes to the Taiko DAO).

Once a proposer has collected enough transactions, most probably including and ordering them with the intent to generate a (maxim) profit, they create a block.

- Profit means that for the proposer, the sum of transaction fees (L2 tx fees) from the block is larger than L1 tx fee + prover fee + EIP-1559 base fee.

**Prover economics and prover mechanisms**

1 . First prover wins and gets rewarded only
One proof should be confirmed for one “window.” A “window” is a period of time in which multiple blocks are proposed. Any prover can submit a proof for any amount of blocks at any time.

- There is a target reward, x, that is paid to the prover if they confirm the proof exactly at the target window, t = n. If proven earlier, the reward is lower, if later, reward is higher.
- A target reward is defined based on the historical reward values and is adjusted after each window depending on the proof confirmation time

_Note: to view the provided image, please see the original submission [here](https://github.com/code-423n4/2024-03-taiko-findings/issues/253)._

- Effects:
  - To be efficient within this design, a prover should be able to find an optimal trade-off point between (i) confirming the proof as late as possible (to get the higher reward) and (ii) confirming the proof earlier than all other provers.
  - to confirm the proof as early as possible is not an optimal strategy for the prover; confirming all proofs as fast as possible decreases the rewards making it unreasonable for provers (but beneficial for users).

2 . Staking-based prover design

one prover is pseudo-randomly chosen for each block from a pool which includes the top 32 provers, and assigns it to a proposed block. This designated prover must then submit a valid proof within a set time window for block verification. If the prover fails to submit the proof on time, the prover’s stake will be slashed. Prover exit is possible anytime, with a withdrawal time of one week.

- Prover weight W is calculated based on the stake A and expected reward per gas R. This weight reflects probability to be chosen.

_Note: to view the provided image, please see the original submission [here](https://github.com/code-423n4/2024-03-taiko-findings/issues/253)._

- The current fee per gas F is calculated based on historical values and is supplied by the core protocol.
- Three other parameters unique for each prover; claimed while joining the pool:

  1. Amount of Taiko’s TTKO tokens to stake A;
  2. The expected reward per gas, R, is limited to (75% – 125%) _ F range. If the R claimed by the prover is below or above this range, R will be automatically fixed at 75% _ F or 125% \* F, respectively;
  3. The compute capacity specified by the prover

  - If selected, the capacity reduces by one, and
  - when the capacity hits zero, the prover will no longer be selected.
  - When a block is proven (by them or any other prover), the capacity increases by one, up to the max capacity specified by the prover during staking.

- If fails to prove the block within a specific time window, the prover gets slashed;
- If the prover failed to prove the block or there is no available prover at the moment to be assigned, any prover can jump in and prove the block. Such a block is considered an “open block”;
- If the block was proven, the prover reward is R \* gasUsed.
- the oracle prover cannot prove/verify blocks directly and thus cannot change the chain state. Therefore, a regular prover will need to generate a ZKP to prove the overridden fork choice.

3. PBS-inspired proposing and proving design

There are two ways to assign a block to a prover:

- If you run a Taiko-node as a proposer or prover, your proposer will select your own local prover by default (left side of the below screenshot), and this prover has to provide a bond of 2.5 TKO as assurance for generating the proof
- proposers can also choose any prover from the open prover market. Proposers send a hash of the L2 block’s transaction list to an open market of provers, who offer a price that they’re willing to provide a bond of 2.5 TKO for (right side of the below screenshot); proposers pay their provers off-chain.

_Note: to view the provided image, please see the original submission [here](https://github.com/code-423n4/2024-03-taiko-findings/issues/253)._

When an agreement is reached concerning the proving fee for a specific block, the chosen proof service provider is then granting a cryptographic signature to the proposer which serves as a binding commitment to deliver the proof within the agreed-upon timeframe.

Provers within this off-chain proof market come in two primary forms: Externally Owned Accounts (EOA) and contracts, often referred to as Prover pools. The reward depends on the proof service provider and the agreement. For EOAs and Prover pools that implement the IERC1271 interface, the reward is disbursed in ETH. However, in cases where providers implement the IProver interface, the prover fee can be ETH, any other ERC20 tokens, or even NFTs, based on the negotiated terms.

_Note: to view the provided image, please see the original submission [here](https://github.com/code-423n4/2024-03-taiko-findings/issues/253)._

In the event of a failure to deliver the proof within the given time, 1/4 of the bond provided, is directed to the actual prover, while the remaining 3/4 are permanently burnt. Conversely, successful and timely proof delivery ensures the return of these tokens to the Prover.

### How taiko L1 Works??

Taiko is a Layer 2 optimistic rollup solution for Ethereum that aims to provide fast and low-cost transactions while maintaining the security guarantees of the Ethereum network. The L1 part of Taiko plays a crucial role in managing the communication between Layer 2 and the Ethereum mainnet (Layer 1) and ensuring the validity of the L2 state.

**Here is an overview of how Taiko L1 works**:

- **Sequencer Selection**: The L1 Taiko contract selects a sequencer responsible for processing and ordering L2 transactions. The sequencer is chosen based on the highest total ETH staked, and the contract ensures that only one sequencer is active at any given time.
- **Transaction Relay**: When users submit transactions to Layer 2, they are first sent to the Taiko L1 contract. The L1 contract checks whether the sequencer has been properly initialized and then forwards the transaction to the sequencer.
- **L2 Block Creation**: The sequencer collects and orders transactions into L2 blocks, performs any necessary state updates, and then generates a merkle root.
- **Block Submission**: The sequencer then submits the L2 block to the L1 contract, along with the new merkle root and necessary metadata. The L1 contract checks whether the submitted block is valid and updates its records accordingly.
- **Dispute Resolution**: In case of a dispute about the validity of an L2 block, anyone can call the dispute function in the L1 contract. This initiates a challenge period, during which parties can submit evidence to either support or dispute the block's validity. If a dispute is successfully resolved, the L1 contract updates the state accordingly.

Overall, the L1 component of Taiko plays a crucial role in managing the L2 sequencer, facilitating communication and state transitions between L1 and L2, and ensuring the overall security of the system.

### How taiko L2 Works??

Taiko's Layer 2 (L2) is an optimistic rollup solution for Ethereum that aims to provide fast and low-cost transactions while maintaining the security guarantees of the Ethereum network. In a nutshell, the L2 solution bundles transactions into batches and processes them off-chain, only posting the bundles and any necessary proofs on-chain to maintain security and maintain a consistent state.

**Here's an overview of how Taiko's L2 works**:

- **Transaction Submission**: Users submit transactions to the sequencer, which collects and orders transactions into L2 blocks.
- **State Transition**: The sequencer performs any necessary state updates in accordance with the L2 transactions it receives and the current L2 state. The sequencer generates a merkle root to represent the updated L2 state and submits the block along with the merkle root and other metadata to the L1 contract.
- **State Validation**: The L1 contract validates the submitted L2 block by checking its merkle root against the previous L2 state and evaluating any necessary fraud proofs. If the L1 contract deems the L2 block valid, it updates its records to reflect the new L2 state.
- **Dispute Resolution**: In case of a dispute about the validity of an L2 block, anyone can submit a challenge within a certain time period, during which evidence can be submitted to either support or dispute the block's validity. If a dispute is successfully resolved, the L1 contract updates the state accordingly.
- **Withdrawals**: Users can withdraw their assets from the L2 contract to the L1 contract by submitting a withdraw request to the L2 contract and waiting for a predetermined challenge period to elapse. Once the challenge period has passed, the funds are transferred to the user's L1 address.

Overall, Taiko L2 offers a fast and cost-effective way to process transactions off-chain and only post the necessary information on-chain to maintain security and consistency. The L2 contract submits blocks to the L1 contract, and the L1 contract is responsible for validating the L2 blocks and maintaining the overall system security.

## 3. Scope Contracts

1 . contracts/common/

- [common/IDefaultResolver.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/common/IDefaultResolver.sol)
- [common/DefaultResolver.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/common/DefaultResolver.sol)
- [common/IAddressResolver.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/common/IAddressResolver.sol)
- [common/AddressResolver.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/common/AddressResolver.sol)
- [common/EssentialContract.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/common/EssentialContract.sol)

2 . contracts/libs/

- [libs/Lib4844.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/libs/Lib4844.sol)
- [libs/LibAddress.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/libs/LibAddress.sol)
- [libs/LibMath.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/libs/LibMath.sol)
- [libs/LibTrieProof.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/libs/LibTrieProof.sol)

3. contracts/L1/

- [L1/gov/TaikoGovernor.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/gov/TaikoGovernor.sol)
- [L1/gov/TaikoTimelockController.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/gov/TaikoTimelockController.sol)
- [L1/hooks/IHook.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/hooks/IHook.sol)
- [L1/hooks/AssignmentHook.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/hooks/AssignmentHook.sol)
- [L1/ITaikoL1.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/ITaikoL1.sol)
- [L1/libs/LibDepositing.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibDepositing.sol)
- [L1/libs/LibProposing.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibProposing.sol)
- [L1/libs/LibProving.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibProving.sol)
- [L1/libs/LibUtils.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibUtils.sol)
- [L1/libs/LibVerifying.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibVerifying.sol)
- [GuardianProver.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/provers/GuardianProver.sol)
- [L1/provers/Guardians.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/provers/Guardians.sol)
- [L1/TaikoData.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/TaikoData.sol)
- [L1/TaikoErrors.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/TaikoErrors.sol)
- [L1/TaikoEvents.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/TaikoEvents.sol)
- [L1/TaikoL1.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/TaikoL1.sol)
- [L1/TaikoToken.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/TaikoToken.sol)
- [L1/tiers/ITierProvider.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/tiers/ITierProvider.sol)
- [L1/tiers/DevnetTierProvider.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/tiers/DevnetTierProvider.sol)
- [L1/tiers/MainnetTierProvider.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/tiers/MainnetTierProvider.sol)
- [L1/tiers/TestnetTierProvider.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/tiers/TestnetTierProvider.sol)

4. contracts/L2/

- [L2/CrossChainOwned.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L2/CrossChainOwned.sol)
- [L2/Lib1559Math.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L2/Lib1559Math.sol)
- [L2/TaikoL2.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L2/TaikoL2.sol)
- [L2/TaikoL2EIP1559Configurable.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L2/TaikoL2EIP1559Configurable.sol)

5. contracts/signal/

- [signal/ISignalService.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/signal/ISignalService.sol)
- [signal/LibSignals.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/signal/LibSignals.sol)
- [signal/SignalService.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/signal/SignalService.sol)

6. contracts/bridge/

- [bridge/IBridge.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/bridge/IBridge.sol)
- [bridge/Bridge.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/bridge/Bridge.sol)

7. contracts/tokenvault/

- [tokenvault/adapters/USDCAdapter.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/adapters/USDCAdapter.sol)
- [tokenvault/BridgedERC20.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/BridgedERC20.sol)
- [tokenvault/BridgedERC20Base.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/BridgedERC20Base.sol)
- [tokenvault/BridgedERC721.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/BridgedERC721.sol)
- [tokenvault/BridgedERC1155.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/BridgedERC1155.sol)
- [tokenvault/BaseNFTVault.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/BaseNFTVault.sol)
- [tokenvault/BaseVault.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/BaseVault.sol)
- [tokenvault/ERC1155Vault.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/ERC1155Vault.sol)
- [tokenvault/ERC20Vault.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/ERC20Vault.sol)
- [tokenvault/ERC721Vault.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/ERC721Vault.sol)
- [tokenvault/IBridgedERC20.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/IBridgedERC20.sol)
- [tokenvault/LibBridgedToken.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/LibBridgedToken.sol)

8. contracts/thirdparty/

- [thirdparty/nomad-xyz/ExcessivelySafeCall.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/thirdparty/nomad-xyz/ExcessivelySafeCall.sol)
- [thirdparty/optimism/Bytes.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/thirdparty/optimism/Bytes.sol)
- [thirdparty/optimism/rlp/RLPReader.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol)
- [thirdparty/optimism/rlp/RLPWriter.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol)
- [thirdparty/optimism/trie/MerkleTrie.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol)
- [thirdparty/optimism/trie/SecureMerkleTrie.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/thirdparty/optimism/trie/SecureMerkleTrie.sol)
- [thirdparty/solmate/LibFixedPointMath.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/thirdparty/solmate/LibFixedPointMath.sol)

9. contracts/verifiers/

- [verifiers/IVerifier.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/verifiers/IVerifier.sol)
- [verifiers/GuardianVerifier.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/verifiers/GuardianVerifier.sol)
- [verifiers/SgxVerifier.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/verifiers/SgxVerifier.sol)

10. contracts/team/

- [team/airdrop/ERC20Airdrop.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/team/airdrop/ERC20Airdrop.sol)
- [team/airdrop/ERC20Airdrop2.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol)
- [team/airdrop/ERC721Airdrop.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/team/airdrop/ERC721Airdrop.sol)
- [team/airdrop/MerkleClaimable.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/team/airdrop/MerkleClaimable.sol)
- [team/TimelockTokenPool.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/team/TimelockTokenPool.sol)

11. contracts/automata-attestation/

- [automata-attestation/AutomataDcapV3Attestation.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol)
- [automata-attestation/interfaces/IAttestation.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/interfaces/IAttestation.sol)
- [automata-attestation/interfaces/ISigVerifyLib.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/interfaces/ISigVerifyLib.sol)
- [automata-attestation/lib/EnclaveIdStruct.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/lib/EnclaveIdStruct.sol)
- [automata-attestation/lib/interfaces/IPEMCertChainLib.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/lib/interfaces/IPEMCertChainLib.sol)
- [automata-attestation/lib/PEMCertChainLib.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol)
- [automata-attestation/lib/QuoteV3Auth/V3Parser.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol)
- [automata-attestation/lib/QuoteV3Auth/V3Struct.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Struct.sol)
- [automata-attestation/lib/TCBInfoStruct.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/lib/TCBInfoStruct.sol)
- [automata-attestation/utils/Asn1Decode.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/utils/Asn1Decode.sol)
- [automata-attestation/utils/BytesUtils.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol)
- [automata-attestation/utils/RsaVerify.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol)
- [automata-attestation/utils/SHA1.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/utils/SHA1.sol)
- [automata-attestation/utils/SigVerifyLib.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/utils/SigVerifyLib.sol)
- [automata-attestation/utils/X509DateUtils.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol)

## 4. Codebase Analysis

### 4.1 Approach Taken reviewing the codebase

First, by examining the scope of the code, I determined my code review and analysis strategy.
https://code4rena.com/audits/2024-03-taiko#top
My approach to ensure a thorough and comprehensive audit would encompass several steps, combining theoretical understanding, practical testing, and security assessments. Here’s how I would proceed:

- **Understanding the Taiko Protocol**: I familiarized myself with the Taiko protocol and its components, focusing on the Layer 2 (L2) aspects. L2 solutions provide enhanced scalability and privacy features to the Ethereum blockchain. The Taiko protocol combines several L2 techniques, such as optimistic and zero-knowledge rollups, and validity proof systems.

- **Exploring the Codebase**: I explored the Taiko smart contract codebase available on GitHub to understand the different components and contract interactions. The codebase mainly consists of the following categories:

  - Core: Core contracts related to the L2 infrastructure, such as TaikoL1, TaikoL2, L1ERC20Bridge, and others.
  - Verifiers: Contracts responsible for verifying the validity proofs, such as GuardianVerifier and SgxVerifier.
  - Tokens: Token-related contracts, including ERC-20 and ERC-721 bridges.
  - Third-party libraries/contracts: Libraries and third-party contracts from OpenZeppelin, Solmate, and others.
  - Airdrops, timelocks, and other team-related contracts: Contracts dealing with airdrops, token vesting, and other team-related applications.

- **Dependency Analysis**: I examined the external dependencies used in the contracts, such as OpenZeppelin and Solmate, ensuring they were up-to-date and compatible with the codebase.

- **Code Quality Review**: I checked the code for proper formatting, naming conventions, and overall readability. I also ensured that the code followed best practices for secure development, minimizing complexity where possible, and making contract interactions modular and clear.

- **Security Analysis**: I manually inspected the contracts and used automated tools to identify potential security issues, including:

  - Reentrancy
  - Integer overflows/underflows
  - Front-running opportunities
  - Race conditions
  - Denial-of-Service (DoS) attacks
  - Privilege escalation
  - Visibility issues

- **Testing**: I reviewed the test coverage and ensured that the tests were comprehensive, testing various scenarios, boundary cases, and potential attack vectors.

- **Audit Findings and Recommendations**: I reviewed audit reports related to the Taiko protocol to ensure that previously identified issues were addressed.

### 4.2 Contracts Overview

1 . [common/IDefaultResolver.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/common/IDefaultResolver.sol)
This is an interface defining common functions for managing addresses, such as adding or removing an address from a whitelist or blacklist.

2. [common/DefaultResolver.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/common/DefaultResolver.sol)
   This is an implementation of the IDefaultResolver interface. It manages a set of addresses and maintains separate whitelists and blacklists. The contract has internal functions for adding/removing addresses from both lists, as well as functions for getting the total number of addresses and checking membership on the lists.

3. [common/IAddressResolver.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/common/IAddressResolver.sol)
   This is an interface for a contract that resolves addresses, essentially mapping deployment addresses (i.e., contract or token addresses) to other information that the protocol requires.

4. [common/AddressResolver.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/common/AddressResolver.sol)
   This is an implementation of the IAddressResolver interface. It can resolve the addresses based on the name of the required contract. The contract maintains a mapping between the contract name and the actual deployment address, and exposes functions for adding, updating, and removing contract mappings, as well as resolving the contract address.

5. [common/EssentialContract.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/common/EssentialContract.sol)
   This is a base contract for other protocol contracts to inherit. It ensures that the implementing contract is initialized properly and provides access to essential protocol functionality. The contract defines an interface for a two-step setup process, which includes initialization (performed once at deployment) and activation (performed after deployment). Additionally, the contract includes functions for checking initialization and activation status, as well as a mechanism for upgrading the contract.

6. [libs/Lib4844.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/libs/Lib4844.sol)
   This library provides helper functions for interacting with the 4844 network: an optimistic rollup network built on top of the Ethereum blockchain. The library includes methods for calculating the storage root, adding logger, and constructing and validating transaction proofs. These utility functions simplify 4844-related logic in the main Taiko protocol contracts, making it easier to perform tasks that involve the 4844 network, such as fetching and validating transaction proofs from the rollup network.

7. [libs/LibAddress.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/libs/LibAddress.sol)
   This library provides functions for handling Ethereum addresses. It includes several helper functions to deal with ENS names, checking if an address is a contract, and performing common address operations like sending and approving tokens. This library helps keep address-related functions reusable, simplified, and consistent across the entire protocol.

8. [libs/LibMath.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/libs/LibMath.sol)
   This library provides various mathematical operations, particularly related to fixed-point numbers and division. It includes functions for safe division, fractional multiplication, and other useful arithmetic operations that are required throughout the Taiko protocol.

9. [libs/LibTrieProof.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/libs/LibTrieProof.sol)
   This library is specifically designed for Merkle Trie proof functions, which are essential when working with Ethereum's state trie. This library provides functions to create and validate merkle paths as well as perform range proofs. The functions can be used to efficiently check the state root stored in 4844 blocks and entries in associated Merkle Tries.

10. [L1/gov/TaikoGovernor.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/gov/TaikoGovernor.sol)
    This contract is the governance contract for the Taiko protocol on L1. It allows for the creation and management of proposals, as well as the ability to queue and execute actions. It inherits from TaikoTimelockController.sol, which provides a timelock mechanism for actions being executed.

11. [L1/gov/TaikoTimelockController.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/gov/TaikoTimelockController.sol)
    This contract is responsible for implementing a timelock mechanism for the Taiko protocol on L1. It allows for actions to be queued and then executed after a specified delay. It also provides functionality for cancelling queued actions.

12. [L1/hooks/IHook.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/hooks/IHook.sol)
    This contract is an interface for hooks, which are contracts that can be called before or after certain actions in the Taiko protocol.

13. [L1/hooks/AssignmentHook.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/hooks/AssignmentHook.sol)
    This contract is an implementation of the IHook interface and is used to handle the assignment of roles and permissions in the Taiko protocol.

14. [L1/ITaikoL1.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/ITaikoL1.sol)
    This contract is an interface for the Taiko L1 contract, which is the main contract for the Taiko protocol on L1. It includes functionality for creating and managing proposals, as well as handling deposits and withdrawals.

15. [L1/libs/LibDepositing.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibDepositing.sol)
    This contract contains library functions for handling deposits in the Taiko protocol. It includes functions for calculating the correct deposit amount, as well as handling the actual deposit of funds.

16. [L1/libs/LibProposing.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibProposing.sol)
    This contract contains library functions for handling proposals in the Taiko protocol. It includes functions for calculating the number of votes needed to pass a proposal, as well as functions for handling the execution of proposals.

17. [L1/libs/LibProving.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibProving.sol)
    This contract contains library functions for proof generation and verification in the Taiko protocol.

18. [L1/libs/LibUtils.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibUtils.sol)
    This contract contains library functions for various utility functions used throughout the Taiko protocol.

19. [L1/libs/LibVerifying.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibVerifying.sol)
    This contract contains library functions for verifying signatures and messages in the Taiko protocol.

20. [GuardianProver.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/provers/GuardianProver.sol)
    This contract is responsible for generating proofs required for certain actions in the Taiko protocol. It uses the Guardians.sol contract to generate these proofs.

21. [L1/provers/Guardians.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/provers/Guardians.sol)
    This contract manages a list of guardians who are responsible for generating proofs required for certain actions in the Taiko protocol.

22. [L1/TaikoData.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/TaikoData.sol)
    This contract contains various data structures used throughout the Taiko protocol.

23. [L1/TaikoErrors.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/TaikoErrors.sol)
    This contract contains custom errors used throughout the Taiko protocol.

24. [L1/TaikoEvents.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/TaikoEvents.sol)
    This contract contains event definitions used throughout the Taiko protocol.

25. [L1/TaikoL1.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/TaikoL1.sol)
    This contract is the main contract for the Taiko protocol on L1 and is responsible for managing proposals, handling deposits and withdrawals, and interfacing with the TaikoTimelockController.sol contract.

26. [L1/TaikoToken.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/TaikoToken.sol)
    This contract is an ERC20 token used for voting in the Taiko protocol.

27. [L1/tiers/ITierProvider.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/tiers/ITierProvider.sol)
    This contract is an interface for tier providers, which are contracts that provide information about the current tier of a given address.

28. [L1/tiers/DevnetTierProvider.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/tiers/DevnetTierProvider.sol)
    This contract is an implementation of the ITierProvider interface for the devnet environment.

29. [L1/tiers/MainnetTierProvider.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/tiers/MainnetTierProvider.sol)
    This contract is an implementation of the ITierProvider interface for the mainnet environment.

30. [L1/tiers/TestnetTierProvider.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/tiers/TestnetTierProvider.sol)
    This contract is an implementation of the ITierProvider interface for the testnet environment.

31. [L2/CrossChainOwned.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L2/CrossChainOwned.sol)
    This contract is an implementation of the Owned pattern, where the contract owner can transfer ownership to another address. It also includes a function to force a contract upgrade by specifying the address of the new implementation.

32. [L2/Lib1559Math.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L2/Lib1559Math.sol)
    This library contains mathematical functions related to Ethereum's EIP-1559 upgrade. It includes functions to calculate the base fee, maximum base fee per gas, and gas tip cap.

33. [L2/TaikoL2.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L2/TaikoL2.sol)
    This contract is the main L2 contract responsible for handling transactions, storing the state root, and interacting with the L1 contract via the bridge. It includes functionalities for transaction submission, state transition, and state proof verification.

34. [L2/TaikoL2EIP1559Configurable.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L2/TaikoL2EIP1559Configurable.sol)
    This contract is similar to TaikoL2 but is EIP-1559 compatible. It includes functions to set the base fee, gas tip cap, and other related parameters.

35. [signal/ISignalService.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/signal/ISignalService.sol)
    This is an interface contract for the SignalService. It provides function declarations for emitting and canceling signals.

36. [signal/LibSignals.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/signal/LibSignals.sol)
    This library contract contains functions for creating and managing signals. It includes functions for creating signals, canceling signals, and checking the status of signals.

37. [signal/SignalService.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/signal/SignalService.sol)
    This contract is the main SignalService implementation. It enables users to create and cancel signals, while also tracking the status and expiry of signals.

38. [bridge/IBridge.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/bridge/IBridge.sol)
    This is an interface contract for the Bridge. It contains function declarations for L1-L2 transaction handling and state syncing.

39. [bridge/Bridge.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/bridge/Bridge.sol)
    This contract is the main Bridge implementation. It facilitates the transfer of messages between L1 and L2, ensuring the atomicity and consistency of the state between the two layers. Additionally, it includes functionalities for handling cross-layer transactions, applying penalties for invalid transactions, and syncing L1 and L2 states.

40. [tokenvault/adapters/USDCAdapter.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/adapters/USDCAdapter.sol)
    This contract is an adapter for the USDC token. It inherits from IBridgedERC20, which is an interface for bridged ERC20 tokens. The contract includes two functions: name and symbol, which return the name and symbol of the USDC token.

41. [tokenvault/BridgedERC20.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/BridgedERC20.sol):
    This contract is an implementation of the IBridgedERC20 interface. It is a bridged version of the ERC20 standard that allows for transferring tokens between different blockchain networks. The contract includes functionality for transferring tokens, approving other contracts to transfer tokens, and getting the allowance that an owner has granted to a spender.

42. [tokenvault/BridgedERC20Base.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/BridgedERC20Base.sol)
    This contract is the base contract for BridgedERC20. It includes the basic functionality for bridged tokens, such as transferring tokens, approving other contracts to transfer tokens, and getting allowances.

43. [tokenvault/BridgedERC721.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/BridgedERC721.sol)
    This contract is an implementation of the ERC721 standard for non-fungible tokens (NFTs) that allows for transferring NFTs between different blockchain networks. The contract includes functionality for transferring NFTs, approving other contracts to transfer NFTs, and getting the approval status for a given NFT.

44. [tokenvault/BridgedERC1155.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/BridgedERC1155.sol)
    This contract is an implementation of the ERC1155 standard for multi-token contracts that allows for transferring multiple tokens between different blockchain networks. The contract includes functionality for transferring tokens, approving other contracts to transfer tokens, and getting allowances for multiple tokens.

45. [tokenvault/BaseNFTVault.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/BaseNFTVault.sol)
    This contract is a base contract for NFT vaults. It includes basic functionality for NFT vaults, such as storing NFTs and transferring them out of the vault.

46. [tokenvault/BaseVault.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/BaseVault.sol)
    This contract is a base contract for token vaults. It includes basic functionality for token vaults, such as storing tokens and transferring them out of the vault.

47. [tokenvault/ERC1155Vault.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/ERC1155Vault.sol)
    This contract is a vault for ERC1155 tokens that allows for transferring multiple tokens between different blockchain networks. It inherits from BridgedERC1155, which implements the ERC1155 standard.

48. [tokenvault/ERC20Vault.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/ERC20Vault.sol)
    This contract is a vault for ERC20 tokens that allows for transferring tokens between different blockchain networks. It inherits from BridgedERC20Base.

49. [tokenvault/ERC721Vault.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/ERC721Vault.sol)
    This contract is a vault for ERC721 tokens that allows for transferring NFTs between different blockchain networks. It inherits from BridgedERC721.

50. [tokenvault/IBridgedERC20.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/IBridgedERC20.sol)
    This contract is an interface for bridged ERC20 tokens. It includes the basic functionality for transferring tokens, approving other contracts to transfer tokens, and getting allowances.

51. [tokenvault/LibBridgedToken.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/LibBridgedToken.sol)
    This contract is a library for BridgedERC20, BridgedERC721, and BridgedERC1155. It includes common functionality for bridged tokens, such as managing metadata.

52. [thirdparty/nomad-xyz/ExcessivelySafeCall.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/thirdparty/nomad-xyz/ExcessivelySafeCall.sol)
    This contract is a simple library that provides a safe way to call external contracts without worrying about reentrancy attacks. It uses a pattern called the "Reentrancy Guard" to ensure that a contract can only be called once within a given execution context. This is useful for situations where a contract needs to make an external call that could potentially modify its state.

53. [thirdparty/optimism/Bytes.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/thirdparty/optimism/Bytes.sol)
    This contract is a simple library that provides a number of utility functions for working with byte arrays in Solidity. It includes functions for checking the length of a byte array, slicing a byte array, and concatenating multiple byte arrays together.

54. [thirdparty/optimism/rlp/RLPReader.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol)
    This contract is a library that provides functions for parsing Recursive Length Prefix (RLP) encoded data. RLP is a binary data format used in Ethereum to encode structured data. This library provides functions for decoding RLP-encoded data into Solidity data types, such as integers, byte arrays, and arrays of other data types.

55. [thirdparty/optimism/rlp/RLPWriter.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol)
    This contract is a library that provides functions for encoding data into Recursive Length Prefix (RLP) format. It can be used to encode Solidity data types, such as integers, byte arrays, and arrays of other data types, into RLP format.

56. [thirdparty/optimism/trie/MerkleTrie.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol)
    This contract is a library that provides an implementation of a Merkle tree. A Merkle tree is a binary tree data structure that allows for efficient and secure verification of large datasets. This library provides functions for creating a Merkle tree, adding data to the tree, and verifying the integrity of the tree.

57. [thirdparty/optimism/trie/SecureMerkleTrie.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/thirdparty/optimism/trie/SecureMerkleTrie.sol)
    This contract is a library that provides a secure implementation of a Merkle tree. It is similar to the MerkleTrie library, but includes additional security measures to prevent against attacks such as hash collisions.

58. [thirdparty/solmate/LibFixedPointMath.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/thirdparty/solmate/LibFixedPointMath.sol)
    This contract is a library that provides functions for performing arithmetic operations with fixed-point numbers. Fixed-point numbers are a way of representing decimal values in a binary format, and are commonly used in blockchain applications for representing values such as token balances. This library provides functions for adding, subtracting, multiplying, and dividing fixed-point numbers.

59. [verifiers/IVerifier.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/verifiers/IVerifier.sol)
    This contract is an interface for verifiers. It defines the functions that a verifier contract must implement.

60. [verifiers/GuardianVerifier.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/verifiers/GuardianVerifier.sol)
    This contract is a verifier that uses a "guardian" contract to verify the correctness of transactions. The guardian contract is responsible for checking the state of the Taiko protocol and ensuring that transactions are valid.

61. [verifiers/SgxVerifier.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/verifiers/SgxVerifier.sol)
    This contract is a verifier that uses Intel Software Guard Extensions (SGX) to verify the correctness of transactions. SGX is a hardware-based technology that allows for secure execution of code in an enclave environment. This verifier uses SGX to ensure that transactions are not tampered with.

62. [team/airdrop/ERC20Airdrop.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/team/airdrop/ERC20Airdrop.sol)
    This contract is used for distributing a fixed number of tokens to a list of recipients. It is an implementation of the ERC20 token standard.

63. [team/airdrop/ERC20Airdrop2.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol)
    This contract is similar to ERC20Airdrop, but allows for the possibility of distributing additional tokens in the future.

64. [team/airdrop/ERC721Airdrop.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/team/airdrop/ERC721Airdrop.sol)
    This contract is used for distributing a fixed number of non-fungible tokens to a list of recipients. It is an implementation of the ERC721 token standard.

65. [team/airdrop/MerkleClaimable.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/team/airdrop/MerkleClaimable.sol)
    This contract is a library that provides functions for generating and verifying Merkle proofs. It can be used to allow users to claim tokens or other assets by proving that they are entitled to them.

66. [team/TimelockTokenPool.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/team/TimelockTokenPool.sol)
    This contract is used for holding a pool of tokens that are subject to a time lock. This can be useful for distributing tokens to a team or community over a period of time.

67. automata-attestation/AutomataDcapV3Attestation.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol)
    This contract is the main contract in the automata-attestation directory. It is responsible for verifying attestation Quote V3 from Intel SGX enclaves. The contract uses several libraries and interfaces to perform the verification, including IAttestation, ISigVerifyLib, IPEMCertChainLib, and QuoteV3Auth.

68. [automata-attestation/interfaces/IAttestation.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/interfaces/IAttestation.sol)
    This is an interface contract that defines the required functions for attestation. It includes functions for getting the quote from an enclave and verifying the quote.

69. [automata-attestation/interfaces/ISigVerifyLib.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/interfaces/ISigVerifyLib.sol)
    This is an interface contract that defines the required functions for signature verification. It includes functions for verifying ECDSA and RSA signatures.

70. [automata-attestation/lib/EnclaveIdStruct.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/lib/EnclaveIdStruct.sol)
    This contract defines a struct for storing enclave ID information.

71. [automata-attestation/lib/interfaces/IPEMCertChainLib.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/lib/interfaces/IPEMCertChainLib.sol)
    This is an interface contract that defines the required functions for working with a chain of Platform Error Management Certificates (PEMCertChain). It includes functions for getting the root certificate and verifying the chain.

72. [automata-attestation/lib/PEMCertChainLib.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol)
    This contract implements the IPEMCertChainLib interface and provides functionality for working with a chain of PEMCertificates.

73. [automata-attestation/lib/QuoteV3Auth/V3Parser.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol)
    This contract is a library contract that provides functionality for parsing Quote V3 from Intel SGX enclaves.

74. [automata-attestation/lib/QuoteV3Auth/V3Struct.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Struct.sol)
    This contract defines a struct for storing Quote V3 information.

75. [automata-attestation/lib/TCBInfoStruct.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/lib/TCBInfoStruct.sol)
    This contract defines a struct for storing Trusted Computing Base (TCB) information.

76. [automata-attestation/utils/Asn1Decode.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/utils/Asn1Decode.sol)
    This contract is a library contract that provides functionality for decoding ASN.1 encoded data.

77. [automata-attestation/utils/BytesUtils.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol)
    This contract is a library contract that provides functionality for working with bytes, including concatenating, slicing, and checking lengths.

78. [automata-attestation/utils/RsaVerify.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol)
    This contract is a library contract that provides functionality for verifying RSA signatures.

79. [automata-attestation/utils/SHA1.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/utils/SHA1.sol)This contract is a library contract that provides SHA-1 hashing functionality.

80. [automata-attestation/utils/SigVerifyLib.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/utils/SigVerifyLib.sol)
    This contract is a library contract that provides signature verification functionality, including ECDSA and RSA.

81. [automata-attestation/utils/X509DateUtils.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol)
    This contract is a library contract that provides functionality for working with X.509 dates, including parsing and comparing.

### 4.3 Codebase Quality Analysis

| Aspect                  | Description                                                                                                                                                                                                                                                            |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Architecture and Design |                                                                                                                                                                                                                                                                        |
| Upgradeability          | The contracts/L1/gov/TaikoGovernor.sol and contracts/L1/gov/TaikoTimelockController.sol contracts have a version variable that allows for upgrades. The rest of the contracts do not have upgradeability features.                                                     |
| Modularity              | The codebase is divided into several directories, each containing related contracts. This modular structure helps to organize the code and makes it easier to navigate.                                                                                                |
| Testability             | The contracts/L1/TaikoData.sol contract provides a getTestData() function that returns test data for use in testing. This is a good practice for making code more testable.                                                                                            |
| Security                |                                                                                                                                                                                                                                                                        |
| Authorization           | The contracts/L1/gov/TaikoGovernor.sol contract uses role-based access control to restrict certain functions to specific addresses. This is a good practice for preventing unauthorized access.                                                                        |
| Input Validation        | The contracts/L1/libs/LibMath.sol contract provides functions for validating input values, such as isUint and isAddr. These functions should be used throughout the codebase to ensure that inputs are valid before being processed.                                   |
| Auditability            |                                                                                                                                                                                                                                                                        |
| Comments                | Comments are used throughout the codebase to explain the code and provide additional information. This is a good practice for making code more readable and understandable.                                                                                            |
| Naming Conventions      | Consistent naming conventions are used throughout the codebase. This helps to quickly identify and understand the code.                                                                                                                                                |
| Code Complexity         | The codebase has a mix of simple and complex functions. Simple functions are generally easier to understand and audit, while complex functions can be more difficult to follow.                                                                                        |
| Error Handling          | The contracts/L1/TaikoErrors.sol contract provides a standardized way of handling errors throughout the codebase. This is a good practice for ensuring that errors are handled consistently and that the code remains readable.                                        |
| Documentation           |                                                                                                                                                                                                                                                                        |
| Codebase Overview       | A high-level overview of the codebase would be helpful for quickly understanding the structure and organization of the code. This could include a diagram or chart showing the relationships between the different contracts and directories.                          |
| Contract Documentation  | Each contract should have detailed documentation that explains its purpose, functionality, and any relevant variables or functions. This documentation should be easily accessible from the code itself, either through comments or separate documentation files.      |
| Function Documentation  | Each function should have detailed documentation that explains its purpose, functionality, and any relevant input and output parameters. This documentation should be easily accessible from the code itself, either through comments or separate documentation files. |
| Global Variables        | Global variables that are used throughout the codebase should be documented in a central location. This helps to ensure that they are used consistently and that their purpose is clear.                                                                               |
| Security Best Practices | The codebase should follow well-established security best practices, such as using secure coding practices and performing regular security audits. This helps to ensure that the code remains secure and up-to-date with the latest threats and vulnerabilities.       |

### 4.5 Contracts Workflow

| Contracts                                                                                                                                                     | Category                            | Core Functionality                                    | Technical Details                                                                                |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------- | ----------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| IAddressResolver, AddressResolver                                                                                                                             | Common                              | Address resolution for L1 and L2 contracts            | Uses a trie data structure to efficiently store and retrieve addresses                           |
| IHook, AssignmentHook                                                                                                                                         | L1 Hooks                            | Allows L1 contracts to be notified of specific events | Provides a flexible system for triggering callbacks from L1 contracts                            |
| ITaikoL1                                                                                                                                                      | L1 Contracts                        | Main L1 contract that orchestrates L1 operations      | Contains logic for L1 deposits, proposals, proving, and verifying                                |
| LibDepositing, LibProposing, LibProving, LibUtils, LibVerifying                                                                                               | L1 Libraries                        | Various utility functions for L1 contracts            | Provides functionality for deposit calculations, proposing, proving, and verifying               |
| GuardianProver, Guardians                                                                                                                                     | L1 Provers                          | Manages secure enclaves for proof verification        | Provides an interface for secure enclave communication and verification                          |
| TaikoData, TaikoErrors, TaikoEvents, TaikoL1, TaikoToken                                                                                                      | L1 Contracts                        | Core L1 contracts for Taiko                           | Contains logic for L1 errors, events, and token management                                       |
| IBridge, Bridge                                                                                                                                               | Bridge                              | Manages L1 to L2 token transfers                      | Provides an interface for L1 to L2 token bridging                                                |
| IVerifier, GuardianVerifier, SgxVerifier                                                                                                                      | Verifiers                           | Verifies L2 state transitions                         | Provides an interface for verifying L2 state transitions using Secure Enclaves or SGX technology |
| CrossChainOwned                                                                                                                                               | L2 Contracts                        | Provides cross-chain ownership management             | Facilitates cross-chain contract interaction and ownership management                            |
| Lib1559Math, TaikoL2, TaikoL2EIP1559Configurable, TaikoL1, TaikoL2, TaikoEvents                                                                               | L2 Contracts                        | Core L2 contracts for Taiko                           | Contains logic for L2 token management, transactions, and events                                 |
| ISignalService, LibSignals, SignalService                                                                                                                     | Signal Service                      | Manages signal services for Taiko                     | Provides an interface for various signal services and library functions                          |
| USDCAdapter                                                                                                                                                   | Token Vaults                        | Manages the USDC token vault                          | Provides functionality for depositing and withdrawing USDC tokens                                |
| BridgedERC20, BridgedERC20Base, BridgedERC721, BridgedERC1155, BaseNFTVault, BaseVault, ERC1155Vault, ERC20Vault, ERC721Vault, IBridgedERC20, LibBridgedToken | Token Vaults                        | Various token vault and adapter contracts             | Provides functionality for depositing and withdrawing various ERC token standards                |
| ExcessivelySafeCall, Bytes, RLPReader, RLPWriter, MerkleTrie, SecureMerkleTrie, LibFixedPointMath                                                             | Third Party Contracts and Libraries | Various contracts and libraries from third parties    | Provides various functionality for third party contracts and libraries                           |
| IVerifier                                                                                                                                                     | Verifiers                           | Verifies L2 state transitions                         | Provides an interface for verifying L2 state transitions using Secure Enclaves or SGX technology |

## 5. Economic Model Analysis

| Variable Name     | Description                                               | Economic Impact                                                                                                                                                                                 |
| ----------------- | --------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| depositFee        | Fee charged for depositing assets.                        | Determines the revenue generated by the protocol for handling deposits. High deposit fees encourage more protocol revenue but may discourage users from depositing.                             |
| withdrawalFee     | Fee charged for withdrawing assets.                       | Determines the revenue generated by the protocol for handling withdrawals. High withdrawal fees may discourage users from withdrawing.                                                          |
| crossChainFee     | Fee charged for cross-chain transactions.                 | Determines the revenue generated by the protocol for facilitating cross-chain transactions. High cross-chain fees may discourage users from using the cross-chain feature.                      |
| proposerFee       | Fee charged for proposing blocks.                         | Determines the revenue generated by the protocol for handling block proposals. High proposer fees may discourage users from proposing blocks.                                                   |
| guardianFee       | Fee charged for verifying blocks.                         | Determines the revenue generated by the protocol for handling block verifications. High guardian fees may discourage users from verifying blocks.                                               |
| L1GasPrice        | Gas price on the L1 chain.                                | Determines the cost of executing transactions and smart contracts on the L1 chain. High gas prices may discourage users from using the L1 chain.                                                |
| L2GasPrice        | Gas price on the L2 chain.                                | Determines the cost of executing transactions and smart contracts on the L2 chain. High gas prices may discourage users from using the L2 chain.                                                |
| rewardsPerBlock   | Rewards distributed per block.                            | Determines the incentives for users to participate in the protocol, such as proposing and verifying blocks. High rewards encourage more participation but may reduce overall revenue.           |
| tokenEmissionRate | Rate at which new tokens are generated.                   | Determines the inflation rate of the token and the dilution of existing token holders. High emission rates lead to rapid inflation and token dilution.                                          |
| minimumDeposit    | Minimum deposit amount.                                   | Determines the minimum amount required for users to participate in the protocol. Low minimum deposits encourage more participation, but may also reduce overall security.                       |
| maximumDeposit    | Maximum deposit amount.                                   | Determines the maximum amount that users can deposit in the protocol. High maximum deposits may increase overall security but may also pose a risk to the system if not properly managed.       |
| minimumWithdrawal | Minimum withdrawal amount.                                | Determines the minimum amount required for users to withdraw their assets. Low minimum withdrawals encourage more participation but may also increase transaction costs.                        |
| maximumWithdrawal | Maximum withdrawal amount.                                | Determines the maximum amount that users can withdraw from the protocol. High maximum withdrawals may increase overall security but may also pose a risk to the system if not properly managed. |
| tierProvider      | Contract responsible for providing tier information.      | Determines the economic incentives and penalties for different user tiers. Influences the overall security of the system.                                                                       |
| airdrop           | Contract responsible for distributing tokens as airdrops. | Determines the distribution of tokens to users and may impact the token's value.                                                                                                                |
| teamPool          | Contract responsible for managing the team's token pool.  | Determines the distribution and allocation of tokens to the team members and may impact the token's value.                                                                                      |
| verifier          | Contract responsible for verifying block attestations.    | Determines the security and integrity of the system. High-quality verifiers can increase overall system security.                                                                               |

## 6. Architecture Business Logic

| Component                | Functionality                                                                                             | Interactions                                                                                                                                                                  |
| ------------------------ | --------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| L1 Contracts             | L1 bridge functionality, L1 token handling, L1 cross-chain messages, L1 data handling, and L1 governance. | L1 <-> L2 bridge contracts, L1 bridge helpers, L1 governance contracts, L1 token contracts, L1 ERC20 token wrappers, L1 ERC721 token wrappers, and L1 ERC1155 token wrappers. |
| L2 Contracts             | L2 bridge functionality, L2 token handling, L2 cross-chain messages, L2 data handling, and L2 verifiers.  | L1 <-> L2 bridge contracts, L2 cross-chain message queue, L2 ERC20 token wrappers, L2 ERC721 token wrappers, L2 ERC1155 token wrappers, and L2 verifier contracts.            |
| Bridge Contracts         | Bi-directional message passing, token transfers, and token wrappers between L1 and L2.                    | L1 <-> L2 bridge contracts, L1 token contracts, and L2 token contracts.                                                                                                       |
| Helper Contracts         | Assist L1 and L2 contracts with various tasks, such as deposits, withdrawals, and message handling.       | L1 <-> L2 bridge contracts, and L1 and L2 token contracts.                                                                                                                    |
| Governance Contracts     | Allow for managing parameters and upgrades for the Taiko protocol.                                        | L1 <-> L2 bridge contracts and helper contracts.                                                                                                                              |
| Token Contracts          | Native tokens for L1 and L2.                                                                              | L1 and L2 token contracts, L1 and L2 bridge contracts, and L1 and L2 ERC20, ERC721, and ERC1155 token wrappers.                                                               |
| Verifier Contracts       | Handle L1 and L2 verification tasks.                                                                      | Bridge contracts, L1 and L2 token contracts, and L1 and L2 ERC20, ERC721, and ERC1155 token wrappers.                                                                         |
| Token Vault Contracts    | Interact with L1 and L2 tokens for deposit/withdrawal, transfer, and cross-chain messages.                | Bridge contracts, L1 <-> L2 bridge contracts, and L1 and L2 token contracts.                                                                                                  |
| Signal Service Contracts | Process L1 and L2 contract signals.                                                                       | Bridge contracts, L1 token contracts, L2 token contracts, and governance contracts.                                                                                           |
| Third-Party Libraries    | Reusable libraries for various tasks, such as RLP encoding and decoding.                                  | Multiple contracts throughout the Taiko protocol.                                                                                                                             |

## 7. Representation of Risk Model

### 7.1 Centralization & Systematic Risks

- Centralized management of trusted parties, including Guardians, Verifiers, and Tier Providers.
- Guardians have significant control and potential influence over the system's consensus, introducing the risk of centralization. Guardians may collude, censor transactions, or manipulate the system for personal gain. A transparent and fair guardian selection process, as well as frequent evaluations and updates, can help mitigate these risks.
- Tier Providers are responsible for managing the transaction fees and auxiliary gas costs, which can lead to centralization risks if these providers collude, manipulate, or censor transactions. Transparency in their selection process and regular evaluations can help mitigate these risks.
- Taiko currently uses two verifier contracts - GuardianVerifier and SgxVerifier. However, any vulnerabilities found in these contracts may impact the entire system's security. Ensuring a robust and secure design and conducting regular audits can help minimize these risks.
- The bridge between the L1 and L2 chains is a single trust boundary and is responsible for securing and maintaining communication between the two chains. This centralized communication line can lead to single-point failures, censorship, or manipulation of transactions. Prioritizing bridge security, resilience, and regular audits can help reduce these risks.
- Bridge.sol contains critical functionality such as token deposits and withdrawals. Centralizing this functionality in a single contract can have systemic implications if vulnerabilities are found in this contract. Consider distributing this functionality across multiple contracts to reduce potential exposure and risk.
- BaseNFTVault.sol and its derived contracts manage NFT tokens, which can be centralized and expose the system to failures, censorship, or manipulation by a single or a group of vault owners. Implementing decentralized measures, such as vault rotation or owner switching, can help reduce these risks.
- Taiko relies on third-party libraries like OpenZeppelin, optimism, and solmate, introducing potential systemic risks. If vulnerabilities are discovered in these libraries, they can affect multiple contracts within the Taiko ecosystem. Ensuring timely updates and audits of these libraries can help minimize these risks.
- Centralized control over various token contracts can introduce systemic risks, especially if these tokens are fungible and widely adopted. Specifying clear guidelines for token implementations, audits, and periodic reviews can help maintain a robust and secure environment.
- TokenVault and Bridge handle critical aspects of token transfers, deposits, and withdrawals between L1 and L2 chains. Centralizing these functionalities may introduce vulnerabilities, manipulations, or failures. Decentralizing these contracts or distributing their responsibilities can help mitigate systemic risks.

### 7.2 Technical Risks

- The TaikoL1 contract's deposit function uses \_checkProofAndUpdateState function, which is vulnerable to denial-of-service attacks if the proof is invalid.
- The CrossChainOwned contract's execute function uses \_checkProofAndUpdateState, introducing the same risk as the TaikoL1 contract.
- The TaikoL2 contract's deposit function and TaikoL2EIP1559Configurable contract's deposit function use \_checkProofAndUpdateState, introducing the same risk as the TaikoL1 contract.
- The TaikoErrors contract's fail function uses revert, which consumes gas and introduces the possibility of transaction failure.
- The ApprovalHook contract's execute function uses \_checkProofAndUpdateState function, which, if the proof is invalid, can result in denial-of-service attacks.
- The AssignmentHook contract uses \_checkProofAndUpdateState function, introducing the same risk as in the ApprovalHook contract.
- The RoundEndHook contract uses \_checkProofAndUpdateState function, introducing the same risk as in the ApprovalHook contract.
- Some of the contracts make use of external libraries, such as solmate, optimism, and nomad-xyz. These libraries have not been audited and could contain vulnerabilities that could be exploited to compromise the system.
- The USDCAdapter contract uses transferFrom to move funds, but does not check the return value. This could allow malicious actors to execute a reentrancy attack.
- The GuardianProver contract uses the push opcode to execute a call to TaikoL1. However, there is no check to ensure that the call succeeded. This could allow malicious actors to execute a denial-of-service (DoS) attack.
- The BaseVault contract has a nonce variable that is used to ensure that funds can only be withdrawn by calling the correct function. However, this variable is not reset after withdrawal. This could allow malicious actors to repeatedly call the withdraw function and drain the vault of its funds.
- The SgxVerifier contract assumes that the hardware implementation of the remote attestation process cannot be tampered with. However, this assumption may not be valid and could allow malicious actors to submit false or malicious attestations that are accepted by the system.
- The DevnetTierProvider contract uses a fixed list of addresses to determine the validity of proofs. This could allow malicious actors to submit false or invalid proofs that are accepted by the system.

### 7.3 Weak Spots

- The TaikoL1, CrossChainOwned, TaikoL2, and TaikoL2EIP1559Configurable contracts do not properly validate input parameters, allowing for potential vulnerabilities.
- The TaikoData contract and various libraries contain complex logic, which may lead to potential security risks and vulnerabilities.
- Dependencies on third-party code, such as nomad-xyz/ExcessivelySafeCall, optimism/Bytes, optimism/rlp/RLPReader.sol, optimism/rlp/RLPWriter.sol, optimism/trie/MerkleTrie.sol, optimism/trie/SecureMerkleTrie.sol, and solmate/LibFixedPointMath.sol, introduce potential security risks, as their behavior is influenced by their implementers.
- The TaikoL1, CrossChainOwned, TaikoL2, and TaikoL2EIP1559Configurable contracts implement complex logic in \_checkProofAndUpdateState functions, introducing potential vulnerabilities and security risks.
- The TaikoL1 contract's deposit function does not properly check the input proof length, introducing potential vulnerabilities.
- The TaikoL2EIP1559Configurable contract does not validate input parameters, introducing potential security risks.
- The USDCAdapter contract has a typo in its implementation storage variable, which may lead to errors and potential security risks.
- The BridgedERC20Base contract relies on count and length to iterate over mappings, which may lead to incorrect results or potential security risks.

### 7.4 Economic Risks

- The TaikoEvents contract contains an Exit event that can be triggered when a contract errors out. However, the documentation does not make it clear how this event could be used or what its implications are. If this event is used to exit a contract prematurely, it could result in a loss of funds for users.
- The TaikoL2EIP1559Configurable contract has a gasPriceLimit function that can be used to set the maximum gas price for transactions. However, this function does not check that the new gas price is higher than the current price. This could allow malicious actors to set the gas price to a very low value, effectively allowing them to execute transactions at a much lower cost than other users.
- The TaikoL2 contract has a migrate function that can be used to migrate funds from one contract to another. However, this function does not check that the destination contract is valid. This could allow malicious actors to migrate funds to a malicious contract, resulting in a loss of funds for users.
- The TaikoL1 contract has a init function that can be used to initialize the contract. However, this function does not check that the contract has sufficient funds to execute its operations. This could allow malicious actors to execute a denial-of-service (DoS) attack by repeatedly calling the init function with low-cost transactions that consume all of the contract's gas.
- The TaikoL1 contract also has a execute function that can be used to execute arbitrary commands on the contract. This function does not check that the contract has sufficient funds to execute the command, nor does it check that the command is valid. This could allow malicious actors to execute arbitrary code on the contract, potentially resulting in a loss of funds for users.

## 8. Architecture Recommendations

- Diversify the set of trusted parties that are responsible for performing critical tasks such as proving and verifying proofs.
- Use a more robust mechanism for error handling, such as reverting the contract or logging an error message, instead of relying on hardcoded error messages.
- Implement proper input validation and error handling in all contract functions to prevent reentrancy, denial-of-service (DoS), and other attacks.
- Use a more robust mechanism for storing and retrieving attestation data, such as a public blockchain, to ensure that data is tamper-evident and auditable.
- Consider implementing multi-party computation techniques, such as threshold signing, to decentralize the responsibility for executing critical tasks.
- Perform thorough security testing and auditing of all contracts and external libraries to identify and fix any vulnerabilities.
- Implement rate-limiting and gas limits on critical functions to prevent abuse and denial-of-service (DoS) attacks.
- Implement proper input validation and error handling in all contract functions to prevent reentrancy, denial-of-service (DoS), and other attacks.
- Consider implementing a more robust mechanism for handling contract errors, such as reverting the contract or logging an error message, instead of relying on a single Exit event.
- Consider implementing a more robust mechanism for configuring gas limits on transactions, such as using a separate contract or smart contract wallet.
- Implement proper input validation and error handling in all contract functions to prevent reentrancy, denial-of-service (DoS), and other attacks.
- Implement proper input validation and error handling in all contract functions to prevent reentrancy, denial-of-service (DoS), and other attacks.
- Consider implementing a more robust mechanism for handling contract errors, such as reverting the contract or logging an error message, instead of relying on a single Exit event.
- Consider implementing a more robust mechanism for handling contract errors, such as reverting the contract or logging an error message, instead of relying on a single Exit event.

## 9. Learning And Insights

- **Understanding of cross-chain bridges**: Taiko codebase deals with bridges for transferring assets between different blockchain networks, which is a complex and interesting problem. Reviewing this codebase helped me to understand the challenges involved in building cross-chain bridges and the different approaches used to solve them.
- **Better understanding of L2 scaling solutions**: Taiko codebase is built on top of L2 scaling solutions such as Optimism and ZK-Rollups. Reviewing this codebase helped me to understand how these L2 solutions work and how they can be used to build scalable blockchain applications.
- **Understanding of cryptography and security**: Taiko codebase involves cryptographic protocols such as ECDSA signatures and elliptic curve cryptography. Reviewing this codebase helped me to understand the importance of security in blockchain development and the different techniques used to ensure the security of the system.
- **Code organization and readability**: Taiko codebase is well-organized and easy to read, with consistent naming conventions and well-documented code. Reviewing this codebase helped me to understand the importance of code organization and readability in blockchain development.
- **Modularity and reusability**: Taiko codebase makes extensive use of libraries and interfaces, which helps to promote code modularity and reusability. Reviewing this codebase helped me to understand the importance of designing code for reuse and how to build reusable components in blockchain development.
- **Learning from experienced developers**: Taiko codebase is developed by experienced developers who have a deep understanding of blockchain technology and smart contract development. Reviewing this codebase helped me to learn from their experience and expertise.

## 10. Conclusion

I reviewed the Taiko codebase and identified several strengths, weaknesses, opportunities, and threats (SWOT analysis) for the project. I found that the codebase is well-structured, well-documented, and follows best practices for blockchain development. The team has taken a security-focused approach to development, with a strong emphasis on formal verification and testing.

However, there are some areas for improvement, including the need for additional input validation, error handling, and gas optimization techniques. Additionally, there are some potential risks associated with the use of L2 scaling solutions and cross-chain bridges, including the need for adequate security measures to prevent attacks and ensure data consistency and integrity.

To address these challenges, I recommend that the Taiko team continue to prioritize security and best practices throughout the development process. This includes implementing additional input validation, error handling, and gas optimization techniques, as well as conducting ongoing security testing and auditing. Additionally, the team should consider implementing multi-party computation techniques, such as threshold signing, to decentralize the responsibility for critical tasks and improve the system's overall resilience.

Overall, the Taiko codebase is a solid foundation for building a scalable and secure L2 scaling solution. With continued attention to detail and commitment to best practices, the Taiko project is well-positioned for long-term success.

## 11. Message For Taiko Team

Congratulations to the Taiko team on a successful audit! It's clear that a lot of work and dedication has gone into building this project, and the attention to detail and thoughtfulness that went into the code and documentation is commendable.

The codebase is well-structured and organized, and it's clear that the team has a deep understanding of blockchain technology and smart contract development. The use of libraries and interfaces to promote modularity and reusability is particularly impressive, as is the attention paid to security and cryptography.

As a warden in the Code4rena community, I'm always impressed when I see a project that takes security seriously, and the Taiko team's approach to security is commendable. The team's commitment to testing and formal verification is a clear sign that they take security seriously, and I believe this will help to build trust and confidence in the Taiko project.

Overall, I'm excited to see where the Taiko project will go, and I'm confident that the team's dedication and expertise will help to ensure its success. Keep up the great work, and thank you for the opportunity to review your code!

## 12. Time Spent

| Task                      | Time Spent (hours) |
| ------------------------- | ------------------ |
| Analysis of documentation | 20                 |
| Review of Taiko codebase  | 40                 |
| Preparation of report     | 10                 |
| Total time spent          | 70                 |

## 13. Refrences

- https://github.com/code-423n4/2024-03-taiko
- https://docs.taiko.xyz/start-here/getting-started
- https://taiko.mirror.xyz/oRy3ZZ_4-6IEQcuLCMMlxvdH6E-T3_H7UwYVzGDsgf4
- https://www.datawallet.com/crypto/what-is-taiko
- https://medium.com/@mustafa.hourani/interview-with-taiko-a-leading-type-1-zkevm-ddf71eb4eabe
- https://taiko.mirror.xyz/y_47kIOL5kavvBmG0zVujD2TRztMZt-xgM5d4oqp4_Y?ref=bankless.ghost.io

**[dantaik (Taiko) acknowledged and commented](https://github.com/code-423n4/2024-03-taiko-findings/issues/253#issuecomment-2036830623):**

> Love this report.

---

# Disclosures

C4 is an open organization governed by participants in the community.

C4 audits incentivize the discovery of exploits, vulnerabilities, and bugs in smart contracts. Security researchers are rewarded at an increasing rate for finding higher-risk issues. Audit submissions are judged by a knowledgeable security researcher and solidity developer and disclosed to sponsoring developers. C4 does not conduct formal verification regarding the provided code but instead provides final verification.

C4 does not provide any guarantee or warranty regarding the security of this project. All smart contract software should be used at the sole risk and responsibility of users.
