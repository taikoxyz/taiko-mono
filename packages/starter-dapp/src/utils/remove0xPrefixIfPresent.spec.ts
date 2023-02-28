import { remove0xPrefixIfPresent } from "./remove0xPrefixIfPresent";

it("Should remove 0x if it is present (for 1-n sets of '0x'), and leave string alone if not", () => {
  expect(remove0xPrefixIfPresent("0x555")).toStrictEqual("555");
  expect(remove0xPrefixIfPresent("0x0x0x555")).toStrictEqual("555");
  expect(remove0xPrefixIfPresent("555")).toStrictEqual("555");
});
