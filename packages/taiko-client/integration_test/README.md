# How to debug test cases?
* start docker compose
```
./internal/docker/start.sh
```

* deploy L1 contracts
```
# replace $taiko-mono with the taiko-mono repo path.
TAIKO_MONO_DIR=$taiko-mono ./integration_test/deploy_l1_contract.sh
```

* expose environment variables into .env file.
```
# replace $taiko-mono with the taiko-mono repo path.
TAIKO_MONO_DIR=$taiko-mono ./integration_test/test_env.sh
```

* copy the result of previous step and paste it into `Debug configurations`
> after debugging, don't forget stop docker compose!
```
./internal/docker/stop.sh
```