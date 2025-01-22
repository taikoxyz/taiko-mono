# Defender as Code Serverless Plugin

Defender as Code (DaC) is a Serverless Framework plugin for automated resource management and configuration as code.

:warning: This plugin is under development and behavior might change. Handle with care.

## Prerequisites

Serverless Framework: https://www.serverless.com/framework/docs/getting-started/

## Installation

You can initialise your Serverless project directly using our pre-configured template:

```
sls install --url https://github.com/OpenZeppelin/defender-as-code/tree/main/template -n my-service
```

Note: for the command above to work correctly you need access to this repo.

Alternatively, you can install it directly into an existing project with:

`yarn add @openzeppelin/defender-as-code`

## Setup

There are a few ways you can set up the `serverless.yml` configuration:

- Create it from scratch;
- Use Defender's 2.0 Serverless export capability;
- Leverage the example [template](https://github.com/OpenZeppelin/defender-as-code/blob/main/template/serverless.yml) provided in the `defender-as-code` repository.

If you already have resources such as contracts, notifications, relayers, actions, etc. in Defender 2.0, you can export a `serverless.yml` configuration file containing these resources from the manage → advanced page.

NOTE: If you have previously deployed with `defender-as-code` to the same account and subsequently created new resources through the Defender 2.0 user interface, the export function will automatically assign a `stackResourceId` to the new resources based on the name of your latest deployment stack. If you have not deployed using `defender-as-code` before, a default stack name of `mystack` will be used.

This plugin allows you to define Actions, Monitors, Notifications, Categories, Relayers, Contracts, Policies and Secrets declaratively from a `serverless.yml` and provision them via the CLI using `serverless deploy`. An example template below with an action, a relayer, a policy and a single relayer API key defined:

```yaml
service: defender-serverless-template
configValidationMode: error
frameworkVersion: "3"

provider:
  name: defender
  stage: ${opt:stage, 'dev'}
  stackName: "mystack"
  ssot: false

defender:
  key: "${env:TEAM_API_KEY}"
  secret: "${env:TEAM_API_SECRET}"

resources:
  actions:
    action-example-1:
      name: "Hello world from serverless"
      path: "./actions/hello-world"
      relayer: ${self:resources.relayers.relayer-1}
      trigger:
        type: "schedule"
        frequency: 1500
      paused: false
      # optional - unencrypted and scoped to the individual action
      environment-variables:
        hello: "world!"
    action-example-2: 2cbc3f58-d962-4be8-a158-1035be4b661c

  policies:
    policy-1:
      gas-price-cap: 1000
      whitelist-receivers:
        - "0x0f06aB75c7DD497981b75CD82F6566e3a5CAd8f2"
      eip1559-pricing: true

  relayers:
    relayer-1:
      name: "Test Relayer 1"
      network: "sepolia"
      min-balance: 1000
      policy: ${self:resources.policies.policy-1}
      api-keys:
        - key1

plugins:
  - "@openzeppelin/defender-as-code"
```

This requires setting the `key` and `secret` under the `defender` property of the YAML file. We recommend using environment variables or a secure (gitignored) configuration file to retrieve these values. Modify the `serverless.yml` accordingly.

Ensure the Defender Team API Keys are setup with all appropriate API capabilities.

The `stackName` (e.g. mystack) is combined with the resource key (e.g. relayer-1) to uniquely identify each resource. This identifier is called the `stackResourceId` (e.g. mystack.relayer-1) and allows you to manage multiple deployments within the same Defender team.

You may also reference existing Defender resources directly by their unique ID (e.g. `2cbc3f58-d962-4be8-a158-1035be4b661c`). These resources will not be managed by the plugin and will be ignored during the deploy process. However, you may reference them in other resources to update their configuration accordingly.

A list of properties that support direct referencing:

- `relayer` may reference a `relayerId` in Actions
- `action-trigger` may reference an `actionid` in Monitor
- `action-condition` may reference an `actionId` in Monitor
- `address-from-relayer` may reference a `relayerId` in Relayer
- `notify-config.channels` may reference multiple `notificationId` in Monitor
- `contracts` may be used over `addresses` and reference multiple `contractId` in Monitor

The following is an example of how a direct reference to a Defender contract and relayer can be used in monitor and action respectively:

```yaml
...
contracts:
  contract-1: 'sepolia-0x62034459131329bE4349A9cc322B03c63806Aa11' # contractId of an existing resource in Defender

relayers:
  relayer-2: 'bcb659c6-7e11-4d37-a15b-0fa9f3d3442c' # relayerId of an existing relayer in Defender

actions:
  action-example-1:
    name: 'Hello world from serverless'
    path: './actions/hello-world'
    relayer: ${self:resources.relayers.relayer-2}
    trigger:
      type: 'schedule'
      frequency: 1500
    paused: false

monitors:
  block-example:
    name: 'Block Example'
    type: 'BLOCK'
    network: 'sepolia'
    risk-category: 'TECHNICAL'
    # optional - either contracts OR addresses should be defined
    contracts:
      - ${self:resources.contracts.contract-1}
    ...
...
```

### SSOT mode

Under the `provider` property in the `serverless.yml` file, you can optionally add a `ssot` boolean. SSOT or Single Source of Truth, ensures that the state of your stack in Defender is perfectly in sync with the `serverless.yml` template.
This means that all Defender resources, that are not defined in your current template file, are removed from Defender, with the exception of Relayers, upon deployment. If SSOT is not defined in the template, it will default to `false`.

Any resource removed from the `serverless.yml` file does _not_ get automatically deleted in order to prevent inadvertent resource deletion. For this behaviour to be anticipated, SSOT mode must be enabled.

### Block Explorer Api Keys

Exported serverless configurations with Block Explorer Api Keys will not contain the `key` field but instead a `key-hash` field which is a keccak256 hash of the key. This must be replaced with the actual `key` field (and `key-hash` removed) before deploying

### Secrets (Action)

Action secrets can be defined both globally and per stack. Secrets defined under `global` are not affected by changes to the `stackName` and will retain when redeployed under a new stack. Secrets defined under `stack` will be removed (on the condition that [SSOT mode](#SSOT-mode) is enabled) when the stack is redeployed under a new `stackName`. To reference secrets defined under `stack`, use the following format: `<stackname>_<secretkey>`, for example `mystack_test`.

```yaml
secrets:
  # optional - global secrets are not affected by stackName changes
  global:
    foo: ${self:custom.config.secrets.foo}
    hello: ${self:custom.config.secrets.hello}
  # optional - stack secrets (formatted as <stackname>_<secretkey>)
  stack:
    test: ${self:custom.config.secrets.test}
```

### Types and Schema validation

We provide auto-generated documentation based on the JSON schemas:

- [Defender Property](https://github.com/OpenZeppelin/defender-as-code/blob/main/src/types/docs/defender.md)
- [Provider Property](https://github.com/OpenZeppelin/defender-as-code/blob/main/src/types/docs/provider.md)
- [Resources Property](https://github.com/OpenZeppelin/defender-as-code/blob/main/src/types/docs/resources.md)

More information on types can be found [here](https://github.com/OpenZeppelin/defender-as-code/blob/main/src/types/index.ts). Specifically, the types preceded with `Y` (e.g. YRelayer). For the schemas, you can check out the [docs-schema](https://github.com/OpenZeppelin/defender-as-code/blob/main/src/types/docs-schemas) folder.

Additionally, an [example project](https://github.com/OpenZeppelin/defender-as-code/blob/main/examples/defender-test-project/serverless.yml) is available which provides majority of properties that can be defined in the `serverless.yml` file.

## Commands

### Deploy

You can use `sls deploy` to deploy your current stack to Defender.

The deploy takes in an optional `--stage` flag, which is defaulted to `dev` when installed from the template above.

Moreover, the `serverless.yml` may contain an `ssot` property. More information can be found in the [SSOT mode](#SSOT-mode) section.

This command will append a log entry in the `.defender` folder of the current working directory. Additionally, if any new relayer keys are created, these will be stored as JSON objects in the `.defender/relayer-keys` folder.

> When installed from the template, we ensure the `.defender` folder is ignored from any git commits. However, when installing directly, make sure to add this folder it your `.gitignore` file.

### Info

You can use `sls info` to retrieve information on every resource defined in the `serverless.yml` file, including unique identifiers, and properties unique to each Defender component.

### Remove

You can use `sls remove` to remove all Defender resources defined in the `serverless.yml` file.

> To avoid potential loss of funds, Relayers can only be deleted from the Defender UI directly.

### Logs

You can use `sls logs --function <stack_resource_id>` to retrieve the latest action logs for a given action identifier (e.g. mystack.action-example-1). This command will run continuously and retrieve logs every 2 seconds.

### Invoke

You can use `sls invoke --function <stack_resource_id>` to manually run an action, given its identifier (e.g. mystack.action-example-1).

> Each command has a standard output to a JSON object.

More information can be found on our documentation page [here](https://docs.openzeppelin.com/defender/dac)

## Caveats

Errors thrown during the `deploy` process, will not revert any prior changes. Common errors are:

- Not having set the API key and secret
- Insufficient permissions for the API key
- Validation error of the `serverless.yml` file (see [Types and Schema validation](#Types-and-Schema-validation))

Usually, fixing the error and retrying the deploy should suffice as any existing resources will fall within the `update` clause of the deployment. However, if unsure, you can always call `sls remove` to remove the entire stack, and retry.

Action secrets are encrypted key-value pairs and injected at runtime into the lambda environment. Secrets are scoped to all actions automatically. Alternatively, you may use environment-variables to define key-value pairs that are scoped to the individual action, and available at runtime through `process.env`. Note that these values are not encrypted.

## Publish a new release

```bash
npm login
git checkout main
git pull origin main
# increment version in package.json
npm publish
git add package.json
git commit -m 'v{version here}'
git push origin main
```
