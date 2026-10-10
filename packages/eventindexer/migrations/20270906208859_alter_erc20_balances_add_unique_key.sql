-- +goose Up
-- +goose StatementBegin
-- (contract_address, address, chain_id) is the logical identity of an ERC20
-- balance: the indexer looks a balance up by exactly these three columns, and
-- two rows agreeing on them means one account has two balances for one token.
-- A plain index cannot stop that; only a unique key can.
--
-- It replaces erc20_balances_contract_address_address_chain_id_index rather than
-- sitting beside it: the leading columns are identical, so the old index is
-- redundant once the unique key exists, and leaving both in place would let the
-- planner pick the non-unique one for the locking read in
-- findERC20BalanceForUpdate.
--
-- If the table already holds duplicates this ALTER fails with ER_DUP_ENTRY,
-- which is intended: collapsing them is a data decision, not a schema one. Check
-- first with:
--   SELECT contract_address, address, chain_id, COUNT(*) FROM erc20_balances
--   GROUP BY contract_address, address, chain_id HAVING COUNT(*) > 1
ALTER TABLE `erc20_balances`
  DROP INDEX `erc20_balances_contract_address_address_chain_id_index`,
  ADD UNIQUE KEY `erc20_balances_contract_address_address_chain_id_unique` (`contract_address`, `address`, `chain_id`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
ALTER TABLE `erc20_balances`
  DROP INDEX `erc20_balances_contract_address_address_chain_id_unique`,
  ADD INDEX `erc20_balances_contract_address_address_chain_id_index` (`contract_address`, `address`, `chain_id`);

-- +goose StatementEnd
