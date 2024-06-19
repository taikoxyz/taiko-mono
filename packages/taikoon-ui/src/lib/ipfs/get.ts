export default async function get(url: string, json?: boolean): Promise<any> {
  const response = await fetch(url);
  return json ? response.json() : response.text();
}
