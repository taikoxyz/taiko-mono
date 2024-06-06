<script lang="ts">
  import { t } from 'svelte-i18n';

  import { browser } from '$app/environment';
  import { Button } from '$components/core/Button';
  import { Link } from '$components/core/Text';
  import { Modal, ModalBody, ModalFooter, ModalTitle } from '$ui/Modal';

  import {
    bodyWrapperClasses,
    footerWrapperClasses,
    linkClasses,
    modalContentWrapperClasses,
    modalTitleClasses,
  } from './classes';

  const termsUrl = 'https://www.notion.so/taikoxyz/Legal-Disclaimer-89047a75cb0948f8833032f3467660c4';
  $: isModalOpen = Boolean(browser && !localStorage.getItem('acceptedLegal'));

  function acceptTerms() {
    localStorage.setItem('acceptedLegal', 'true');
    isModalOpen = false;
  }
</script>

<Modal canClose={false} open={isModalOpen}>
  <div class={modalContentWrapperClasses}>
    <ModalTitle class={modalTitleClasses}>
      {$t('content.legal.title')}
    </ModalTitle>
    <ModalBody>
      <div class={bodyWrapperClasses}>
        {$t('content.legal.textPre')}
        <Link href={termsUrl} class={linkClasses} target="_blank">
          {$t('content.legal.link')}
        </Link>
        {$t('content.legal.textPost')}
      </div>
    </ModalBody>
    <ModalFooter>
      <div class={footerWrapperClasses}>
        <Button on:click={acceptTerms} type="primary">
          {$t('buttons.accept')}
        </Button>
      </div>
    </ModalFooter>
  </div>
</Modal>
