<script lang="ts">
  import { t } from 'svelte-i18n';

  import { classNames } from '$lib/util/classNames';
  import { Button } from '$ui/Button';
  import { Modal, ModalBody, ModalFooter, ModalTitle } from '$ui/Modal';

  export let open: boolean = localStorage.getItem('mintAgreement') !== 'true';

  const textContainerClasses = classNames(
    'p-8',
    'my-4',
    'h-[50vh]',
    'w-[90vw]',
    'rounded-3xl',
    'overflow-y-scroll',
    'bg-elevated-background',
  );

  const buttonRowClasses = classNames(
    'flex',
    'md:flex-row',
    'flex-col',
    'w-full',
    'items-center',
    'justify-evenly',
    'gap-4',
    'py-4',
  );

  function acceptMintTerms() {
    localStorage.setItem('mintAgreement', 'true');

    open = false;
  }
</script>

<Modal bind:open canClose={false} class="items-center justify-center">
  <ModalTitle>{$t('content.mint.modals.agreement.title')}</ModalTitle>
  <ModalBody>
    <div class={textContainerClasses}>
      {$t('content.mint.modals.agreement.text')}
    </div>
  </ModalBody>

  <ModalFooter>
    <div class={buttonRowClasses}>
      <Button type="error" size="lg" wide class="w-full md:w-1/2" href="/">{$t('buttons.cancel')}</Button>
      <Button type="success" size="lg" wide class="w-full md:w-1/2" on:click={acceptMintTerms}
        >{$t('buttons.agree')}</Button>
    </div>
  </ModalFooter>
</Modal>
