#!/bin/bash

# Set up pods and local env so we are prepared to run infiniband benchmarks.

# From https://stackoverflow.com/a/4774063
REPO_DIR="$( cd -- "$(dirname "$0")/.." >/dev/null 2>&1 ; pwd -P )"
BIN_DIR="$REPO_DIR/bin"
TMP_DIR="$REPO_DIR/tmp"
TMP_BIN_DIR="$TMP_DIR/bin"

ACTION="$1"

if [ -z "$ACTION" ]; then
  echo "Missing argument #1, ACTION"
  exit 1
fi

if [ "$ACTION" = "setup" -a -z "$INDEX" ]; then
  echo "Missing INDEX"
  exit 2
fi

NAMESPACE="infiniblah"
#BENCHMARK=slurm
BENCHMARK=composer

ALL_PODS=$(kubectl -n "$NAMESPACE" get pods -o go-template='{{ range .items }}{{.metadata.name}}{{ printf "\n" }}{{end}}')
TEST_PODS=$(echo "$ALL_PODS" | grep -E '-1|-2')

if [ "$ACTION" = "setup" ]; then
  for TEST_POD in $(echo "$TEST_PODS"); do
    # Set up the pods by copying relevant files and making them executable
    kubectl -n "$NAMESPACE" cp $BIN_DIR/run.sh "${TEST_POD}:run.sh"
    kubectl -n "$NAMESPACE" cp $BIN_DIR/scripts/all_reduce_bench.py "${TEST_POD}:all_reduce_bench.py"
    kubectl -n "$NAMESPACE" exec -it "${TEST_POD}" -- chmod u+x run.sh
    # Set up local environment with convenience scripts for `kubectl exec` to pods
    if `echo "${TEST_POD}" | grep -q gpu-1`; then
      echo "kubectl -n $NAMESPACE exec -it ${TEST_POD} -- bash run.sh $BENCHMARK | tee $TMP_DIR/gpu-1-logs/${INDEX}.log" > $TMP_BIN_DIR/gpu-1-exec-benchmark
      echo "kubectl -n $NAMESPACE exec -it ${TEST_POD} -- bash" > $TMP_BIN_DIR/gpu-1-exec-bash
      chmod u+x $TMP_BIN_DIR/gpu-1-exec-bash
      chmod u+x $TMP_BIN_DIR/gpu-1-exec-benchmark
    else
      echo "kubectl -n $NAMESPACE exec -it ${TEST_POD} -- bash run.sh $BENCHMARK | tee $TMP_DIR/gpu-2-logs/${INDEX}.log" > $TMP_BIN_DIR/gpu-2-exec-benchmark
      echo "kubectl -n $NAMESPACE exec -it ${TEST_POD} -- bash" > $TMP_BIN_DIR/gpu-2-exec-bash
      chmod u+x $TMP_BIN_DIR/gpu-2-exec-bash
      chmod u+x $TMP_BIN_DIR/gpu-2-exec-benchmark
    fi
  done
elif [ "$ACTION" = "delete" ]; then
  # Delete the pods so deployment can recreate them
  for TEST_POD in $(echo "$TEST_PODS"); do
    kubectl -n "$NAMESPACE" delete pod "$TEST_POD"
  done
elif [ "$ACTION" = "get" ]; then
  # Get pods matching expected pattern
  kubectl -n "$NAMESPACE" get pods | grep -E 'gpu-(1|2)'
fi
