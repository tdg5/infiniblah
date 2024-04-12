# The pods run an image derived from this Dockerfile

FROM mosaicml/llm-foundry:2.2.0_cu121_flash2-latest
RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get -y install tzdata
RUN apt-get install software-properties-common nfs-common -y
RUN add-apt-repository ppa:deadsnakes/ppa

RUN apt-get update && apt-get install --no-install-recommends -y build-essential && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN apt-get update
RUN apt-get install ffmpeg libsm6 libxext6 libgl1 libglib2.0-0 cmake openssh-server git wget curl tmux zsh vim htop -y
RUN apt-get update

# configure missing UTF-8 -- solves tmux issue
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y locales && \
    rm -rf /var/lib/apt/lists/*
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

RUN echo 'service ssh start; exec "$@"' > /entrypoint.sh
RUN chmod u+x /entrypoint.sh

WORKDIR /root/github
RUN git clone https://github.com/mosaicml/llm-foundry.git
WORKDIR /root/github/llm-foundry
RUN pip install -e ".[gpu-flash2]"

WORKDIR /root

EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
CMD ["sleep", "infinity"]
