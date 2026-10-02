#!/usr/bin/env bash
set -u

OPTIONS="/data/options.json"
export HOME="/data"

RETRY_MIN=5
RETRY_MAX=60
STOPPING=0
CHILD_PID=""
RESERVED_OUTPUT=""

log() {
    echo "[zrok-persistent] $*"
}

stop_handler() {
    STOPPING=1
    log "Shutdown requested."
    if [ -n "${CHILD_PID}" ] && kill -0 "${CHILD_PID}" 2>/dev/null; then
        log "Stopping zrok tunnel..."
        kill -TERM "${CHILD_PID}" 2>/dev/null || true
        wait "${CHILD_PID}" 2>/dev/null || true
    fi
    exit 0
}
trap stop_handler TERM INT

ENABLE_TOKEN="$(jq -r '.enable_token // empty' "$OPTIONS")"
SHARE_NAME="$(jq -r '.share_name // "tnethome"' "$OPTIONS")"
TARGET="$(jq -r '.target // "http://localhost:8123"' "$OPTIONS")"

[ -n "$ENABLE_TOKEN" ] || { log "ERROR: enable_token is not configured."; exit 1; }
[ -n "$SHARE_NAME" ] || { log "ERROR: share_name is empty."; exit 1; }
[ -n "$TARGET" ] || { log "ERROR: target is empty."; exit 1; }

sleep_retry() {
    local seconds="$1"
    [ "$STOPPING" -eq 0 ] || exit 0
    log "Retrying in ${seconds} seconds..."
    sleep "$seconds"
}

increase_backoff() {
    local next=$(( $1 * 2 ))
    [ "$next" -le "$RETRY_MAX" ] || next="$RETRY_MAX"
    echo "$next"
}

environment_exists() {
    [ -f "/data/.zrok/environment.json" ]
}

enable_environment() {
    local output rc
    log "Enabling zrok environment..."
    output="$(zrok enable "$ENABLE_TOKEN" --headless 2>&1)"
    rc=$?
    printf '%s\n' "$output"
    if [ "$rc" -eq 0 ]; then
        log "zrok environment enabled successfully."
        return 0
    fi
    log "Unable to enable zrok environment."
    return 1
}

wait_for_environment() {
    local delay="$RETRY_MIN"
    while [ "$STOPPING" -eq 0 ]; do
        if environment_exists; then
            log "Using existing persistent zrok environment."
            return 0
        fi
        log "No persistent zrok environment found."
        if enable_environment; then
            return 0
        fi
        log "Environment enable failed; treating this as temporary."
        sleep_retry "$delay"
        delay="$(increase_backoff "$delay")"
    done
}

query_reserved_shares() {
    local rc
    RESERVED_OUTPUT="$(zrok overview 2>&1)"
    rc=$?
    return "$rc"
}

reservation_visible() {
    printf '%s\n' "$RESERVED_OUTPUT" | jq -e --arg share "$SHARE_NAME" '
        any(.environments[]?.shares[]?;
            (.reserved == true) and (.shareToken == $share)
        )
    ' >/dev/null 2>&1
}

is_unauthorized() {
    printf '%s\n' "$1" | grep -Eqi 'shareUnauthorized|environmentUnauthorized|\[401\]|unauthorized'
}

recover_unauthorized_environment() {
    log "Current zrok environment is unauthorized."
    log "Resetting LOCAL environment credentials only; server-side shares will not be deleted."
    rm -rf "/data/.zrok"
    wait_for_environment
}

ensure_reservation() {
    local delay="$RETRY_MIN"
    local create_output create_rc query_output

    while [ "$STOPPING" -eq 0 ]; do
        RESERVED_OUTPUT=""
        log "Querying reserved shares..."

        if query_reserved_shares; then
            if reservation_visible; then
                log "Reserved share '${SHARE_NAME}' exists; reusing it."
                return 0
            fi

            log "Query succeeded and '${SHARE_NAME}' is absent."
            log "Attempting to create the reserved share..."
            create_output="$(zrok reserve public "$TARGET" --unique-name "$SHARE_NAME" 2>&1)"
            create_rc=$?
            printf '%s\n' "$create_output"

            if [ "$create_rc" -eq 0 ]; then
                log "Creation reported success; verifying server state."
            elif is_unauthorized "$create_output"; then
                recover_unauthorized_environment
                delay="$RETRY_MIN"
                continue
            elif printf '%s\n' "$create_output" | grep -qi 'shareConflict'; then
                log "Creation returned shareConflict; reconciling account state."
            else
                log "Creation failed or was ambiguous; reconciling before any retry."
            fi

            sleep 3
            RESERVED_OUTPUT=""
            if query_reserved_shares; then
                if reservation_visible; then
                    log "Found '${SHARE_NAME}' after reconciliation; reusing it."
                    return 0
                fi
                if [ "$create_rc" -ne 0 ] && printf '%s\n' "$create_output" | grep -qi 'shareConflict'; then
                    log "Conflict persists but '${SHARE_NAME}' is not visible to this environment."
                    log "Nothing will be deleted or overwritten."
                else
                    log "'${SHARE_NAME}' is still not visible; waiting before another attempt."
                fi
            else
                query_output="$RESERVED_OUTPUT"
                printf '%s\n' "$query_output"
                if is_unauthorized "$query_output"; then
                    recover_unauthorized_environment
                    delay="$RETRY_MIN"
                    continue
                fi
                log "Unable to verify server state; no new reservation attempt will be made yet."
            fi
        else
            query_output="$RESERVED_OUTPUT"
            printf '%s\n' "$query_output"
            if is_unauthorized "$query_output"; then
                recover_unauthorized_environment
                delay="$RETRY_MIN"
                continue
            fi
            log "Unable to query reserved shares."
            log "This may be DNS, Internet connectivity, or a zrok API problem."
            log "Absence has NOT been assumed; nothing will be created or deleted from this failed query."
        fi

        sleep_retry "$delay"
        delay="$(increase_backoff "$delay")"
    done
}

run_tunnel() {
    local delay="$RETRY_MIN"
    local rc

    while [ "$STOPPING" -eq 0 ]; do
        log "Starting reserved tunnel."
        log "URL    : https://${SHARE_NAME}.share.zrok.io"
        log "Target : ${TARGET}"

        zrok share reserved "$SHARE_NAME" --headless --force-local &
        CHILD_PID=$!
        wait "$CHILD_PID"
        rc=$?
        CHILD_PID=""

        [ "$STOPPING" -eq 0 ] || exit 0

        log "Tunnel process exited with code ${rc}."
        log "Reconciling zrok state before reconnecting."
        ensure_reservation
        sleep_retry "$delay"
        delay="$(increase_backoff "$delay")"
    done
}

log "Starting zrok Persistent Tunnel"
log "Reserved share : ${SHARE_NAME}"
log "Target         : ${TARGET}"

zrok version || { log "ERROR: zrok executable failed."; exit 1; }

wait_for_environment
ensure_reservation
run_tunnel
