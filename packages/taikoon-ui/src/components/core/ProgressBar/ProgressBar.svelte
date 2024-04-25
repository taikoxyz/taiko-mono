<script lang="ts">
  import { classNames } from '../../../lib/util/classNames';

  export let progress: number = 50;

  const wrapperClasses = classNames(
    'w-full',
    'h-3',
    'flex',
    'flex-row',
    'items-center',
    'bg-content-tertiary',
    'justify-start',
    'rounded-full',
    'overflow-hidden',
  );

  const progressClasses = classNames('h-full', 'bg-primary', 'rounded-full', 'transition-all');
</script>

<div class={wrapperClasses}>
  <div class={progressClasses} style={`width: ${progress}%`}></div>
</div>
