# ES Snapshot Manager

<!--toc:start-->
- [ES Snapshot Manager](#es-snapshot-manager)
  - [Local development](#local-development)
<!--toc:end-->

Simple python tool to interact with indexes from workflows.

The tool uses poetry but you can generate the requirements.txt file used in the
docker build.

## Local development

Setup elastecsearch environment:

```bash
export ELASTIC_USER=elastic-internal
export ELASTIC_PASSWORD=
export ELASTIC_HOST=http://localhost:19200
```

For the secret, you can see the value in 1Passoword or in the secret kubernetes.

Run in another terminal:

```bash
k port-forward services/elasticsearch-dev-es-internal-http 19200:9200
```
