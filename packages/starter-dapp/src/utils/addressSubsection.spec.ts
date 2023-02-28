import { addressSubsection } from "./addressSubsection";

it("should return string with prefix and suffix", () => {
  const dummyAddress = "0x63FaC9201494f0bd17B9892B9fae4d52fe3BD377";

  expect(addressSubsection(dummyAddress)).toStrictEqual("0x63F...D377");
});

it("should return 0x if empty", () => {
  const dummyAddress = "";

  expect(addressSubsection("")).toStrictEqual("0x");
});
