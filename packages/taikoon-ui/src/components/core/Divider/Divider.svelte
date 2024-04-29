<script lang="ts">
  import { classNames } from '$lib/util/classNames';

  const dividerClasses = classNames('w-full border-t border-border-divider-default my-5', $$props.class);
</script>

<div class={dividerClasses}></div>
