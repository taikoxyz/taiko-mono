WITH 
proposing AS (
    SELECT
      DATE(call_block_time) AS date,
      AVG(gas_used) AS avg_proposeBlock_gas_used
    FROM taikoxyz_ethereum.TaikoL1_call_proposeBlockV2 as T1
    INNER JOIN ethereum.transactions AS T0
        ON T1.call_tx_hash = T0.hash
    WHERE
      contract_address = 0x06a9ab27c7e2255df1815e6cc0168d7755feb19a
      AND call_success = TRUE
      AND call_block_time >= CURRENT_TIMESTAMP - INTERVAL '365' day
    GROUP BY
      DATE(call_block_time)
),
proving AS (
    SELECT
      DATE(call_block_time) AS date,
      AVG(gas_used) AS avg_proveBlock_gas_used
    FROM taikoxyz_ethereum.TaikoL1_call_proveBlock as T1
    INNER JOIN ethereum.transactions AS T0
        ON T1.call_tx_hash = T0.hash
    WHERE
      contract_address = 0x06a9ab27c7e2255df1815e6cc0168d7755feb19a
      AND call_success = TRUE
      AND call_block_time >= CURRENT_TIMESTAMP - INTERVAL '365' day
    GROUP BY
      DATE(call_block_time)
)

SELECT 
    COALESCE(a.date, b.date) AS date,
    COALESCE(a.avg_proposeBlock_gas_used, 0) AS gas_used_by_proposing,
    COALESCE(b.avg_proveBlock_gas_used, 0) AS gas_used_by_proving
FROM proposing a
FULL OUTER JOIN proving b ON a.date = b.date
