import {
  TaikoL1Alpha3,
  TaikoL1Alpha4,
  TaikoL2Alpha3,
  TaikoL2Alpha4,
} from "../domain/chain/baseTypes";

interface NetworkConfigTableProps {
  networkConfig: TaikoL1Alpha3 | TaikoL1Alpha4 | TaikoL2Alpha3 | TaikoL2Alpha4;
}

export function NetworkConfigTable() {
  return (
    <table>
      <thead>
        <tr>
          <th>Country</th>
          <th>Flag</th>
        </tr>
      </thead>
      <tbody>
        {[
          { country: "France", flag: "🇫🇷" },
          { country: "Ukraine", flag: "🇺🇦" },
        ].map((item) => (
          <tr key={item.country}>
            <td>{item.country}</td>
            <td>{item.flag}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
