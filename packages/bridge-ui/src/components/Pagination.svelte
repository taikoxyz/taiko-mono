<script lang="ts">
  export let totalPages: number;
  export let page: number;

  const DISABLED_BUTTON_LABEL = '...';

  type Button = {
    label: number | string;
    onClick: () => void;
    value?: number;
  };

  function getPageButtons(pages: number): Button[] {
    if (pages <= 5) {
      return new Array(pages).fill(0).map((_, index) => ({
        label: index + 1,
        onClick: () => (page = index),
        value: index,
      }));
    } else {
      return [
        {
          label: 1,
          onClick: () => (page = 1),
          value: 1,
        },
        {
          label: 2,
          onClick: () => (page = 2),
          value: 2,
        },
        {
          label: DISABLED_BUTTON_LABEL,
          onClick: () => {},
        },
        {
          label: pages - 1,
          onClick: () => (page = pages - 2),
          value: pages - 2,
        },
        {
          label: pages,
          onClick: () => (page = pages - 1),
          value: pages - 1,
        },
      ];
    }
  }

  function makeButtons(pages): Button[] {
    return [
      {
        label: '<<',
        onClick: () => (page = 0),
      },
      {
        label: '<',
        onClick: () => {
          if (page > 0) {
            page -= 1;
          }
        },
      },
      ...getPageButtons(pages),
      {
        label: '>',
        onClick: () => {
          if (page < totalPages - 1) {
            page += 1;
          }
        },
      },
      {
        label: '>>',
        onClick: () => (page = pages - 1),
      },
    ];
  }

  let buttons: Button[] = makeButtons(totalPages);
</script>

<div class="btn-group pagination justify-center mt-4">
  {#each buttons as button}
    <button
      class={`btn btn-xs md:btn-md ${
        button.value === page ? 'btn-active text-white' : ''
      } ${button.label === DISABLED_BUTTON_LABEL ? 'btn-disabled' : ''}`}
      on:click={button.onClick}>{button.label}</button>
  {/each}
</div>
