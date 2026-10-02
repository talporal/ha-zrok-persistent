# HA zrok Persistent

A Home Assistant app that maintains a persistent [zrok](https://zrok.io/) reserved public share and reconnects it automatically after Home Assistant restarts, network outages, DNS startup delays, and transient zrok API failures.

## Design goals

- Persistent zrok environment in the app's `/data`
- Reuse an existing reserved share instead of recreating it
- Never interpret a failed API/DNS query as "share does not exist"
- Reconcile state after ambiguous create failures and `409 shareConflict`
- Exponential retry/backoff for temporary failures
- Clean shutdown and automatic tunnel restart
- No automatic deletion of server-side shares

## Installation

In Home Assistant, open **Settings → Apps → App store → Repositories** and add:

`https://github.com/talporal/ha-zrok-persistent`

Then install **zrok Persistent Tunnel**, configure your zrok enable token and reserved share name, and start the app.

## Default target

The app uses host networking and proxies to:

`http://localhost:8123`

## Security

Keep your zrok enable token private. It is stored as a password-type Home Assistant app option and should never be committed to this repository.

## Upstream

This project packages the upstream zrok CLI. zrok itself is developed by the OpenZiti project and is not maintained by this repository.
