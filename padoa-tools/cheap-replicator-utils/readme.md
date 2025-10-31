# Login to acr

az acr login -n padoa

# Change the tag

Do it

# Build

docker build --platform linux/amd64 -t padoa.azurecr.io/padoa-tools/cheap-replicator-utils-utils:vX.Y.Z .

# Push

 docker push padoa.azurecr.io/padoa-tools/cheap-replicator-utils-utils:vX.Y.Z
