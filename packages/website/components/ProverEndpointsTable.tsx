import { useEffect, useState } from "react";
import { getProverEndpoints } from "../utils/proverEndpoints";
import { StyledLink } from "../components/StyledLink";
import PocketBase from "pocketbase";

export function ProverEndpointsTable() {
  const [provers, setProvers] = useState([]);
  const [sortOrder, setSortOrder] = useState("asc");
  const [sortColumn, setSortColumn] = useState("currentCapacity");
  const [newProverEndpoint, setNewProverEndpoint] = useState("");

  async function addProverEndpoint(e) {
    e.preventDefault();

    try {
      const pb = new PocketBase("https://provers.dojonode.xyz");
      // dummy login to allow anyone to add their endpoint
      await pb.collection("users").authWithPassword("dummy", "dummy12345");

      // Remove trailing slashes
      const newProverEndpointValue = newProverEndpoint.replace(/\/+$/, "");

      // Add the prover to the DB
      await pb.collection("prover_endpoints").create({
        url: newProverEndpointValue,
      });

      // Success: refresh data and show toast?
      fetchProverEndpoints();
      setNewProverEndpoint("");
    } catch (error) {
      console.error(error);
      // Show error as a toast message
    }
  }

  async function fetchProverEndpoints() {
    try {
      const proverEndpoints = await getProverEndpoints();
      setProvers(
        proverEndpoints.sort((a, b) => b.currentCapacity - a.currentCapacity)
      );
      console.log(proverEndpoints);
    } catch (error) {
      console.error(error);
    }
  }

  const sortData = (column) => {
    const sortedProvers = [...provers];
    sortedProvers.sort((a, b) => {
      if (sortOrder === "asc") {
        return a[column] - b[column];
      } else {
        return b[column] - a[column];
      }
    });
    setProvers(sortedProvers);
    setSortOrder(sortOrder === "asc" ? "desc" : "asc");
    setSortColumn(column);
  };

  // Function to render the sorting arrow in the table header
  const renderSortArrow = (column) => {
    if (column === sortColumn) {
      if (sortOrder === "asc") {
        return <span>&uarr;</span>; // Up arrow
      } else {
        return <span>&darr;</span>; // Down arrow
      }
    }
    return null;
  };

  useEffect(() => {
    fetchProverEndpoints();
  }, []);

  return (
    <div>
      <form
        className="flex flex-col items-center my-4"
        onSubmit={(e) => addProverEndpoint(e)}
      >
        <input
          value={newProverEndpoint}
          onChange={(e) => setNewProverEndpoint(e.target.value)}
          className="my-3 py-1 text-center"
          placeholder="http://192.168.20.1:9876"
        />
        <button
          className="hover:cursor-pointer text-neutral-100 bg-[#E81899] hover:bg-[#d1168a] border-solid border-neutral-200 focus:ring-4 focus:outline-none focus:ring-neutral-100 font-medium rounded-lg text-sm px-3 py-2 text-center inline-flex items-center m-1 w-48 justify-center"
          type="submit"
        >
          Add prover pool
        </button>
      </form>

      <table className="table-auto w-full text-center mt-8">
        <thead>
          <tr>
            <th>API Endpoint</th>
            <th
              className="cursor-pointer"
              onClick={() => sortData("minimumGas")}
            >
              Minimum Fee {renderSortArrow("minimumGas")}
            </th>
            <th
              className="cursor-pointer"
              onClick={() => sortData("currentCapacity")}
            >
              Current Capacity {renderSortArrow("currentCapacity")}
            </th>
          </tr>
        </thead>
        <tbody>
          {provers.map((prover, index) => (
            <tr key={index}>
              <td>
                <StyledLink href={prover.url} text={prover.url} />
              </td>
              <td>{prover.minimumGas}</td>
              <td>{prover.currentCapacity}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
