<script lang="ts">
  import { noop } from '$libs/util/noop';
  import { type Account, account } from '$stores/account';

  export let change: (newAccount: Account, oldAccount?: Account) => void = noop;

  let prevAccount: Account;

  account.subscribe((newAccount) => {
    change(newAccount, prevAccount);
    prevAccount = newAccount;
  });
</script>
