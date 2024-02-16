<script lang="ts">
  import { switchChain } from '@wagmi/core';
  import { t } from 'svelte-i18n';
  import { type Chain, SwitchChainError, UserRejectedRequestError } from 'viem';

  import { chainConfig } from '$chainConfig';
  import { LoadingMask } from '$components/LoadingMask';
  import { warningToast } from '$components/NotificationToast';
  import { chains } from '$libs/chain';
  import { config } from '$libs/wagmi';
  import { switchChainModal } from '$stores/modal';

  // TODO: We should combine this with the ChainSelector component.
  // Or at least share the same base component. There is a lot of code duplication

  let switchingNetwork = false;

  function closeModal() {
    $switchChainModal = false;
  }

  async function selectChain(chain: Chain) {
    // We want to switch the wallet to the selected network.
    // This will trigger the network switch in the UI also
    switchingNetwork = true;

    try {
      await switchChain(config, { chainId: chain.id });
      closeModal();
    } catch (err) {
      console.error(err);
      if (err instanceof SwitchChainError) {
        warningToast({ title: $t('messages.network.pending.title'), message: $t('messages.network.pending.message') });
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

<dialog class="modal modal-bottom md:modal-middle" class:modal-open={$switchChainModal}>
  <div
    class="modal-box relative px-6 py-[35px] md:py-[35px] bg-neutral-background text-primary-content box-shadow-small">
    {#if switchingNetwork}
      <LoadingMask spinnerClass="border-white" text={$t('messages.network.switching')} />
    {/if}

    <h3 class="title-body-bold mb-[30px]">{$t('switch_modal.title')}</h3>
    <p class="body-regular mb-[20px]">{$t('switch_modal.description')}</p>
    <ul role="menu" class=" w-full">
      {#each chains as chain (chain.id)}
        {@const icon = chainConfig[Number(chain.id)]?.icon || 'Unknown Chain'}
        <li
          role="menuitem"
          tabindex="0"
          class="p-4 rounded-[10px] hover:bg-primary-background cursor-pointer w-full"
          on:click={() => selectChain(chain)}
          on:keydown={getChainKeydownHandler(chain)}>
          <!-- TODO: agree on hover:bg color -->
          <div class="f-row f-items-center justify-between w-full">
            <div class="f-items-center space-x-4">
              <i role="img" aria-label={chain.name}>
                <img src={icon} alt="chain-logo" class="rounded-full" width="30px" height="30px" />
              </i>
              <span class="body-bold">{chain.name}</span>
            </div>
          </div>
        </li>
      {/each}
    </ul>
  </div>
</dialog>
