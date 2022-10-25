import { IPFS_GATEWAY_PREFIX } from "../constants/IPFS_GATEWAY_PREFIX";
import { transformMetadataUri } from "./transformMetadataUri";

describe("convert metadata uri", () => {
  type testCase = {
    i: { metadataUri: string; tokenID: string };
    o: string;
  };

  const tests: testCase[] = [
    {
      i: { metadataUri: "ipfs://asdf", tokenID: "" },
      o: IPFS_GATEWAY_PREFIX + "ipfs/" + "asdf",
    },
    {
      i: { metadataUri: "ipfs://ipfs/asdf", tokenID: "" },
      o: IPFS_GATEWAY_PREFIX + "ipfs/" + "asdf",
    },
    {
      i: { metadataUri: "https://ipfs.io/ipfs/asdf", tokenID: "" },
      o: IPFS_GATEWAY_PREFIX + "ipfs/" + "asdf",
    },
    {
      i: {
        metadataUri: "https://thirdeyesociety.mypinata.cloud/ipfs/asdf/1974",
        tokenID: "",
      },
      o: IPFS_GATEWAY_PREFIX + "ipfs/" + "asdf/1974",
    },
    {
      i: { metadataUri: "https://fake.com/metadata.json", tokenID: "" },
      o: "https://fake.com/metadata.json",
    },
    {
      i: { metadataUri: "ipfs://asdf/123", tokenID: "" },
      o: IPFS_GATEWAY_PREFIX + "ipfs/" + "asdf/123",
    },
    {
      i: { metadataUri: "", tokenID: "" },
      o: "",
    },
    {
      i: { metadataUri: "Unable", tokenID: "" },
      o: "",
    },
  ];

  test.each(tests)(
    "converts metadata uris to expected output",
    (testCase: testCase) => {
      expect(
        transformMetadataUri(testCase.i.metadataUri, testCase.i.tokenID)
      ).toStrictEqual(testCase.o);
    }
  );

  expect(transformMetadataUri("https://ipfs.io/ipfs/asdf", "")).toStrictEqual(
    IPFS_GATEWAY_PREFIX + "ipfs/" + "asdf"
  );

  expect(transformMetadataUri("https://ipfs.io/asdf", "")).toStrictEqual(
    IPFS_GATEWAY_PREFIX + "ipfs/" + "asdf"
  );

  expect(
    transformMetadataUri(
      "https://thirdeyesociety.mypinata.cloud/ipfs/asdf/1974",
      ""
    )
  ).toStrictEqual(IPFS_GATEWAY_PREFIX + "ipfs/" + "asdf/1974");

  expect(
    transformMetadataUri("https://fake.com/metadata.json", "")
  ).toStrictEqual("https://fake.com/metadata.json");

  expect(transformMetadataUri("ipfs://asdf/123", "")).toStrictEqual(
    IPFS_GATEWAY_PREFIX + "ipfs/" + "asdf/123"
  );

  expect(transformMetadataUri("", "")).toStrictEqual("");
  expect(transformMetadataUri("Unable", "")).toStrictEqual("");
});
