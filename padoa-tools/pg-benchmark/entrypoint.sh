#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

set -x

if ! kubectl get pod ${POD_NAME} >/dev/null 2>&1; then
    echo "Error: Pod ${POD_NAME} does not exist"
    exit 1
fi

# Create benchmark directory in /pgdata
kubectl exec ${POD_NAME} -c database -- mkdir -p /pgdata/benchmark

# Copy the script to the pod
kubectl cp ./scripts/pg_benchmark.sh ${POD_NAME}:/pgdata/benchmark/pg_benchmark.sh --container database

# Make the script executable
kubectl exec ${POD_NAME} -c database -- chmod +x /pgdata/benchmark/pg_benchmark.sh

# Run the quick script directly
kubectl exec ${POD_NAME} -c database -- /pgdata/benchmark/pg_benchmark.sh --scenario=classic || true # The script exit 10 if successful

# Run the script with nohup
kubectl exec ${POD_NAME} -c database -- /bin/bash -c "nohup /pgdata/benchmark/pg_benchmark.sh --scenario=watch --watch-period=86400 --watch-interval=60 > /pgdata/benchmark/pg_benchmark_watch.log 2>&1 &"

# Exit successfully
exit 0
