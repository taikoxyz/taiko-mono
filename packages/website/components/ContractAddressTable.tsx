import {
  TaikoL1Alpha3,
  TaikoL1Alpha4,
  TaikoL2Alpha3,
  TaikoL2Alpha4,
  BasedContracts,
  RollupContracts,
  OtherContracts,
} from "../domain/chain/baseTypes";
import { contractAddressToLink } from "../utils/contractAddressToLink";

interface ContractAddressTableProps {
  networkConfig: TaikoL1Alpha3 | TaikoL1Alpha4 | TaikoL2Alpha3 | TaikoL2Alpha4;
  contracts: BasedContracts | RollupContracts | OtherContracts;
}

export function ContractAddressTable(props: ContractAddressTableProps) {
  const { networkConfig, contracts } = props;
  return (
    <table>
      <thead>
        <tr>
          <th style={{ textAlign: "left" }}>Name</th>
          <th style={{ textAlign: "left" }}>Proxy</th>
          <th style={{ textAlign: "left" }}>Implementation</th>
        </tr>
      </thead>
      <tbody>
        {Object.keys(contracts).map((key) => {
          if (key === "erc20Contracts") return;
          const contract = contracts[key];
          const baseUrl = networkConfig.blockExplorer.url;
          const proxyAddress = contract.address.proxy;
          const implementationAddress = contract.address.impl;
          return (
            <tr key={contract.name}>
              <td>{contract.name}</td>
              <td>
                {proxyAddress ? (
                  <a href={contractAddressToLink(baseUrl, proxyAddress)}>
                    {`${networkConfig.blockExplorer.name} ↗`}
                  </a>
                ) : (
                  "None"
                )}
              </td>
              <td>
                <a href={contractAddressToLink(baseUrl, implementationAddress)}>
                  {`${networkConfig.blockExplorer.name} ↗`}
                </a>
              </td>
            </tr>
          );
        })}
      </tbody>
    </table>
  );
}
