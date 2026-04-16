ARG ES_VERSION=please_set_es_version_arg

FROM docker.elastic.co/elastic-agent/elastic-agent:${ES_VERSION}

USER root

RUN apt-get update && \
    apt-get install -y curl jq

COPY entrypoint.sh /entrypoint.sh

USER elastic

ENTRYPOINT [ "/entrypoint.sh" ]
