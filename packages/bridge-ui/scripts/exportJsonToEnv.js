#!/usr/bin/env node

import * as fs from 'fs';
import * as path from 'path';

import { PluginLogger as LogUtil } from './utils/PluginLogger.js';

const Logger = new LogUtil('exportJsonToEnv');

const envFile = './.env';

const defaultPaths = {
  bridges: 'configuredBridges.json',
  chains: 'configuredChains.json',
  tokens: 'configuredCustomTokens.json',
  relayer: 'configuredRelayer.json',
  eventIndexer: 'configuredEventIndexer.json',
};

// Parse command line arguments
const args = process.argv.slice(2);
const isLocal = args.includes('--local');
const isDev = args.includes('--dev');
const isProd = args.includes('--prod');
const isA7 = args.includes('--a7');
const isA6 = args.includes('--a6');
const isA5 = args.includes('--a5');

// Determine the environment
let environment = '';
if (isDev) {
  environment = 'dev';
} else if (isProd) {
  environment = 'prod';
} else if (isLocal) {
  environment = 'local';
}

// Determine the version
let version = '';
if (isA6) {
  version = 'a6';
} else if (isA5) {
  version = 'a5';
} else if (isA7) {
  version = 'a7';
}

Logger.info(`Detected ${environment} environment and ${version} version.`);

// Generate paths based on environment and version or create default paths
const paths = {};
Object.entries(defaultPaths).forEach(([key, value]) => {
  const fileName = path.basename(value);
  const filePath = path.dirname(value);
  const updatedPath = path.join('config', environment, version, filePath, fileName);
  paths[key] = updatedPath;
});

// Create a backup of the existing .env file
fs.copyFileSync(envFile, `${envFile}.bak`);

Object.entries(paths).forEach(([, value]) => {
  const jsonFile = value;

  if (fs.existsSync(jsonFile)) {
    Logger.info(`Exporting ${jsonFile} to .env file...`);

    const fileContent = fs.readFileSync(jsonFile);
    let base64Content = fileContent.toString('base64');
    const filename = path.basename(jsonFile, '.json');

    if (filename !== 'configuredChains') {
      base64Content = base64Content.replace(/\s+/g, '');
    }

    const envKey = filename.replace(/([a-z0-9])([A-Z])/g, '$1_$2').toUpperCase();

    const envFileContent = fs.readFileSync(envFile, 'utf-8');
    const regex = new RegExp(`^export ${envKey}=.*$`, 'm');

    if (regex.test(envFileContent)) {
      fs.writeFileSync(envFile, envFileContent.replace(regex, `export ${envKey}='${base64Content}'`));
    } else {
      fs.appendFileSync(envFile, `\nexport ${envKey}='${base64Content}'`);
    }

    Logger.info(`Successfully updated ${envKey}`);
  } else {
    Logger.error(`Warning: File ${jsonFile} does not exist.`);
  }
});

Logger.info('Done.');
