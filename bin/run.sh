COMMAND="$1"

if [ -z "$COMMAND" ]; then
  echo "missing COMMAND"
  exit 1
fi

# Install some dependencies
which rsync || (apt-get update && apt-get install -y iftop iproute2 nethogs rsync)

# Print infiniband info for diagnostic purposes
ibstat
iblinkinfo
ibdev2netdev

# Run benchmark with composer
if [ "$COMMAND" = "composer" ]; then
  # Copy dataset to local drive to avoid NFS confounding data
  rsync -rv /nfs/mpt_7b/c4/ /root/c4

  # Run the benchmark
  export WORLD_SIZE=16
  # Always use 192.168.6.225 as the master
  export MASTER_ADDR=192.168.6.225
  # Check if this pod has randomly received the 192.168.6.225 IP this time
  export NODE_RANK=$(ip a | grep -q "$MASTER_ADDR" && echo 0 || echo 1)
  export MASTER_PORT=12345

  # See https://github.com/mosaicml/llm-foundry/tree/main/scripts/train
  composer github/llm-foundry/scripts/train/train.py \
      github/llm-foundry/scripts/train/yamls/pretrain/mpt-7b.yaml \
      max_seq_len=2048 \
      precision=amp_bf16 \
      data_local=/root/c4 \
      train_loader.dataset.split=train_small \
      eval_loader.dataset.split=val_small \
      max_duration=100ba \
      eval_interval=1ep \
      device_eval_microbatch_size=16 \
      eval_first=False \
      global_train_batch_size=256 \
      device_train_microbatch_size=16
  exit 0

# Run benchmark with slurm
elif [ "$COMMAND" = "slurm" ]; then
  export GPUS_PER_NODE=8 \
    NNODES=2 \
    # Always use 192.168.6.225 as the master
    MASTER_ADDR=192.168.6.225 \
    MASTER_PORT=12345
  python -u -m torch.distributed.run \
      --nproc_per_node $GPUS_PER_NODE \
      --nnodes $NNODES \
      --rdzv_endpoint $MASTER_ADDR:$MASTER_PORT \
      --rdzv_backend c10d \
      --max_restarts 0 \
      --role `hostname -s`: \
      --tee 3 \
      all_reduce_bench.py
fi
