# Lombard Immunefi Forge PoC

This project follows the Immunefi Forge PoC template structure:

- `src/PoC.sol`: minimal PoC base with a `snapshot` modifier.
- `src/AttackContract.sol`: attack flow.
- `test/PoCTest.sol`: fork setup and `testAttack()`.

Run:

```bash
forge test -vv --match-path test/PoCTest.sol
```

Expected result:

```text
[PASS] testAttack()
```

The test forks Ethereum mainnet at block `23842682`, constructs a GMP mint payload with the Base inbound path instead of the Ledger inbound path, calls `AssetRouter.handlePayload()` as the Mailbox, and shows the historical recipient's staked LBTC balance increasing by `299403043`.
