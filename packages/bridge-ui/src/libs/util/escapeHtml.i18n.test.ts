/**
 * Two things have to hold for the {@html} toast sink to be safe, and neither was pinned:
 * svelte-i18n does not escape interpolated values, and every site that interpolates an
 * on-chain symbol runs it through escapeHtml first. Stripping the escaping from all call
 * sites left the suite green because the component tests mock `t` as `key => key`, which
 * discards the values before they can reach the sink.
 */
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import { get } from 'svelte/store';
import { addMessages, format, init } from 'svelte-i18n';

import en from '../../i18n/en.json';
import { escapeHtml } from './escapeHtml';

const HOSTILE_SYMBOL = '<img src=x onerror=alert(1)>';

beforeAll(() => {
  addMessages('en', en);
  init({ fallbackLocale: 'en', initialLocale: 'en' });
});

describe('the toast messages that interpolate a token symbol', () => {
  it('receive the value verbatim from the formatter, markup included', () => {
    // The formatter is not a sanitizer; whatever is passed as `token` lands in the HTML
    const message = get(format)('bridge.actions.approve.success.message', { values: { token: HOSTILE_SYMBOL } });

    expect(message).toContain('<img src=x onerror=alert(1)>');
  });

  it('carry no markup once the symbol has been escaped', () => {
    const message = get(format)('bridge.actions.approve.success.message', {
      values: { token: escapeHtml(HOSTILE_SYMBOL) },
    });

    expect(message).not.toContain('<img');
    expect(message).toContain('&lt;img src=x onerror=alert(1)&gt;');
  });
});

describe('every call site that interpolates a symbol escapes it', () => {
  // A source-level pin, because the component tests mock the formatter away. Each
  // `values: { ... token: <expr> ... }` passed to a toast must wrap the symbol in escapeHtml.
  const sources = [
    'src/components/Bridge/SharedBridgeComponents/ConfirmationStep/ConfirmationStep.svelte',
    'src/components/Faucet/Faucet.svelte',
  ];

  it.each(sources)('%s', (file) => {
    const text = readFileSync(resolve(process.cwd(), file), 'utf8');
    // Only the `values: { ... }` objects handed to the formatter; a `token: Token` type
    // annotation elsewhere in the file is not an interpolation
    const valueBlocks = [...text.matchAll(/values:\s*\{([^}]*)\}/g)].map((match) => match[1]);
    const tokenValues = valueBlocks
      .flatMap((block) => [...block.matchAll(/\btoken:\s*([^,\n]+)/g)])
      .map((match) => match[1].trim());

    expect(tokenValues.length).toBeGreaterThan(0);
    for (const expression of tokenValues) {
      expect(expression, `${file}: ${expression}`).toMatch(/^escapeHtml\(/);
    }
  });
});
