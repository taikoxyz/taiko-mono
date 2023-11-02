<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';

  import { Icon } from '$components/Icon';
  import { uid } from '$libs/util/uid';

  import { IDInputState as State } from './state';

  export let validIdNumbers: number[] = [];
  export let isDisabled = false;
  export let enteredIds: string = '';
  export let limit = 1;
  export let state: State = State.DEFAULT;

  export const clearIds = () => {
    enteredIds = '';
    validIdNumbers = [];
    dispatch('inputValidation');
  };

  const dispatch = createEventDispatcher();

  let inputId = `input-${uid()}`;

  function validateInput(idInput: EventTarget | string | null = null) {
    state = State.VALIDATING;
    if (!idInput) return;
    let ids;
    if (idInput && idInput instanceof EventTarget) {
      ids = (idInput as HTMLInputElement).value.replace(/\s+/g, '');
    } else {
      ids = idInput as string;
    }

    const inputArray = ids.split(',');
    if (inputArray.length > limit) {
      ids = inputArray.slice(0, limit).join(',');
    }
    enteredIds = ids;
    const isValid = inputArray.every((item) => /^[0-9]+$/.test(item));
    validIdNumbers = isValid ? inputArray.map((num) => parseInt(num)).filter(Boolean) : [];
    state = State.VALID;
    dispatch('inputValidation');
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
      on:input={(e) => validateInput(e.target)}
      class="w-full input-box withValdiation py-6 pr-16 px-[26px] title-subsection-bold placeholder:text-tertiary-content {$$props.class}
      {state === State.VALID ? 'success' : state === State.DEFAULT ? '' : 'error'}" />
    <!-- /*state === State.Valid ? 'success' : state === State.Invalid ? 'error' : ''  -->
    <button class="absolute right-6 uppercase body-bold text-secondary-content" on:click={clearIds}>
      <Icon type="x-close-circle" fillClass="fill-primary-icon" size={24} />
    </button>
  </div>
</div>
