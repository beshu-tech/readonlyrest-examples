FROM docker.elastic.co/elastic-agent/elastic-agent:8.15.0

USER root

RUN apt-get update && \
    apt-get install -y curl jq net-tools

COPY entrypoint.sh /entrypoint.sh

USER elastic

ENTRYPOINT [ "/entrypoint.sh" ]
