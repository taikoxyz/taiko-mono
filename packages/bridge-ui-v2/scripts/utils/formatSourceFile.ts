import { promises as fs } from 'fs';
import * as prettier from 'prettier';

export async function formatSourceFile(tsFilePath: string) {
  const generatedCode = await fs.readFile(tsFilePath, 'utf-8');

  // Format the code using Prettier
  return await prettier.format(generatedCode, { parser: 'typescript' });
}
