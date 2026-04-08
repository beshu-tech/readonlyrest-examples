  @@KBN_INSTANCE_NAME@@:
    build:
      context: @@ENVIROMENT_DIR@@
      dockerfile: images/kbn/${KBN_DOCKERFILE:-KBN_DOCKERFILE_NOT_CONFIGURED}
      args:
        KBN_VERSION: ${KBN_VERSION:-KBN_VERSION_NOT_CONFIGURED}
        ROR_VERSION: ${ROR_KBN_VERSION:-ROR_KBN_VERSION_NOT_CONFIGURED}
        ROR_FILE: ${KBN_ROR_FILE:-KBN_ROR_FILE_NOT_CONFIGURED}
        ROR_LICENSE_EDITION: ${ROR_LICENSE_EDITION:-ROR_LICENSE_EDITION_NOT_CONFIGURED}
    depends_on:
      es-ror:
        condition: service_healthy
    ports:
      - "@@KBN_INSTANCE_PORT@@:5601"
    environment:
      ELASTICSEARCH_HOSTS: https://es-ror:9200
      ROR_ACTIVATION_KEY: $ROR_ACTIVATION_KEY
    healthcheck:
      test: ["CMD-SHELL", "curl -fksS --connect-timeout 3 --max-time 5 --retry 2 --retry-connrefused -u admin:admin https://127.0.0.1:5601/api/features >/dev/null || exit 1"]
      interval: 10s
      timeout: 10s
      retries: 30
      start_period: 60s
    volumes:
      - @@KBN_INSTANCE_KIBANA_YML@@:/usr/share/kibana/config/kibana.yml:ro
    networks:
      - ror-network
    ulimits:
      memlock:
        soft: -1
        hard: -1
