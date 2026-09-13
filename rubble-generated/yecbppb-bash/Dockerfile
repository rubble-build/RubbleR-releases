# syntax=docker/dockerfile:1
ARG RUBBLE_BASE_IMAGE
FROM ${RUBBLE_BASE_IMAGE}
USER root
RUN --mount=type=bind,source=bootstrap,target=/rubble-bootstrap \
    bash /rubble-bootstrap/install-image.sh
ENTRYPOINT []
