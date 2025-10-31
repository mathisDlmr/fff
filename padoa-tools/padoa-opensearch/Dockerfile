FROM opensearchproject/opensearch:2.19.3
RUN /usr/share/opensearch/bin/opensearch-plugin install --batch repository-azure
RUN /usr/share/opensearch/bin/opensearch-plugin install --batch mapper-size

# Remove not used plugins that contain critical CVE
RUN /usr/share/opensearch/bin/opensearch-plugin remove opensearch-skills
RUN /usr/share/opensearch/bin/opensearch-plugin remove opensearch-ml
