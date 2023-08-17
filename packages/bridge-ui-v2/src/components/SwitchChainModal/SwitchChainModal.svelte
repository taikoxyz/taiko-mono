<script lang="ts">
  import { type Chain, switchNetwork } from '@wagmi/core';
  import { t } from 'svelte-i18n';
  import { UserRejectedRequestError } from 'viem';

  import { LoadingMask } from '$components/LoadingMask';
  import { warningToast } from '$components/NotificationToast';
  import { chains } from '$libs/chain';
  import { chainToIconMap } from '$libs/util/chainToIconMap';
  import { switchChainModal } from '$stores/modal';

  let switchingNetwork = false;

  function closeModal() {
    $switchChainModal = false;
  }

  async function selectChain(chain: Chain) {
    // We want to switch the wallet to the selected network.
    // This will trigger the network switch in the UI also
    switchingNetwork = true;

    try {
      await switchNetwork({ chainId: chain.id });
      closeModal();
    } catch (err) {
      console.error(err);

      if (err instanceof UserRejectedRequestError) {
        warningToast($t('messages.network.rejected'));
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
  <div class="modal-box relative px-6 py-[35px] md:py-[20px] bg-primary-base-background text-primary-base-content">
    {#if switchingNetwork}
      <LoadingMask
        class="bg-grey-0/60"
        spinnerClass="border-primary-base-content"
        text={$t('messages.network.switching')} />
    {/if}

    <h3 class="title-body-bold mb-[20px]">{$t('switch_modal.title')}</h3>
    <p class="body-regular">{$t('switch_modal.description')}</p>
    <ul role="menu" class="space-y-4">
      {#each chains as chain (chain.id)}
        <li
          role="menuitem"
          tabindex="0"
          class="p-4 rounded-[10px] hover:bg-primary-content hover:cursor-pointer"
          on:click={() => selectChain(chain)}
          on:keydown={getChainKeydownHandler(chain)}>
          <!-- TODO: agree on hover:bg color -->
          <div class="f-row justify-between">
            <div class="f-items-center space-x-4">
              <i role="img" aria-label={chain.name}>
                <svelte:component this={chainToIconMap[chain.id]} size={32} />
              </i>
              <span class="body-bold">{chain.name}</span>
            </div>
            <span class="body-regular">{chain.network}</span>
          </div>
        </li>
      {/each}
    </ul>
  </div>
</dialog>
