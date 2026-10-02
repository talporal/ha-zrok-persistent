# zrok Persistent Tunnel

Runs a persistent zrok reserved public share for Home Assistant.

## Configuration

- **enable_token** — zrok account enable token. Keep this secret.
- **share_name** — reserved zrok share name, for example `tnethome`.
- **target** — local HTTP target. Default: `http://localhost:8123`.

## Recovery behavior

At startup the app waits for the zrok API to become reachable before making state decisions. A DNS, Internet, or API failure is never treated as proof that a reservation is absent.

If the configured reservation already exists and is visible to the current zrok environment, it is reused. If a creation request times out or returns an ambiguous error, the app queries zrok again before attempting another creation. A `409 shareConflict` likewise causes reconciliation rather than deletion.

The app does not automatically delete server-side zrok shares.
