FROM kong/kong-gateway:3.7
USER root
RUN apk add --no-cache unzip
RUN luarocks install kong-oidc
USER kong
