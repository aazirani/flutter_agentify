---
name: reliable-mutations
description: How an action changes data safely, by validating everything first, batching related writes in one transaction, re-reading to verify, reporting "M of N saved" honestly, and never stating a change that the receipt does not show. Use when writing or reviewing an action that writes, or a flow that changes several records.
---

# Reliable mutations

Don't load this for the action's shape, naming and registration; see `actions`.

## Rule

1. Validate every input before the first write. A failure then leaves nothing behind.
2. Related writes (several records, or a record plus its children) go in one database transaction so they all land or none do.
3. After writing, re-read the stored record and set `verified` on the receipt from what you read.
4. When a batch can partly succeed, say so: "2 of 3 saved", with the ids that failed. Never "done".
5. Whatever the assistant tells the person must match the receipts. Do not state a change that no receipt shows.

Enforced by receipts checked in the action tests (`test/actions/`); no lint rule or doctor check exists for it.

## Why

The assistant repeats what the action returns. A half-applied change reported as complete, or a write that never landed, becomes a false statement to the person. A receipt with `verified: false` or a clear count lets the assistant and the UI say what really happened.

## How

Copy `lib/domain/actions/items_actions.dart`:

- **Validate first.** `_title` and `_description` throw `invalid_input` (with the field path) before any repository call. They run inside `run`, not only in the schema, because screens call `registry.run` with typed input that skips the JSON schema. `UpdateItem` also rejects a call that changes nothing.
- **Write, re-read, record.** `CreateItem` calls `items.createItem`, then `items.getItem(created.id)`, then `context.receipt(resource: 'items', ids: [...], summary: ..., verified: stored != null)`. `DeleteItem` sets `verified` to `await items.getItem(input) == null`.
- **Missing target.** Throw `ActionFailure('not_found', ...)` and list `not_found` in `failureCodes`.
- **Several records.** Check all of them first (every id exists, every value is valid). Do the writes in one transaction in the repository, for example `db.transaction(() async { ... })` in the `lib/data/` implementation, so the action calls one repository method. Re-read all ids afterwards. `DeleteItems` is the model: it checks every id (`not_found`, ids in `details`), calls one repository method, re-reads and reports "M of N".
- **If a partial result is unavoidable** (an external call per record), record one receipt with the ids that did save and put "M of N saved" plus the failed ids in the summary and output.
- **Long actions check `context.cancel` before each write.** After the action's `timeout` the caller gets a `timeout` failure but the action keeps running; the registry cancels `context.cancel` so it can stop. Receipts recorded before a thrown `ActionFailure` come back on `failure.receipts`.
- **Return the stored record**, so the model has the real ids and values.

## Anti-patterns

- Looping `createItem` over input and throwing on the third, after two are saved.
- `verified: true` hard-coded without a read.
- A summary written from the input ("Renamed to X") instead of the stored value.
- Swallowing an error and returning success.
- Doing the validation in the dialog only.
- Building the "all done" sentence in the assistant from the request instead of the receipts.

## Verification

- Each action test asserts the stored data and the receipt: see `test/actions/create_item_test.dart` and `test/actions/update_item_test.dart`. Add a case where validation fails and assert nothing was written.
- Use `test/support/actions_harness.dart` to run the action through a registry.
- `dart run tool/action.dart <name> '<json>'` prints the output and receipts.
- `tool/check.sh` ends with `All checks passed.`

## Related skills

- `actions` — the shape of an action and its failure codes.
- `storing-data` — constraints and transactions in the data layer.
- `approval-and-safety` — deletes and bulk changes that need the person's approval.
