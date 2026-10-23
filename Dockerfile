# syntax=docker/dockerfile:1

# Official postgres image tag (optionally pinned by digest), e.g. 18.6-trixie, 18-alpine.
ARG BASE_IMAGE=postgres:18

FROM ${BASE_IMAGE}

# Demo database release (YYYYMMDD) and dataset size (3m, 6m, 1y, 2y).
ARG DEMODB_VERSION=20250901
ARG DEMODB_SIZE=3m

ENV DEMODB_VERSION=${DEMODB_VERSION} \
    DEMODB_SIZE=${DEMODB_SIZE} \
    DEMODB_LANG=en

# The dump is downloaded into ./dumps by scripts/fetch-dump.sh before building.
COPY --chmod=0555 dumps/demo-${DEMODB_VERSION}-${DEMODB_SIZE}.sql.gz /opt/demodb/demo.sql.gz
COPY --chmod=0755 docker-entrypoint-initdb.d/ /docker-entrypoint-initdb.d/

LABEL org.opencontainers.image.title="PostgreSQL with the Postgres Professional demo database (Airlines)" \
      org.opencontainers.image.description="Official postgres image that loads demo database ${DEMODB_VERSION}-${DEMODB_SIZE} on first start" \
      org.opencontainers.image.source="https://github.com/jinahya/postgresql-demodb-docker" \
      org.opencontainers.image.url="https://postgrespro.com/community/demodb" \
      org.opencontainers.image.licenses="MIT" \
      com.postgrespro.demodb.version="${DEMODB_VERSION}" \
      com.postgrespro.demodb.size="${DEMODB_SIZE}"
