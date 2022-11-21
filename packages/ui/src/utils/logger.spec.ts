import logger from "./logger";
import type { ErrorTracker } from "../domain/errorTracker";

const errorTracker = {
  captureError: jest.fn(),
};
jest.mock("svelte/store", () => ({
  get: () => errorTracker as any as ErrorTracker,
  writable: () => jest.fn(),
}));

it("logs when it should, doesnt when it shouldnt", () => {
  const consoleSpy = jest.spyOn(console, "log").mockImplementation();

  expect(consoleSpy).not.toBeCalled();

  import.meta.env.VITE_NODE_ENV = "production";
  logger.log("yo");

  expect(consoleSpy).not.toBeCalled();

  import.meta.env.VITE_NODE_ENV = "dev";

  logger.log("yo");

  expect(consoleSpy).toBeCalled();
});

describe("error", () => {
  it("errors when it should, doesnt when it shouldnt", () => {
    const consoleSpy = jest.spyOn(console, "error").mockImplementation();
    expect(consoleSpy).not.toBeCalled();
    import.meta.env.VITE_NODE_ENV = "production";
    logger.error("yo");

    expect(consoleSpy).not.toBeCalled();

    import.meta.env.VITE_NODE_ENV = "dev";

    logger.error("yo");

    expect(consoleSpy).toBeCalled();
  });

  it("reports error object", () => {
    const error = new Error("test");
    logger.error(error);
    expect(errorTracker.captureError).toBeCalledWith(error);
  });

  it("reports error string", () => {
    const error = "test";
    logger.error(error);
    expect(errorTracker.captureError).toBeCalledWith(error);
  });

  it("reports error object when string present", () => {
    const error = new Error("test");
    logger.error("string", error);
    expect(errorTracker.captureError).toHaveBeenCalledWith(error);
    errorTracker.captureError.mockClear();
    logger.error(error, "string");
    expect(errorTracker.captureError).toHaveBeenCalledWith(error);
  });

  it("reports error and tags", () => {
    const error = "test";
    const context = "TokensView::submit";
    logger.error("TokensView::submit", error);
    expect(errorTracker.captureError).toBeCalledWith(error, context);
  });
});

it("warns when it should, doesnt when it shouldnt", () => {
  const consoleSpy = jest.spyOn(console, "warn").mockImplementation();

  expect(consoleSpy).not.toBeCalled();
  import.meta.env.VITE_NODE_ENV = "production";
  logger.warn("yo");

  expect(consoleSpy).not.toBeCalled();

  import.meta.env.VITE_NODE_ENV = "dev";

  logger.warn("yo");

  expect(consoleSpy).toBeCalled();
});
