<script lang="ts">
  import { switchChain } from '@wagmi/core';
  import { t } from 'svelte-i18n';
  import { type Chain, SwitchChainError, UserRejectedRequestError } from 'viem';
  import { taiko, taikoHekla } from 'viem/chains';

  import { isDevelopmentEnv } from '$lib/util/isDevelopmentEnv';
  import { config } from '$wagmi-config';

  import { chains, getChainImage } from '../../lib/chain';
  import { switchChainModal } from '../../stores/modal';
  import { warningToast } from '../core/Toast';
  //import { chainConfig } from '$chainConfig';
  import { LoadingMask } from '../LoadingMask';
  import {
    chainItemClasses,
    chainItemContentClasses,
    chainItemContentWrapperClasses,
    modalDialogClasses,
    modalWrapperClasses,
    textClasses,
    titleClasses,
  } from './classes';

  // TODO: We should combine this with the ChainSelector component.
  // Or at least share the same base component. There is a lot of code duplication

  let switchingNetwork = false;

  $: selectedChains = [isDevelopmentEnv ? taikoHekla : taiko];

  function closeModal() {
    $switchChainModal = false;
  }

  async function selectChain(chain: Chain) {
    // We want to switch the wallet to the selected network.
    // This will trigger the network switch in the UI also
    switchingNetwork = true;

    try {
      await switchChain(config, { chainId: chain.id as any });
      closeModal();
    } catch (err) {
      console.error(err);
      if (err instanceof SwitchChainError) {
        warningToast({
          title: $t('messages.network.pending.title'),
          message: $t('messages.network.pending.message'),
        });
      }
      if (err instanceof UserRejectedRequestError) {
        warningToast({
          title: $t('messages.network.rejected.title'),
          message: $t('messages.network.rejected.message'),
        });
      }
    } finally {
      switchingNetwork = false;
    }
  }

  function getChainKeydownHandler(chain: Chain) {
    return (event: KeyboardEvent) => {
      if (event.key === 'Enter') {
        selectChain(chain);
      }
    };
  }
</script>

{#if selectedChains}
  <dialog class={modalDialogClasses} class:modal-open={$switchChainModal}>
    <div class={modalWrapperClasses}>
      {#if switchingNetwork}
        <LoadingMask spinnerClass="border-white" text={$t('messages.network.switching')} />
      {/if}

      <h3 class={titleClasses}>{$t('switch_modal.title')}</h3>
      <p class={textClasses}>{$t('switch_modal.description')}</p>
      <ul role="menu" class=" w-full">
        {#if chains !== undefined}
          {#each selectedChains as chain (chain.id)}
            {@const icon = getChainImage(Number(chain.id)) || 'Unknown Chain'}

            <li
              role="menuitem"
              tabindex="0"
              class={chainItemClasses}
              on:click={() => selectChain(chain)}
              on:keydown={getChainKeydownHandler(chain)}>
              <!-- TODO: agree on hover:bg color -->
              <div class={chainItemContentClasses}>
                <div class={chainItemContentWrapperClasses}>
                  <i role="img" aria-label={chain.name}>
                    <img src={icon} alt="chain-logo" class="rounded-full" width="30px" height="30px" />
                  </i>
                  <span class="body-bold">{chain.name}</span>
                </div>
              </div>
            </li>
          {/each}{/if}
      </ul>
    </div>
  </dialog>
{/if}
