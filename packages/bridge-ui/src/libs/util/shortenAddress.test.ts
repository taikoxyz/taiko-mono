import { shortenAddress } from './shortenAddress';

it('should return string with prefix and suffix', () => {
  const dummyAddress = '0x63FaC9201494f0bd17B9892B9fae4d52fe3BD377';

  expect(shortenAddress(dummyAddress)).toStrictEqual('0x63Fa…D377');
  expect(shortenAddress(dummyAddress, 10, 10)).toStrictEqual('0x63FaC920…52fe3BD377');
});

it('should return 0x if empty', () => {
  expect(shortenAddress('')).toBe('0x');
});
