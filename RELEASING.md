# Releasing

Home Assistant discovers app updates from the version in `zrok/config.yaml`. A GitHub Release is not required for Supervisor update discovery, but this repository uses tagged GitHub Releases to make releases auditable and easy to maintain.

## Versioning

The Home Assistant app uses semantic versions independently of the bundled zrok CLI.

Examples:

- Patch: wrapper bug fix — `1.0.1 -> 1.0.2`
- Minor: backward-compatible feature — `1.0.x -> 1.1.0`
- Major: breaking configuration or migration — `1.x -> 2.0.0`

The upstream zrok version is controlled separately by `ZROK_VERSION` in `zrok/Dockerfile`.

## Release procedure

1. Make and test the code changes.
2. Add a new section to `zrok/CHANGELOG.md`.
3. Bump `version` in `zrok/config.yaml`.
4. Push to `main` and wait for the Validate workflow to pass.
5. Create and push a tag matching the app version exactly, e.g. `v1.0.2`.
6. The Release workflow verifies that the tag matches `config.yaml` and creates the GitHub Release from the matching changelog section.

Home Assistant installations that have this repository configured will see the newer app version after the repository refreshes. The user may enable Home Assistant's automatic update option for the installed app if available.

## Important

Never commit a zrok enable token or a populated `options.json`.

Do not release or delete a user's reserved zrok share as part of an app update. Persistent runtime state belongs in the app's `/data` directory and is preserved by Supervisor across normal app updates.
