FROM postgres:14.5-alpine

COPY wal_cleaner.sh /

ENTRYPOINT ["/wal_cleaner.sh"]
