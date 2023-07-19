<script lang="ts">
  import type { FetchBalanceResult } from '@wagmi/core';
  import { t } from 'svelte-i18n';
  import { formatEther, parseUnits } from 'viem';

  import { InputBox } from '$components/InputBox';
  import { bridges } from '$libs/bridge';
  import { estimateCostOfBridging } from '$libs/bridge/estimateCostOfBridging';
  import { ETHBridge } from '$libs/bridge/ETHBridge';
  import type { ETHBridgeArgs } from '$libs/bridge/types';
  import { chainContractsMap, chains } from '$libs/chain';
  import { ETHToken, isETH, type Token } from '$libs/token';
  import { uid } from '$libs/util/uid';
  import { account } from '$stores/account';
  import { network } from '$stores/network';

  import { destNetwork, enteredAmount, processingFee, selectedToken } from '../state';
  import Balance from './Balance.svelte';
  import { amountInputComponent } from '$config';

  let inputId = `input-${uid()}`;
  let tokenBalance: FetchBalanceResult;
  let inputBox: InputBox;

  let computingMaxETH = false;

  function updateAmount(event: Event) {
    if (!$selectedToken) return;

    const target = event.target as HTMLInputElement;

    try {
      $enteredAmount = parseUnits(target.value, $selectedToken?.decimals);
    } catch (err) {
      $enteredAmount = BigInt(0);
    }
  }

  function setETHAmount(amount: bigint) {
    inputBox.setValue(formatEther(amount));
    $enteredAmount = amount;
  }

  async function useMaxAmount() {
    if (!$selectedToken || !$network) return;

    if (isETH($selectedToken)) {
      computingMaxETH = true;

      try {
        // Let's estimate the cost of briding 1 ETH
        // and then subtract it from the balance,
        // minus the processing fee

        const ethBridge = bridges['ETH'];
        const to = $account.address;
        const srcChainId = $network.id;

        // If no destination chain is selected, grab another
        // chain that's not the connected one
        const destChainId = $destNetwork ? $destNetwork.id : chains.find((chain) => chain.id !== srcChainId)?.id;

        const amount = BigInt(1); // whatever amount just to get an estimation
        const { bridgeAddress } = chainContractsMap[srcChainId.toString()];

        const bridgeArgs = {
          to,
          amount,
          srcChainId,
          destChainId,
          bridgeAddress,
          processingFee: $processingFee,
        } as ETHBridgeArgs;

        const estimatedCost = await estimateCostOfBridging(ethBridge, bridgeArgs);
        const maxAmount = tokenBalance.value - $processingFee - estimatedCost;

        setETHAmount(maxAmount);
      } catch (err) {
        console.error(err);

        // Unfortunately something happened and we couldn't estimate the cost
        // of bridging. Let's substract our own estimation
        const maxAmount = tokenBalance.value - $processingFee - amountInputComponent.estimatedCostBridging;

        setETHAmount(maxAmount);
      } finally {
        computingMaxETH = false;
      }
    } else {
      inputBox.setValue(tokenBalance.formatted);

      // Unfortunately setting the inputbox via API doesn't trigger
      // the `input` event, so we need to manually update the amount
      $enteredAmount = tokenBalance.value;
    }
  }
</script>

<div class="AmountInput f-col space-y-2">
  <div class="f-between-center text-secondary-content">
    <label class="body-regular" for={inputId}>{$t('amount_input.label')}</label>
    <Balance bind:value={tokenBalance} />
  </div>
  <div class="relative f-items-center">
    <InputBox
      id={inputId}
      type="number"
      placeholder="0.01"
      min="0"
      loading={computingMaxETH}
      on:input={updateAmount}
      bind:this={inputBox}
      class="w-full input-box outline-none py-6 pr-16 px-[26px] title-subsection-bold placeholder:text-tertiary-content" />
    <button
      class="absolute right-6 uppercase"
      disabled={!$selectedToken || !$network || computingMaxETH}
      on:click={useMaxAmount}>
      {$t('amount_input.button.max')}
    </button>
  </div>
</div>
