interface proverEndpoint {
  url: string,
  currentCapacity: number,
  minimumFee: number,
}

export async function getProverEndpoints() {
  try {
    const response = await fetch('https://provers.dojonode.xyz/validProvers');

    if (!response.ok) {
      throw new Error(`HTTP error! Status: ${response.status}`);
    }

    const provers = await response.json(); // Parse the response as JSON

    console.log(provers);
    return provers as proverEndpoint[];
  } catch (error) {
    console.error(error);
    throw error; // Rethrow the error so that the caller can handle it
  }
}
