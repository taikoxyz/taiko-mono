<script lang="ts">
  import { onDestroy } from 'svelte';

  import { noop } from '$libs/util/noop';
  import { type Account, account } from '$stores/account';

  export let change: (newAccount: Account, oldAccount?: Account) => void = noop;

  let prevAccount: Account;

  // Manual subscriptions are not auto-released like $-syntax ones: without the
  // onDestroy below, every mount leaks a handler that keeps firing forever
  const unsubscribe = account.subscribe((newAccount) => {
    change(newAccount, prevAccount);
    prevAccount = newAccount;
  });

  onDestroy(unsubscribe);
</script>
