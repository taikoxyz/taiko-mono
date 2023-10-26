import { useEffect, useState } from "react";
import { getProverEndpoints } from "../utils/proverEndpoints";
import { StyledLink } from "/components/StyledLink";

export default function ProverEndpointsTable() {
  const [provers, setProvers] = useState([]);

  useEffect(() => {
    async function fetchProverEndpoints() {
      try {
        const proverEndpoints = await getProverEndpoints();
        setProvers(proverEndpoints);
        console.log(proverEndpoints);
      } catch (error) {
        console.error(error);
      }
    }

    fetchProverEndpoints();
  }, []);

  return (
    <table className="table-auto w-[80%] text-left mt-8">
      <thead>
        <tr>
          <th>API Endpoint</th>
          <th>Minimum Fee</th>
          <th>Current Capacity</th>
        </tr>
      </thead>
      <tbody>
        {provers.map((prover, index) => (
          <tr key={index}>
            <td><StyledLink href={prover.url} text={prover.url}/></td>
            <td>{prover.minimumGas}</td>
            <td>{prover.currentCapacity}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

export {ProverEndpointsTable}
