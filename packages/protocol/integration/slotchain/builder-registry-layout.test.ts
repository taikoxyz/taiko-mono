import assert from "node:assert/strict";

import {
    canonicalTypeIdentifier,
    encodeStorageLayout,
} from "../../utils/slotchain/checkBuilderRegistryLayout";

assert.equal(
    canonicalTypeIdentifier(
        "t_mapping(t_uint64,t_struct(Generation)11050_storage)",
    ),
    "t_mapping(t_uint64,t_struct(Generation)_storage)",
);
assert.equal(
    canonicalTypeIdentifier(
        "t_array(t_struct(Generation)7_storage)1072_storage",
    ),
    "t_array(t_struct(Generation)_storage)1072_storage",
);

const fixture = (astId: number, reverse: boolean) => ({
    types: reverse
        ? {
              t_uint64: {
                  numberOfBytes: "8",
                  label: "uint64",
                  encoding: "inplace",
              },
              [`t_struct(Row)${astId}_storage`]: {
                  numberOfBytes: "8",
                  members: [
                      {
                          type: "t_uint64",
                          slot: "0",
                          offset: 0,
                          label: "value",
                          contract: "Fixture",
                          astId: astId + 1,
                      },
                  ],
                  label: "struct Fixture.Row",
                  encoding: "inplace",
              },
          }
        : {
              [`t_struct(Row)${astId}_storage`]: {
                  encoding: "inplace",
                  label: "struct Fixture.Row",
                  members: [
                      {
                          astId: astId + 1,
                          contract: "Fixture",
                          label: "value",
                          offset: 0,
                          slot: "0",
                          type: "t_uint64",
                      },
                  ],
                  numberOfBytes: "8",
              },
              t_uint64: {
                  encoding: "inplace",
                  label: "uint64",
                  numberOfBytes: "8",
              },
          },
    storage: [
        {
            astId,
            contract: "Fixture",
            label: "_row",
            offset: 0,
            slot: "0",
            type: `t_struct(Row)${astId}_storage`,
        },
    ],
});

assert.equal(
    encodeStorageLayout(fixture(12, false)),
    encodeStorageLayout(fixture(99, true)),
);

assert.throws(
    () =>
        encodeStorageLayout({
            storage: [
                {
                    label: "_row",
                    slot: "0",
                    offset: 0,
                    type: "t_struct(Row)1_storage",
                },
            ],
            types: {
                "t_struct(Row)1_storage": { encoding: "inplace" },
                "t_struct(Row)2_storage": { encoding: "inplace" },
            },
        }),
    /canonical key collision/,
);

console.log("builder registry layout normalization tests passed");
