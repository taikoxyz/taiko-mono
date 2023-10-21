<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';

  import { Icon } from '$components/Icon';
  import { uid } from '$libs/util/uid';

  import { IDInputState as State } from './state';

  export let numbersArray: number[] = [];
  export let isDisabled = false;
  export let enteredIds: string = '';
  export let limit = 1;
  export let state: State = State.DEFAULT;

  export const clearIds = () => {
    enteredIds = '';
    numbersArray = [];
    dispatch('input', { enteredIds, numbersArray });
  };

  const dispatch = createEventDispatcher();

  let inputId = `input-${uid()}`;

  function validateInput(e: Event) {
    const target = e.target as HTMLInputElement;
    let newValue = target.value.replace(/\s+/g, '');
    const inputArray = newValue.split(',');
    if (inputArray.length > limit) {
      newValue = inputArray.slice(0, limit).join(',');
    }
    enteredIds = newValue;
    dispatch('input', { enteredIds, numbersArray });
  }

  $: {
    if (enteredIds === '' || enteredIds.endsWith(',')) {
      numbersArray = [];
    } else {
      const inputArray = enteredIds.split(',');
      const isValid = inputArray.every((item) => /^[0-9]+$/.test(item));
      numbersArray = isValid ? inputArray.map((num) => parseInt(num)).filter(Boolean) : [];
    }
  }
</script>

<div class="f-col space-y-2">
  <div class="f-between-center text-secondary-content">
    <label class="body-regular" for={inputId}>{$t('inputs.token_id_input.label')}</label>
  </div>
  <div class="relative f-items-center">
    <input
      id={inputId}
      disabled={isDisabled}
      type="text"
      placeholder={$t('inputs.token_id_input.placeholder')}
      bind:value={enteredIds}
      on:input={validateInput}
      class="w-full input-box withValdiation py-6 pr-16 px-[26px] title-subsection-bold placeholder:text-tertiary-content {$$props.class}
      {state === State.VALID ? 'success' : state === State.DEFAULT ? '' : 'error'}" />
    <!-- /*state === State.Valid ? 'success' : state === State.Invalid ? 'error' : ''  -->
    <button class="absolute right-6 uppercase body-bold text-secondary-content" on:click={clearIds}>
      <Icon type="x-close-circle" fillClass="fill-primary-icon" size={24} />
    </button>
  </div>
</div>
