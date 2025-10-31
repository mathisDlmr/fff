FROM docker.elastic.co/beats/filebeat-oss:7.12.1


COPY filebeat.yml /usr/share/filebeat/filebeat.yml
COPY pipeline.yml /usr/share/filebeat/module/postgresql/log/ingest/pipeline.yml
COPY pipeline-permissive.yml /usr/share/filebeat/module/postgresql/log/ingest/pipeline-permissive.yml
COPY log.yml /usr/share/filebeat/module/postgresql/log/config/log.yml
COPY manifest.yml /usr/share/filebeat/module/postgresql/log/manifest.yml

USER root
RUN set -ex; \
  chown 26:26 /usr/share/filebeat/filebeat.yml; \
  chmod go-w /usr/share/filebeat/filebeat.yml
RUN chown -R 26:26 /usr/share/filebeat
