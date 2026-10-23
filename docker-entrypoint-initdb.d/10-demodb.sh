#!/bin/bash
# Loads the Postgres Professional demo database on first container start.
# Run by the official postgres entrypoint while a temporary server listens on
# the unix socket; POSTGRES_USER is a superuser.
set -Eeo pipefail

dump=/opt/demodb/demo.sql.gz
: "${DEMODB_LANG:=en}"

echo "demodb: loading ${DEMODB_VERSION:-?}-${DEMODB_SIZE:-?} from ${dump} (this can take a while)"

# The dump begins with a plain `DROP DATABASE demo;` (no IF EXISTS), so make
# sure the database exists before replaying it.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres --quiet <<-'EOSQL'
	SELECT 'CREATE DATABASE demo' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'demo')\gexec
EOSQL

gunzip -c "$dump" | psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres --quiet

if [ "$DEMODB_LANG" != "en" ]; then
	echo "demodb: setting bookings.lang to '${DEMODB_LANG}'"
	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres --quiet \
		-c "ALTER DATABASE demo SET \"bookings.lang\" TO '${DEMODB_LANG}'"
fi

echo "demodb: done"
