# MinisPersona

MinisPersona includes a native draft editor for Minis and a separate CLI. The editor cannot apply settings.

## Native draft editor

In a supported Minis app window (`com.openminis.app`), tap **Persona** at the upper right. Edit **Style** and **Body**, then tap **Preview JSON** or **Copy JSON**. Copy writes plain text to the device-only clipboard with a ten-minute expiration. Copy does not save the draft or apply it. **Save Local Draft** stores the fields under one namespaced preference in the app container; closing discards unsaved edits. Keep secrets out of drafts and the clipboard.

To apply, paste the copied JSON into a UTF-8 file and use the CLI commands below. There is no native bridge, request interception, or network access in the editor. Bundled presets remain available via the CLI.

To remove the editor, optionally use **Clear Local Draft** first, then remove `com.knight914.minispersona` using the package manager and reopen Minis. Uninstalling does not revert any CLI-applied settings or necessarily clear the draft preference, clipboard, or files you exported. Use the audit rollback below for CLI-applied settings.

## CLI

Requires Python 3.7+ (standard library only). Apply additionally requires the real `minis-config` on your PATH inside Minis.

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

## macOS build and formal packaging

The native target requests iOS 15+ and `arm64`/`arm64e`. `.github/workflows/build.yml` is manual-only; `.github/scripts/build.sh` selects pinned official Theos (`theos/theos`, `rootless`) or RootHide Theos (`roothide/theos`, `roothide`) with recursive submodules. The jobs use separate runners, checkouts, build trees, and package outputs, select the runner's Apple iPhoneOS SDK, and log the Xcode, SDK, dependency, and toolchain revisions/versions. The repository does not ship or download a separate SDK.

- **Compile check:** Dispatch with `formal_package` off (default). Both macOS jobs run the CLI tests, lint the bundle filter, and run `make all FINALPACKAGE=1` to compile and link under release flags. This is not a test packaging run: it must not produce or upload a `.deb`.
- **Formal packaging:** Request `formal_package` explicitly at dispatch. Both compile checks must pass before the packaging matrix can run. Configure the `formal-packaging` GitHub Environment with required reviewers before dispatching if a separate post-compile human approval is needed; naming an environment in YAML does not configure reviewers. With approval (where configured), each job does a clean formal build of the same source revision using `make clean package FINALPACKAGE=1`. It checks exact package ID, version, architecture, dependencies, payload location, Mach-O slices, and filter, then uploads a scheme-specific `.deb` artifact. Nothing installs or publishes a release.
- **Version gate:** `control` is the version source; dispatch input must match it. Both schemes and both stages of one dispatch share the version. Start at `0.0.1`; before each new dispatch, including a later formal run after a compile-only run, increment and commit the version in `control`. Failed and canceled dispatches still reserve their recorded versions. The workflow rejects GitHub reruns (including partial reruns in build steps), serializes dispatches, and rejects versions at or below earlier recorded dispatches. Keep workflow history and use a trusted ref: deleted runs and modified workflow code are not an authoritative history. A clean formal rebuild within the same approved dispatch belongs to that dispatch's single version reservation.

Local Linux checks do not validate the iOS link, package format, injection, or presentation. After authorized packaging and installation, test launch and scene changes, that the Persona button does not cover existing controls, save/reopen/clear, validation and Unicode JSON, local clipboard, and absence of any settings change until the user explicitly applies through the CLI. Assess compatibility separately on both jailbreak environments.
