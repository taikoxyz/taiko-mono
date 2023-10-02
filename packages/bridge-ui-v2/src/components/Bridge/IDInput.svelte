<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';

  import { Icon } from '$components/Icon';
  import { uid } from '$libs/util/uid';

  export let numbersArray: number[] = [];
  export let isDisabled = false;
  export let enteredIds: string = '';

  // enum State {
  //   Valid,
  //   Invalid,
  //   Neutral,
  // }

  const dispatch = createEventDispatcher();
  let inputId = `input-${uid()}`;
  // let state = State.Neutral;

  $: {
    enteredIds = enteredIds.replace(/\s+/g, '');
    if (enteredIds === '' || enteredIds.endsWith(',')) {
      // state = State.Neutral;
      numbersArray = [];
    } else {
      const inputArray = enteredIds.split(',');
      const isValid = inputArray.every((item) => /^[0-9]+$/.test(item));
      // state = isValid ? State.Valid : State.Invalid;
      numbersArray = isValid ? inputArray.map((num) => parseInt(num)).filter(Boolean) : [];
    }
  }

  function validateInput(e: Event) {
    const target = e.target as HTMLInputElement;
    enteredIds = target.value.replace(/\s+/g, '');
    dispatch('input', { enteredIds, numbersArray });
  }

  function clear() {
    enteredIds = '';
    numbersArray = [];
    // state = State.Neutral;
    dispatch('input', { enteredIds, numbersArray });
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
      class="w-full input-box withValdiation py-6 pr-16 px-[26px] title-subsection-bold placeholder:text-tertiary-content {$$props.class}" />
    <!-- /*state === State.Valid ? 'success' : state === State.Invalid ? 'error' : ''  -->
    <button class="absolute right-6 uppercase body-bold text-secondary-content" on:click={clear}>
      <Icon type="x-close-circle" fillClass="fill-primary-icon" size={24} />
    </button>
  </div>
</div>
