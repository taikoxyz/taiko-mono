<script lang="ts">
  import { fetchSigner, switchNetwork } from '@wagmi/core';
  import { _ } from 'svelte-i18n';

  import { mainnetChain, taikoChain } from '../chain/chains';
  import type { Chain } from '../domain/chain';
  import { isSwitchChainModalOpen } from '../store/modal';
  import { signer } from '../store/signer';
  import Modal from './Modal.svelte';
  import { errorToast, successToast } from './NotificationToast.svelte';

  const switchChain = async (chain: Chain) => {
    try {
      await switchNetwork({
        chainId: chain.id,
      });
      const wagmiSigner = await fetchSigner();

      signer.set(wagmiSigner);
      isSwitchChainModalOpen.set(false);
      successToast('Successfully switched chain');
    } catch (e) {
      console.error(e);
      errorToast('Error switching chain.');
    }
  };
</script>

<Modal
  title={$_('switchChainModal.title')}
  showXButton={false}
  isOpen={$isSwitchChainModalOpen}>
  <div class="w-100 text-center px-4">
    <span class="font-light text-sm">{$_('switchChainModal.subtitle')}</span>
    <div class="py-8 space-y-4 flex flex-col">
      <button
        class="btn btn-dark-5 h-[60px] text-base"
        on:click={async () => {
          await switchChain(mainnetChain);
        }}>
        <svelte:component this={mainnetChain.icon} /><span class="ml-2"
          >{mainnetChain.name}</span>
      </button>
      <button
        class="btn btn-dark-5 h-[60px] text-base"
        on:click={async () => {
          await switchChain(taikoChain);
        }}>
        <svelte:component this={taikoChain.icon} /><span class="ml-2"
          >{taikoChain.name}</span>
      </button>
    </div>
  </div>
</Modal>
