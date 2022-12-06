import { truncateString } from "./truncateString";

it("should truncate when string > maxLength", () => {
  const dummyBalance =
    "148234732894732894723894432847328947.42384732894732894732894";

  expect(truncateString(dummyBalance)).toStrictEqual("1482347328");
});

it("should return string when < maxLength", () => {
  const dummyBalance = "1";

  expect(truncateString(dummyBalance, 2)).toStrictEqual(dummyBalance);
});

it("should return empty string if empty", () => {
  const dummyAddress = "";

  expect(truncateString("")).toStrictEqual("");
});
