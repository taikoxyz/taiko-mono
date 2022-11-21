import { isProduction } from "./isProduction";

it("detects dev", () => {
  import.meta.env.VITE_NODE_ENV = "dev";
  expect(isProduction()).toStrictEqual(false);
});

it("detects prod", () => {
  import.meta.env.VITE_NODE_ENV = "production";
  expect(isProduction()).toStrictEqual(true);
});
