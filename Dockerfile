FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    gcc \
    make \
    libssl-dev \
    xxd \
    gdb \
    nano \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /lab
COPY . /lab

RUN make all

CMD ["/bin/bash"]