# How to debug test cases?

- set up config

```
export L2_NODE=l2_geth
```

- start docker compose

```
./internal/docker/start.sh
```

- deploy L1 contracts

```
./integration_test/deploy_l1_contract.sh
```

- expose environment variables into .env file.

```
./integration_test/test_env.sh
```

- copy the result of previous step and paste it into `Debug configurations`
  > after debugging, don't forget stop docker compose!

```
./internal/docker/stop.sh
```
