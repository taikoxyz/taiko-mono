import { escapeHtml } from './escapeHtml';

describe('escapeHtml', () => {
  it('neutralises markup in a token symbol', () => {
    // A custom ERC-20 is importable by address, and its symbol() is rendered through
    // {@html} in the approval toast
    expect(escapeHtml('<img src=x onerror=alert(1)>')).toBe('&lt;img src=x onerror=alert(1)&gt;');
    expect(escapeHtml('<script>alert(1)</script>')).toBe('&lt;script&gt;alert(1)&lt;/script&gt;');
  });

  it('escapes the ampersand first, so an escape cannot be re-formed', () => {
    // &lt; would otherwise come back out of the escaper as a literal <
    expect(escapeHtml('&lt;img&gt;')).toBe('&amp;lt;img&amp;gt;');
  });

  it('closes an attribute context as well as an element one', () => {
    expect(escapeHtml('" onmouseover="alert(1)')).toBe('&quot; onmouseover=&quot;alert(1)');
    expect(escapeHtml("' onmouseover='alert(1)")).toBe('&#39; onmouseover=&#39;alert(1)');
  });

  it('leaves an ordinary symbol alone', () => {
    expect(escapeHtml('USDC')).toBe('USDC');
    expect(escapeHtml('WETH')).toBe('WETH');
  });

  it('answers with an empty string for a missing symbol', () => {
    expect(escapeHtml(undefined)).toBe('');
    expect(escapeHtml(null)).toBe('');
    expect(escapeHtml('')).toBe('');
  });
});
