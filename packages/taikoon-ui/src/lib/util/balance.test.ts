import { renderBalance, renderEthBalance } from './balance';

vi.mock('@wagmi/core');

test('renderBalance lib', () => {
  expect(renderBalance(null)).toBe('0.00');
  expect(
    renderBalance({
      decimals: 18,
      formatted: '0',
      symbol: 'ETH',
      value: BigInt(0),
    }),
  ).toBe('0 ETH');
  expect(
    renderBalance({
      decimals: 18,
      formatted: '0.0000001234567',
      symbol: 'ETH',
      value: BigInt('123456700000'),
    }),
  ).toBe('0.0000001234567 ETH');
  expect(
    renderBalance({
      decimals: 18,
      formatted: '1',
      symbol: 'ETH',
      value: BigInt(1e18),
    }),
  ).toBe('1 ETH');
  expect(
    renderBalance({
      decimals: 18,
      formatted: '1.23',
      symbol: 'ETH',
      value: BigInt(1.23e18),
    }),
  ).toBe('1.23 ETH');
});

test('renderEthBalance lib', () => {
  expect(renderEthBalance(BigInt(0))).toBe('0 ETH');
  expect(renderEthBalance(BigInt(1))).toBe('0.000000 ETH');
  expect(renderEthBalance(BigInt(123456789000))).toBe('0.000000 ETH');
  expect(renderEthBalance(BigInt(1234567890000))).toBe('0.000001 ETH');
  expect(renderEthBalance(BigInt(12345678900000))).toBe('0.000012 ETH');
});
