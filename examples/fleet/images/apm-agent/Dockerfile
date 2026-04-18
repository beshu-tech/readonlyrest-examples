ARG ES_VERSION=please_set_es_version_arg

FROM docker.elastic.co/elastic-agent/elastic-agent:${ES_VERSION}

USER root

RUN if command -v apt-get > /dev/null; then \
      apt-get update && apt-get install -y --no-install-recommends curl jq && rm -rf /var/lib/apt/lists/*; \
    elif command -v microdnf > /dev/null; then \
      microdnf install -y jq && microdnf clean all; \
    else \
      dnf install -y jq && dnf clean all; \
    fi

COPY entrypoint.sh /entrypoint.sh

USER elastic

ENTRYPOINT [ "/entrypoint.sh" ]
