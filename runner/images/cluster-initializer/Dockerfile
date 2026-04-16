FROM ubuntu:24.04

COPY images/cluster-initializer/entrypoint.sh /entrypoint.sh
COPY utils/init/lib.sh /usr/local/lib/ror-utils.sh

RUN apt-get update --fix-missing && \
    apt-get install -y jq curl && \
    rm -rf /var/lib/apt/lists/*

ENTRYPOINT [ "/entrypoint.sh" ]