<script lang="ts">
  import type { ethers } from "ethers";
  import { displayStatusValue } from "../utils/displayStatusValue";
  import { onDestroy, onMount } from "svelte";
  import Loader from "../components/Loader.svelte";

  export let provider: ethers.providers.JsonRpcProvider;
  export let contractAddress: string;

  export let statusFunc: (
    provider: ethers.providers.JsonRpcProvider,
    contractAddress: string
  ) => Promise<string | number | boolean>;

  export let watchStatusFunc: (
    provider: ethers.providers.JsonRpcProvider,
    contractAddress: string,
    onEvent: (value: string | number | boolean) => void
  ) => void;

  export let colorFunc: (value: string | number | boolean) => string;

  export let header: string;

  export let intervalInMs: number = 0;

  let interval: NodeJS.Timer;

  let statusValue: string | number | boolean;

  onMount(async () => {
    statusValue = await statusFunc(provider, contractAddress);
    console.log(statusValue);
    if (watchStatusFunc) {
      watchStatusFunc(
        provider,
        contractAddress,
        (value: string | number | boolean) => {
          statusValue = value;
        }
      );
    }

    if (intervalInMs !== 0) {
      interval = setInterval(
        async () => (statusValue = await statusFunc(provider, contractAddress)),
        intervalInMs
      );
    }
  });

  onDestroy(() => {
    if (interval) clearInterval(interval);
  });
</script>

<div class="rounded-3xl border-2 border-zinc-800 border-solid p-4">
  <h2 class="font-bold">{header}</h2>
  {#if statusValue || (typeof statusValue === "number" && statusValue === 0)}
    <span class={colorFunc(statusValue)}>
      {displayStatusValue(statusValue)}
    </span>
  {:else}
    <Loader />
  {/if}
</div>
