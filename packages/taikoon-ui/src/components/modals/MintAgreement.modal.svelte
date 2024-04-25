<script lang="ts">
  import { classNames } from '$lib/util/classNames';
  import { Button } from '$ui/Button';
  import { Modal, ModalBody, ModalFooter, ModalTitle } from '$ui/Modal';

  export let open: boolean = localStorage.getItem('mintAgreement') !== 'true';

  import LoremIpsum from '$content/loremIpsum';

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
  <ModalTitle>Before you mint</ModalTitle>
  <ModalBody>
    <div class={textContainerClasses}>
      {LoremIpsum}
    </div>
  </ModalBody>

  <ModalFooter>
    <div class={buttonRowClasses}>
      <Button type="error" size="lg" wide class="w-full md:w-1/2" href="/">Cancel</Button>
      <Button type="success" size="lg" wide class="w-full md:w-1/2" on:click={acceptMintTerms}>I agree</Button>
    </div>
  </ModalFooter>
</Modal>
