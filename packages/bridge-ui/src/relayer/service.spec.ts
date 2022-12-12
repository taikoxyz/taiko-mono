// import { RelayerService } from "./service";

// const mockAxios = {
//   get: jest.fn(),
// };

// jest.mock("axios", () => ({
//   /* eslint-disable-next-line */
//   Axios: function () {
//     return mockAxios;
//   },
// }));

// describe("relayer api tests tests", () => {
//   beforeEach(() => {
//     jest.resetAllMocks();
//   });

//   it("gets all user's bridge transactions by address and chain id", async () => {
//     const url = "https://fakeurl.com";
//     const service = new RelayerService(url);

//     mockAxios.get.mockImplementationOnce(() => {
//       return {
//         data: [
//           {
//             id: 1,
//             name: "messageSent",
//             data: "{}",
//             status: 1,
//             chainID: 167001,
//           },
//         ],
//       };
//     });

//     expect(mockAxios.get).not.toHaveBeenCalled();

//     await service.GetAllByAddress("0x123", 167001);

//     expect(mockAxios.get).toHaveBeenCalledWith("/events", {
//       params: {
//         address: "0x123",
//         chainID: 167001,
//       },
//       headers: {
//         Accept: "*/*",
//       },
//     });
//   });
// });
