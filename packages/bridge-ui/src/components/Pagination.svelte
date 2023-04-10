<script lang="ts">
  export let totalPages: number;
  export let page: number;
  const DISABLED_BUTTON_LABEL = '...';

  function getPageButtons(pages: number) {
    if (pages <= 5) {
      return new Array(pages).fill(0).map((_, index) => ({
        label: index + 1,
        onClick: () => (page = index),
        value: index + 1,
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
          onClick: () => {
            // do nothing
          },
        },
        {
          label: pages - 1,
          onClick: () => (page = pages - 2),
          value: pages - 1,
        },
        {
          label: pages,
          onClick: () => (page = pages - 1),
          value: pages,
        },
      ];
    }
  }

  function makeButtons(pages) {
    return [
      {
        label: '<<',
        onClick: () => (page = 1),
      },
      {
        label: '<',
        onClick: () => {
          if (page > 1) {
            page -= 1;
          }
        },
      },
      ...getPageButtons(pages),
      {
        label: '>',
        onClick: () => {
          if (page < totalPages) {
            page += 1;
          }
        },
      },
      {
        label: '>>',
        onClick: () => (page = pages),
      },
    ];
  }

  let buttons = makeButtons(totalPages);
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

<style>
  .pagination .btn-active {
    color: white;
    background-color: hsla(var(--af) / var(--tw-bg-opacity, 1));
  }
</style>
