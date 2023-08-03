<script lang="ts">
  import { _ } from 'svelte-i18n';

  import { L1Chain, L2Chain } from '../chain/chains';
  import type { Chain } from '../domain/chain';
  import { isSwitchChainModalOpen } from '../store/modal';
  import { switchNetwork } from '../utils/switchNetwork';
  import Modal from './Modal.svelte';
  import { errorToast, successToast } from './NotificationToast.svelte';

  const switchChain = async (chain: Chain) => {
    try {
      await switchNetwork(chain.id);
      isSwitchChainModalOpen.set(false);
      successToast('Successfully switched chain');
    } catch (error) {
      console.error(error);
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
          await switchChain(L1Chain);
        }}>
        <img src={L1Chain.iconUrl} alt={L1Chain.name} />
        <span class="ml-2">{L1Chain.name}</span>
      </button>
      <button
        class="btn btn-dark-5 h-[60px] text-base"
        on:click={async () => {
          await switchChain(L2Chain);
        }}>
        <img src={L2Chain.iconUrl} alt={L2Chain.name} />
        <span class="ml-2">{L2Chain.name}</span>
      </button>
    </div>
  </div>
</Modal>
