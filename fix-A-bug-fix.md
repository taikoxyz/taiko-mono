command to check prover relayer logs for L2 there is wrong command.
Link : https://taiko.xyz/docs/guides/run-a-node/enable-a-prover#verify-prover-logs

For L2 node should use the command docker compose logs -f taiko_client_prover_relayer instead but in there is docker compose logs -f l3_taiko_client_prover_relayer which should be for the L3 node
