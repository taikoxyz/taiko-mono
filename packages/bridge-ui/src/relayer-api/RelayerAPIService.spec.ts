import { RelayerAPIService } from './RelayerAPIService';

jest.mock('../constants/envVars');

describe('RelayerAPIService', () => {
  it('should be defined', () => {
    expect(RelayerAPIService).toBeDefined();
  });
});
