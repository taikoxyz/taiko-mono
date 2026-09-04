/**
 * Two things have to hold for the {@html} toast sink to be safe, and neither was pinned:
 * svelte-i18n does not escape interpolated values, and every site that interpolates a value
 * into a toast runs it through escapeHtml first. Stripping the escaping from all call sites
 * left the suite green because the component tests mock `t` as `key => key`, which discards
 * the values before they can reach the sink.
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

describe('the toast that names the destination chain', () => {
  it('interpolates the chain, escaped', () => {
    // Pins that the string carries a {chain} placeholder at all: the component tests mock
    // the formatter away, so a placeholder silently missing from en.json would not show there
    const message = get(format)('bridge.actions.bridge.success.message', {
      values: { chain: escapeHtml(HOSTILE_SYMBOL) },
    });

    expect(message).not.toContain('<img');
    expect(message).toContain('claiming on &lt;img src=x onerror=alert(1)&gt;');
  });
});

describe('every call site that interpolates a value escapes it', () => {
  // A source-level pin, because the component tests mock the formatter away. Every value in a
  // `values: { ... }` passed to a toast must be wrapped in escapeHtml, except the explorer
  // `url`, which is built from the chain config rather than from anything read off the chain.
  const sources = [
    'src/components/Bridge/SharedBridgeComponents/ConfirmationStep/ConfirmationStep.svelte',
    'src/components/Faucet/Faucet.svelte',
  ];

  it.each(sources)('%s', (file) => {
    const text = readFileSync(resolve(process.cwd(), file), 'utf8');
    // Only the `values: { ... }` objects handed to the formatter; a `token: Token` type
    // annotation elsewhere in the file is not an interpolation
    const valueBlocks = [...text.matchAll(/values:\s*\{([^}]*)\}/g)].map((match) => match[1]);
    const interpolated = valueBlocks
      .flatMap((block) => [...block.matchAll(/\b(?!url\b)\w+:\s*([^,\n]+)/g)])
      .map((match) => match[1].trim());

    expect(interpolated.length).toBeGreaterThan(0);
    for (const expression of interpolated) {
      expect(expression, `${file}: ${expression}`).toMatch(/^escapeHtml\(/);
    }
  });
});
