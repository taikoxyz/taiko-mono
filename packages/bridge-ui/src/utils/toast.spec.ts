const mockPush = jest.fn();

jest.mock("@zerodevx/svelte-toast", () => ({
  ...(jest.requireActual("@zerodevx/svelte-toast") as object),
  push: mockPush,
}));

import { successToast, errorToast } from "./toast";
describe("toasts", function () {
  beforeEach(() => {
    jest.resetAllMocks();
  });
  it("should call successToast with msg and opts", () => {
    successToast("msg");
    expect(mockPush).toHaveBeenCalledWith("msg", {});
  });

  it("should call errorToast with msg and opts", () => {
    errorToast("msg");
    expect(mockPush).toHaveBeenCalledWith("msg", {});
  });
});
