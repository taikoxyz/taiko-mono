<script lang="ts">
  import { onMount } from 'svelte';
  import { t } from 'svelte-i18n';

  import { Alert } from '$components/Alert';
  import { ActionButton } from '$components/Button';
  import { Icon } from '$components/Icon';

  let modalOpen: boolean;

  function closeModal() {
    modalOpen = false;
  }

  function confirmModal() {
    localStorage.setItem('accepted-modal', 'true');

    closeModal();
  }

  onMount(() => {
    modalOpen = localStorage.getItem('accepted-modal') !== 'true';
  });
</script>

<dialog class="modal modal-bottom md:modal-middle" class:modal-open={modalOpen}>
  <div class="modal-box relative !px-[50px] md:rounded-[20px] bg-white space-y-[25px]">
    <div class="w-full space-y-[10px]">
      <!-- <img src="/taiko-favicon.svg" alt="Katla" class="w-[100px] h-[100px] mx-auto" /> -->
      <Icon type="bridge-light" class="w-[100px] h-[100px] mx-auto" />
      <h1 class="!text-black text-4xl font-bold">Important Update</h1>

      <p class="body-regular text-black mb-3">
        Lorem ipsum, dolor sit amet consectetur adipisicing elit. Ut blanditiis iusto aliquid voluptatibus, sint odio
        provident, magnam veniam, quisquam ad magni totam porro? Ullam facere mollitia possimus, molestiae cumque
        beatae!
      </p>
      <a href="https://www.taiko.xyz" target="_blank" class="link"> Learn more </a>
      <div class="w-full">
        <Alert type="warning">{$t('bridge.alerts.slow_bridging')}</Alert>
      </div>
    </div>

    <div class="f-row w-full space-x-[25px]">
      <ActionButton priority="primary" class="w-full" on:click={confirmModal}>
        {$t('common.confirm')}
      </ActionButton>
    </div>
  </div>
</dialog>
