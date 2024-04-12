#!/bin/bash

# From https://stackoverflow.com/a/4774063
REPO_DIR="$( cd -- "$(dirname "$0")/.." >/dev/null 2>&1 ; pwd -P )"

BIN_DIR="$REPO_DIR/bin"
TMP_DIR="$REPO_DIR/tmp"
TMP_BIN_DIR="$TMP_DIR/bin"

# Clean up previous convenience scripts
for TMP_BIN in exec-bash exec-benchmark; do
  for HOST in gpu-1 gpu-2; do
    rm -f "$TMP_BIN_DIR/$HOST-$TMP_BIN"
  done
done

# Run 1000 benchmarks in ideal scenario
for INDEX in $(seq 1 1000); do
  echo "$INDEX : $(date)"

  # Wait for pods to be up at least 1m so `kubectl cp` will work
  while ! `$BIN_DIR/setup-k8s-test.sh get | grep -q 'Running.*m'`; do
    sleep 5
  done

  # Keep trying to set up the pods until we've discovered the pods and created
  # convenience `kubectl exec` scripts.
  while [ ! -f "$TMP_BIN_DIR/gpu-1-exec-benchmark" ]; do
    INDEX="$INDEX" $BIN_DIR/setup-k8s-test.sh setup
  done

  # Watch the logs until we see data on throughput, then kill the pods and
  # start again.
  while true; do
    if `grep -q 'throughput/tokens_per_sec' "gpu-1-logs/$INDEX.log"`; then
      break
    else
      sleep 5
    fi
  done
  $BIN_DIR/setup-k8s-test.sh delete
done
