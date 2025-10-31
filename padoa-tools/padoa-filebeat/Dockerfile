FROM docker.elastic.co/beats/filebeat-oss:7.12.1


COPY filebeat.yml /usr/share/filebeat/filebeat.yml
COPY pipeline.yml /usr/share/filebeat/module/postgresql/log/ingest/pipeline.yml
COPY log.yml /usr/share/filebeat/module/postgresql/log/config/log.yml
USER root
RUN chown root:filebeat /usr/share/filebeat/filebeat.yml

# USER filebeat

