export default async function get(tokenURI: string, json?: boolean): Promise<any> {
  const response = await fetch(tokenURI);
  return json ? response.json() : response.text();
}
