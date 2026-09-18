FROM node:22-bookworm-slim

ARG OPENCODE_VERSION=OPENCODE_VERSION_NOT_CONFIGURED

# git: opencode treats its working directory as a project and shells out to git.
RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && npm i -g "opencode-ai@${OPENCODE_VERSION}"

# The Claude Pro/Max sign-in lives in an opencode plugin that is fetched from
# npm the first time it is needed. `opencode models` is the cheapest command
# that triggers that install, so the plugin is baked into the image instead of
# being downloaded while the user waits at the login prompt. The config written
# here is only the prewarm trigger - at runtime the example mounts its own.
RUN mkdir -p /root/.config/opencode \
 && echo '{"plugin":["opencode-anthropic-auth"]}' > /root/.config/opencode/opencode.json \
 && opencode models > /dev/null \
 && rm /root/.config/opencode/opencode.json

ENV TERM=xterm-256color

# An empty working directory keeps the agent pointed at the Elasticsearch MCP
# tools rather than at files.
WORKDIR /workspace

# The container only has to stay up - the user attaches to it with
# `docker exec -it opencode opencode`.
CMD ["sleep", "infinity"]
