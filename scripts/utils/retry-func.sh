#!/bin/bash
# Retry a command with exponential backoff and jitter

retry() {
  local status
  local interval=1
  local retry=0
  local -r factor=${RETRY_FACTOR:-2}
  local -r max_tries=${RETRY_MAX_TRIES:-10}
  local -r max_interval=${RETRY_MAX_INTERVAL:-60}
  local -r stop_pattern=${RETRY_STOP_IF_STDERR_MATCHES:-unauthorized}
  local err_file
  err_file=$(mktemp)
  trap 'rm -f "$err_file"' RETURN
  while true; do
    echo "Executing:" "${@}" >&2
    "$@" 2> "$err_file" && break
    status=$?
    cat "$err_file" >&2
    ((retry += 1))
    if [ $retry -ge $max_tries ]; then
      echo "error: Command failed after ${max_tries} tries with status ${status}" >&2
      return $status
    fi
    echo "warning: Command failed and will retry, ${retry} try" >&2

    if [ -n "$stop_pattern" ]; then
      stop_error=$(grep -ci "$stop_pattern" "$err_file")
      if [ "$stop_error" -ne 0 ]; then
        echo "error: Matched stop pattern '${stop_pattern}', won't retry" >&2
        return 1
      fi
    fi

    ((interval = interval * factor))
    if [ "$interval" -gt "$max_interval" ]; then
      interval=$max_interval
    fi
    local jitter=$(( RANDOM % (interval + 1) ))
    local sleep_time=$(( interval + jitter ))
    echo "info: Sleeping ${sleep_time}s (base=${interval}s + jitter=${jitter}s) before retry" >&2
    sleep "$sleep_time"
  done
}

retry "$@"
