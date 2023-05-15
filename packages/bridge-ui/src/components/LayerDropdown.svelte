<script lang="ts">
  import { BridgeChainType } from '../domain/bridge';
  import {
    bridgeChains,
    l3Chain,
    mainnetChain,
    taikoChain,
  } from '../chain/chains';
  import { ArrowsRightLeft, ChevronDown } from 'svelte-heros-v2';
  import { selectChain } from '../utils/selectChain';
  import { fromChain, toChain } from '../store/chain';
  import { bridgeChainType } from '../store/bridge';

  async function switchBridgeChains(_bridgeChaintype: BridgeChainType) {
    const chains = bridgeChains[_bridgeChaintype];

    // No need to do anything if we're already on the right chains
    if ($fromChain.id === chains[0].id && $toChain.id === chains[1].id) {
      return;
    }

    $bridgeChainType = _bridgeChaintype;

    return selectChain(chains[0].id, chains);
  }
</script>

<div class="dropdown dropdown-end mr-4">
  <button class="btn btn-md justify-around md:w-[194px]">
    <span class="font-normal flex-1 text-left mr-2"> Click </span>
    <ChevronDown size="20" />
  </button>
  <ul
    role="listbox"
    tabindex="0"
    class="dropdown-content address-dropdown-content flex my-2 menu p-2 shadow bg-dark-2 rounded-sm w-[320px]">
    <!-- TODO: loop over the different bridge chains? -->
    <!-- 
      TODO: Avoid hardcoding in V2
            Loop over BridgeChainType as bridgeChainType:
              const [chain1, chain2] = bridgeChains[bridgeChainType]
              chain1 <=> chain2
    -->
    <li>
      <button
        class="flex items-center px-2 py-4 hover:bg-dark-5 rounded-xl justify-between"
        on:click={() => switchBridgeChains(BridgeChainType.L1_L2)}>
        <svelte:component this={mainnetChain.icon} height={24} />
        <span class="pl-1.5 flex-1 flex justify-between px-2">
          {mainnetChain.name}
          <ArrowsRightLeft class="pointer-events-none" />
          {taikoChain.name}
        </span>
        <svelte:component this={taikoChain.icon} height={24} />
      </button>
    </li>

    <li>
      <button
        class="flex items-center px-2 py-4 hover:bg-dark-5 rounded-xl justify-between"
        on:click={() => switchBridgeChains(BridgeChainType.L2_L3)}>
        <svelte:component this={taikoChain.icon} height={24} />
        <span class="pl-1.5 flex-1 flex justify-between px-2">
          {taikoChain.name}
          <ArrowsRightLeft class="pointer-events-none" />
          {l3Chain.name}
        </span>
        <svelte:component this={l3Chain.icon} height={24} />
      </button>
    </li>
  </ul>
</div>
