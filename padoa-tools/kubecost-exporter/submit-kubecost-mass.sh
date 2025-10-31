WINDOW_DAYS="7d"
JOB_SUFFIX=$(date +%s)
# it should always be WINDOW_DAYS - 2
DAYS_TO_SUBSTRACT=5

for i in $(kubectx); do
  kubectx $i
  if [[ "$i" == *"argocd"* ]]; then
    kubectl create job --namespace 'kubecost' --from=cronjob/kubecost-exporter kubecost-exporter-manually-created-$JOB_SUFFIX --dry-run=client --output yaml > original_temp.yaml
    yq eval ".spec.template.spec.containers[0].env[] |= select(.name == \"WINDOW\").value = \"$WINDOW_DAYS\"" -i original_temp.yaml
    yq eval ".spec.template.spec.containers[0].env[] |= select(.name == \"DAYS_TO_SUBSTRACT\").value = \"$DAYS_TO_SUBSTRACT\"" -i original_temp.yaml
    kubectl apply -f original_temp.yaml
  else
    argo submit --namespace 'kubecost' --from cronwf/kubecost-exporter -p window="$WINDOW_DAYS" -p daysToSubstract="$DAYS_TO_SUBSTRACT"
  fi
  rm original_temp.yaml
done;
