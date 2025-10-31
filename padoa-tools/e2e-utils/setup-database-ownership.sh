#!/bin/sh
set -e


PGPASSWORD=${PGPASSWORD:-$(cat "$PGPASSWORD_FILE")}
DATABASE=$1
export PGPASSWORD

echo "
BEGIN;
    CREATE OR REPLACE PROCEDURE \"pg_catalog\".install_all_extensions_public()
    AS
    \$\$
      -- postgis
      CREATE EXTENSION IF NOT EXISTS postgis;
      CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
      CREATE EXTENSION IF NOT EXISTS postgis_topology;
      CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;
      -- anon
      LOAD 'anon.so';
      CREATE EXTENSION IF NOT EXISTS anon CASCADE;
      CREATE SCHEMA IF NOT EXISTS anon;
    \$\$
    LANGUAGE sql;

    ALTER USER owner with superuser;

    GRANT ALL PRIVILEGES ON SCHEMA public TO \"owner\";
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"owner\";
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO \"owner\";
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO \"owner\";

    REASSIGN OWNED BY resetdb TO owner;
    GRANT owner TO postgres;

    ALTER SCHEMA \"public\" OWNER to owner;
    ALTER DATABASE \"$DATABASE\" OWNER TO owner;

    ALTER USER owner with nosuperuser;
COMMIT;
" | psql -v ON_ERROR_STOP=1 -d "$DATABASE"
