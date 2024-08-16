<script lang="ts">
  import { t } from 'svelte-i18n';

  import { browser } from '$app/environment';
  import { Button } from '$components/core/Button';
  import { account } from '$stores/account';
  import { Modal, ModalBody, ModalTitle } from '$ui/Modal';

  import {
    bodyWrapperClasses,
    checkboxWrapperClasses,
    footerWrapperClasses,
    linkClasses,
    modalContentWrapperClasses,
    modalTitleClasses,
  } from './classes';

  const termsUrl = 'https://www.notion.so/taikoxyz/Legal-Disclaimer-89047a75cb0948f8833032f3467660c4';
  $: isModalOpen = Boolean($account && $account.address && browser && !localStorage.getItem('acceptedLegal'));

  function acceptTerms() {
    localStorage.setItem('acceptedLegal', 'true');
    isModalOpen = false;
  }

  $: isTermsChecked = false;
</script>

<Modal canClose={false} open={isModalOpen}>
  <div class={modalContentWrapperClasses}>
    <ModalTitle class={modalTitleClasses}>
      {$t('content.legal.title')}
    </ModalTitle>
    <ModalBody>
      <div class={bodyWrapperClasses}>
        {$t('content.legal.textPre')}
        <a href={termsUrl} class={linkClasses} target="_blank">
          {$t('content.legal.link')}
        </a>
        {$t('content.legal.textPost')}
      </div>

      <label class={checkboxWrapperClasses}>
        <input type="checkbox" bind:checked={isTermsChecked} class="checkbox border bg-overlay-background" />
        <span class="label-text text-content-secondary">I agree to the terms and conditions mentioned above.</span>
      </label>

      <div class={footerWrapperClasses}>
        <Button on:click={acceptTerms} disabled={!isTermsChecked} type="primary" wide block>
          {$t('buttons.confirm')}
        </Button>
      </div>
    </ModalBody>
  </div>
</Modal>
