FROM kong/kong-gateway:3.7
USER root
RUN apt-get update \
    && apt-get install -y curl jq \
    && rm -rf /var/lib/apt/lists/*
USER kong
