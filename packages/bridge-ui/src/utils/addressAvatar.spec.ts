import Identicon from 'identicon.js';

import { DEFAULT_IDENTICON, getAddressAvatarFromIdenticon } from "./addressAvatar";

it("should return a base64 avatar string", () => {
  const dummyAddress = "0x63FaC9201494f0bd17B9892B9fae4d52fe3BD377";
  const expectedIdenticonString = new Identicon(dummyAddress, 420).toString();

  expect(getAddressAvatarFromIdenticon(dummyAddress)).toStrictEqual(expectedIdenticonString);
});

it("should return default base64 avatar when no address is passed", () => {
  const dummyAddress = "";

  expect(getAddressAvatarFromIdenticon("")).toStrictEqual(DEFAULT_IDENTICON);
});
