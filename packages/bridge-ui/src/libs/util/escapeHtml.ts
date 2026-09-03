/**
 * @dev Escapes a value that will be interpolated into a string rendered with `{@html}`.
 *
 *      `ItemToast` renders its title and message with `{@html}` because the i18n strings
 *      carry an `<a>` to the explorer. svelte-i18n does not escape interpolated `values`,
 *      so anything substituted into one of those strings is markup, not text.
 *
 *      A token symbol is read straight off the chain by `symbol()`, and custom ERC-20s are
 *      importable by address, so a token whose symbol is `<img src=x onerror=...>` would
 *      execute in the app's origin the moment its approval toast appeared - with access to
 *      localStorage and to the amount and recipient on screen before signing.
 *
 *      Escaping at the interpolation site rather than at the token's source keeps the real
 *      symbol intact everywhere it is rendered as text, which is every other consumer.
 *
 * @param value The untrusted value
 * @return escaped_ The value with the five HTML-significant characters replaced
 */
export function escapeHtml(value: Maybe<string>): string {
  if (!value) return '';
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}
