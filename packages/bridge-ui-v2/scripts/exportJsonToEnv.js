#!/usr/bin/env node

import * as fs from 'fs';
import * as path from 'path';

import { PluginLogger as LogUtil } from './utils/PluginLogger.js';

const Logger = new LogUtil('exportJsonToEnv');

const envFile = './.env';

const bridgesPath = 'config/configuredBridges.json';
const chainsPath = 'config/configuredChains.json';
const tokensPath = 'config/configuredCustomToken.json';
const relayerPath = 'config/configuredRelayer.json';
const eventIndexerPath = 'config/configuredEventIndexer.json';

// Create a backup of the existing .env file
fs.copyFileSync(envFile, `${envFile}.bak`);

const jsonFiles = [bridgesPath, chainsPath, tokensPath, relayerPath, eventIndexerPath];

jsonFiles.forEach((jsonFile) => {
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
