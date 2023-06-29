<script lang="ts">
  import { t } from 'svelte-i18n';

  import { Icon } from '$components/Icon';
  import { Tooltip } from '$components/Tooltip';
  import { ProcessingFeeMethod, processingFees } from '$libs/free';
  import { uid } from '$libs/util/uid';
  import { InputBox } from '$components/InputBox';

  let dialogId = `dialog-${uid()}`;
  let selectedFee: ProcessingFeeMethod = ProcessingFeeMethod.RECOMMENDED;
  let modalOpen = false;

  function closeModal() {
    modalOpen = false;
  }

  function openModal() {
    modalOpen = true;
  }

  function getMethodText(method: ProcessingFeeMethod) {
    if (method === ProcessingFeeMethod.RECOMMENDED) {
      // TODO: calculate recommended fee here.
      //       Faking it for now
      return new Promise((resolve) => {
        setTimeout(() => {
          resolve('0.0001350000 ETH');
        }, 500);
      });
    }

    return Promise.resolve($t(`processing_fee.${method}.text`));
  }
</script>

<div class="ProcessingFee">
  <div class="f-between-center">
    <div class="flex space-x-2">
      <span class="body-small-regular text-secondary-content">{$t('processing_fee.title')}</span>
      <Tooltip>TODO: add description about processing fee</Tooltip>
    </div>
    <button
      class="link-regular text-primary-link underline hover:text-primary-link-hover"
      on:click={openModal}
      on:focus={openModal}>{$t('processing_fee.link')}</button>
  </div>

  <dialog id={dialogId} class="modal absolute modal-bottom px-4 pb-4" class:modal-open={modalOpen}>
    <div class="modal-box relative px-6 py-[30px] bg-neutral-background rounded-2xl">
      <button class="absolute right-6 top-[30px]" on:click={closeModal}>
        <Icon type="x-close" fillClass="fill-primary-icon" />
      </button>
      <h3 class="title-body-bold mb-7">{$t('processing_fee.title')}</h3>
      <ul class="space-y-7 mb-[20px]">
        {#each Array.from(processingFees.values()) as processingFee}
          {@const { method } = processingFee}
          {@const label = $t(`processing_fee.${method}.label`)}
          {@const promiseText = getMethodText(method)}

          <li class="f-between-center">
            <div class="flex flex-col">
              <label for={`input-${method}`} class="body-bold">{label}</label>
              <span class="body-small-regular text-secondary-content">
                <!-- TODO: think about the UI for this part. Talk to Jane -->
                {#await promiseText}
                  Calculating...
                {:then text}
                  {text}
                {/await}
              </span>
            </div>
            <input
              id={`input-${method}`}
              class="radio w-6 h-6 checked:bg-primary-interactive-accent hover:border-primary-interactive-hover"
              type="radio"
              value={method}
              name="processingFeeMethod"
              bind:group={selectedFee} />
          </li>
        {/each}
      </ul>
      <div class="relative f-items-center">
        <InputBox
          type="number"
          placeholder="0.01"
          min="0"
          class="w-full input-box outline-none p-6 pr-16 title-subsection-bold placeholder:text-tertiary-content" />
        <span class="absolute right-6 uppercase body-bold text-secondary-content">ETH</span>
      </div>
    </div>

    <div class="overlay-backdrop" />
  </dialog>
</div>
