<script lang="ts">
  import { BridgeMechanism, BridgeType } from "../../domain/bridge";
  import { signer } from "../../store/signer";

  import { onMount } from "svelte";
  import { ethers } from "ethers";
  import { chainId } from "../../store/chainId";
  import logger from "../../utils/logger";
  import ConnectButton from "../../components/ConnectButton.svelte";
  import BridgeTypeTabs from "../../components/BridgeTypeTabs.svelte";
  import ConfirmationsModal from "../../components/ConfirmationsModal.svelte";
  import { bridgeType, activeBridge } from "../../store/bridge";
  import { provider as providerStore } from "../../store/provider";

  let bridgeMechanism: BridgeMechanism = BridgeMechanism.Deposit;
  let loading: boolean = false;

  let amount: string = "0";
  let isConfirmationsModalOpen: boolean = false;
  let btnDisabled: boolean = false;
  let hash: string = "";
  let balance: string = "";

  onMount(async () => {
    if (!$signer || !$chainId) return;
    balance = (await $signer.getBalance()).toString();
  });

  $: amountForBridgeType($bridgeType);
  $: isBtnDisabled($bridgeType, amount)
    .then((b) => (btnDisabled = b))
    .catch((e) => logger.error(e));

  const amountForBridgeType = (t: BridgeType) => {
    if (t === BridgeType.NFT) {
      amount = "1";
    }
  };

  const isBtnDisabled = async (t: BridgeType, amount: string) => {
    if (!amount || amount === "0" || amount === "0.0") return true;
    if (!$signer) return true;
    if (
      t === BridgeType.ETH &&
      (await $signer.getBalance()).lt(ethers.utils.parseUnits(amount, 18))
    )
      return true;
    if (isNaN(Number(amount))) return true;
    return false;
  };

  async function bridge() {
    try {
      loading = true;
      console.log("bridge amount", amount);
      const bridgeTx = await $activeBridge.Bridge({
        signer: $signer,
        amount: ethers.utils.parseUnits(amount, 18).toString(),
        tokenAddress: "",
        tokenId: "",
        destChainId: 167001,
        bridgeAddress: import.meta.env.VITE_L1_BRIDGE_ADDRESS,
      });

      hash = bridgeTx.hash;
      logger.log("bridge txHash", hash);
      isConfirmationsModalOpen = true;
      loading = false;
    } catch (e) {
      logger.error("ETHBridge::error", e);
    } finally {
      loading = false;
    }
  }

  async function toggleBridgeMechanism() {
    if (bridgeMechanism === BridgeMechanism.Deposit) {
      bridgeMechanism = BridgeMechanism.Withdraw;
      if ($chainId !== 31336) {
        await $providerStore.request({
          method: "wallet_switchEthereumChain",
          params: [{ chainId: "0x7A68" }],
        });
      }
    } else {
      bridgeMechanism = BridgeMechanism.Deposit;
      if ($chainId !== 167) {
        await $providerStore.request({
          method: "wallet_switchEthereumChain",
          params: [{ chainId: "0xA7" }],
        });
      }
    }
  }
</script>

<div class="hero min-h-screen bg-base-200">
  <div class="hero-content flex-col lg:flex-row-reverse">
    <div class="text-center lg:text-left">
      <BridgeTypeTabs />

      <h1 class="text-5xl font-bold">
        Bridge {bridgeMechanism === BridgeMechanism.Deposit ? "L1" : "L2"} to {bridgeMechanism ===
        BridgeMechanism.Deposit
          ? "L2"
          : "L1"}
      </h1>
      <a on:click={async () => await toggleBridgeMechanism()}>change</a>
      <p class="py-6">
        Enter an amount to Bridge to bridge {$bridgeType}.
      </p>
    </div>
    <div class="card flex-shrink-0 w-full max-w-sm shadow-2xl bg-base-100">
      <div class="card-body">
        <div class="form-control">
          <label class="label">
            <span class="label-text">Enter amount</span>
          </label>
          <label class="input-group">
            <input
              type="text"
              placeholder="0.01"
              class="input input-bordered"
              bind:value={amount}
            />
            <span> ETH </span>
          </label>
        </div>
        <div class="form-control mt-6">
          {#if loading}
            <button class="btn btn-active btn-secondary loading" />
          {:else if !$signer}
            <ConnectButton />
          {:else}
            <button
              class="btn btn-active btn-secondary"
              disabled={btnDisabled}
              on:click={async () => await bridge()}>Bridge</button
            >
          {/if}
        </div>
      </div>
    </div>
  </div>
</div>

{#if isConfirmationsModalOpen}
  <ConfirmationsModal bind:isOpen={isConfirmationsModalOpen} {hash} />
{/if}
