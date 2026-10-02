# Changelog

## 1.0.1

- Fix reserved-share discovery for zrok v1.1.12 by using `zrok overview` JSON instead of the nonexistent `zrok list reserved` command.
- Match only reserved shares whose `shareToken` exactly equals the configured share name.

## 1.0.0

- Initial repository release.
- Package zrok CLI 1.1.12.
- Persist zrok environment across app restarts.
- Reuse existing reserved shares.
- Distinguish API/DNS query failures from confirmed share absence.
- Reconcile ambiguous reserve failures before retrying creation.
- Recover safely from `shareConflict` when the existing reservation is visible to the current environment.
- Retry transient failures with exponential backoff.
- Restart the reserved tunnel after unexpected exits.
- Never automatically delete server-side shares.
