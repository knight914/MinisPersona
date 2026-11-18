# MinisPersona

A standalone interim CLI, not an iOS tweak or native bridge. Requires Python 3.7+ (standard library only). Apply additionally requires the real `minis-config` on your PATH inside Minis.

```sh
cd /var/minis/shared/github/MinisPersona
python3 persona.py list
python3 persona.py preview --preset concise
python3 persona.py apply --preset concise
```

List and preview work offline and never call `minis-config`. Preview shows the proposed replacement values, not a diff against current settings. `writing`, `concise`, and `review` contain only the reviewed tone and personality text from the local `com.aztut.app_1.14/persona-presets.json`.

## Custom editing

Create and edit a local UTF-8 JSON file such as `custom.json`:

```json
{"style":"Warm and direct","body":"Lead with the answer. Mark uncertainty clearly."}
```

```sh
python3 persona.py preview --file custom.json
python3 persona.py apply --file custom.json
```

Use trusted text and preview it before applying. Both fields are required and nonblank. The CLI caps style at 200 Python characters; Minis performs final validation, including its own 3000-unit body limit. Keep secrets out of persona text.

## Apply and roll back

Apply submits exactly `soul.style` and `soul.body` in one `minis-config set-batch` call over stdin and leaves confirmation to the app. It does not write Soul name, icon, or language, patch the app, or intercept or rewrite network/system requests. Minis itself uses Soul text as response guidance. The CLI passes through native output and status without retries; follow the native message for audit details. Rejection (125), timeout (124), and permission denial (126) are not success.

In Minis, open **Logs → Config Changes**, inspect the matching entry and revert it there. Alternatively:

```sh
minis-config audit-list --scope soul
minis-config audit-get <audit-id>
minis-config audit-revert <audit-id>
```

Replace `<audit-id>` with the actual ID (without angle brackets). Verify the old/new values and check for later edits before reverting; rollback requires app confirmation and depends on the entry still being in Minis's rolling audit log.

## Tests

```sh
python3 -B -m unittest -v
```

Tests mock the config subprocess. Live app confirmation, application, and rollback are not exercised by the tests.
