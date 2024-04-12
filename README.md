# Infiniblah

Some k8s manifests and scripts for debugging distributed ML training over
Infiniband on k8s.

## The problem

In about 30-40% of cases, we see reduced tokens per second performance when
performing distributed jobs with 2 A100s over Infiniband.

The performance degradation only occurs when going through kubernetes and
doesn't occur when running the same benchmarks from bare metal to bare metal.

On a good run, throughput is like so:
```
Train throughput/tokens_per_sec: 55803.1245
```

On a bad run, throughput is like so:
```
Train throughput/tokens_per_sec: 36769.6582
```

Performance degradation is visible after the first 10 epochs and never recovers
even if left to run for many epochs.

## Some things we've tried

- Benchmarks with `ib_write_bw`
  - Write BW benchmarks are consistently good ~200 gbits
- Upgrading mlnx drivers
- Reinstalling nvidia drivers after installing mlnx drivers
  - This seems like more of a GPU Direct thing
- Benchmarks using `composer` to fine-tune an `MPT` model
  - Shows sporadic performance degradation.
- Benchmarks using `scripts/all_reduce_bench.py` with `slurm`
  - Also shows sporadic performance degradation like `composer`
  - Benchmark comes from https://github.com/stas00/ml-engineering/tree/master/network/benchmarks
- Tried `MacVlanNetwork`, but can't get it to work and get vague `invalid
  argument` error from some part of the `network-operator` stack.

## Other data

MLNX driver info:

```bash
modinfo mlx5_core
filename:       /lib/modules/5.15.0-91-generic/updates/dkms/mlx5_core.ko
alias:          auxiliary:mlx5_core.eth-rep
alias:          auxiliary:mlx5_core.eth
basedon:        Korg 6.3-rc3
version:        24.01-0.3.3
license:        Dual BSD/GPL
description:    Mellanox 5th generation network adapters (ConnectX series) core driver
```

NVIDIA driver verison: `545.23.08`

OS: `Ubuntu 22.04.3`

## Layout

- `bin` contains scripts for running benchmarks on a loop since degradation is
  sporadic and can go 5-6 runs without any problem.
- `manifests` contains the manifests for deployments and IPOIB network
- `scripts` contains a community network benchmark script that can be used to
  reproduce degradation.
- `tmp` includes some examples of the ephemeral scripts and logs generated by
  the scripts in the `bin` directory.

## Running Benchmarks

Running diagnostic benchmarks has four parts:

1. Governor that monitors logs to know when to kill pods and start a new benchmark run.
2. Log dumper for gpu-1
3. Log dumper for gpu-2
4. Human to review logs for signs of degraded throughput.

### Terminal 0

Configure resources and start the governor process that's responsible for
setting up pods and waiting for throughput data.

```bash
kubectl apply -f manifests/ipoib-network.yaml
kubectl apply -f manifests/gpu-1.yaml
kubectl apply -f manifests/gpu-2.yaml
bin/governor.sh
```

### Terminal 1

Run a loop to capture logs for gpu-1:

```bash
while true; do
  # Wait for gpu-1 exec script to exist and then execute it.
  (test -f tmp/bin/gpu-1-exec-benchmark && tmp/bin/gpu-1-exec-benchmark) \
  || sleep 1
done
```

### Terminal 2

Run a loop to capture logs for gpu-2:

```bash
while true; do
  # Wait for gpu-2 exec script to exist and then execute it.
  (test -f tmp/bin/gpu-2-exec-benchmark && tmp/bin/gpu-2-exec-benchmark) \
  || sleep 1
done
```

### Human in the loop

Monitor benchmark output for runs that demonstrate throughput degradation.

#### Example good throughput logs

- [gpu-1](https://github.com/tdg5/infiniblah/blob/main/tmp/gpu-1-logs/good.log#L813-L815)
- [gpu-2](https://github.com/tdg5/infiniblah/blob/main/tmp/gpu-2-logs/good.log#L813-L815)

#### Example bad throughput logs

- [gpu-1](https://github.com/tdg5/infiniblah/blob/main/tmp/gpu-1-logs/bad.log#L813-L815)
- [gpu-2](https://github.com/tdg5/infiniblah/blob/main/tmp/gpu-2-logs/bad.log#L772-L774)
