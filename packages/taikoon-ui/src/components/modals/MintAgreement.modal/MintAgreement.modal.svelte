<script lang="ts">
  import { t } from 'svelte-i18n';

  import { Button } from '$ui/Button';
  import { Modal, ModalBody, ModalFooter, ModalTitle } from '$ui/Modal';

  import { buttonClasses, buttonRowClasses, textContainerClasses, wrapperClasses } from './classes';

  export let open: boolean = localStorage.getItem('mintAgreement') !== 'true';

  function acceptMintTerms() {
    localStorage.setItem('mintAgreement', 'true');

    open = false;
  }
</script>

<Modal bind:open canClose={false} class={wrapperClasses}>
  <ModalTitle>{$t('content.mint.modals.agreement.title')}</ModalTitle>
  <ModalBody>
    <div class={textContainerClasses}>
      {$t('content.mint.modals.agreement.text')}
    </div>
  </ModalBody>

  <ModalFooter>
    <div class={buttonRowClasses}>
      <Button type="error" size="lg" wide class={buttonClasses} href="/">{$t('buttons.cancel')}</Button>
      <Button type="success" size="lg" wide class={buttonClasses} on:click={acceptMintTerms}
        >{$t('buttons.agree')}</Button>
    </div>
  </ModalFooter>
</Modal>
