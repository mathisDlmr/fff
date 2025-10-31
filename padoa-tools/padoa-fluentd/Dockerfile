FROM fluent/fluentd:v1.16.2-1.1

USER root

RUN apk add --no-cache --update --virtual .build-deps build-base ruby-dev curl linux-headers \
    && gem install elasticsearch -v 7.13.3 \
    && gem install fluent-plugin-elasticsearch -v 5.2.5 \
    && gem install fluent-plugin-prometheus \
        fluent-plugin-rewrite-tag-filter \
        fluent-plugin-record-modifier \
        fluent-plugin-concat \
        fluent-plugin-beats \
        fluent-plugin-filter_keys \
        fluent-plugin-parser-cri \
	fluent-plugin-split-array \
        fluent-plugin-rename-key \
    && fluent-gem install fluent-plugin-dedot_filter

# Keep fluentd-plugin-kubernetes_metadata_filter as a separate step to avoid build error
RUN gem install fluent-plugin-kubernetes_metadata_filter
RUN gem sources --clear-all
