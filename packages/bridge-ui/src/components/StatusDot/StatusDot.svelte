<script lang="ts">
  import { Icon } from '$components/Icon';

  type StatusType = 'success' | 'pending' | 'error';

  export let type: StatusType;
  export let simple = true;

  let typeMap: Record<StatusType, string> = {
    success: 'fill-positive-sentiment',
    pending: 'fill-warning-sentiment',
    error: 'fill-negative-sentiment',
  };
</script>

<Icon type={simple ? 'circle' : 'status-circle'} fillClass={typeMap[type]} class="min-w-[20px] max-w-[20px]" />
