<script lang="ts">
  import { _ } from "svelte-i18n";
  import { token } from "../../store/token";
</script>

<div class="form-control">
  <label class="label">
    <span class="label-text">From</span>
  </label>
  <label class="input-group">
    <input type="text" placeholder="0.01" class="input input-bordered" />
    <span>{$token.symbol}</span>
  </label>
</div>

<div class="form-control">
  <label class="label">
    <span class="label-text">To</span>
  </label>
  <label class="input-group">
    <input type="text" placeholder="0.01" class="input input-bordered" />
    <span>{$token.symbol}</span>
  </label>
</div>
