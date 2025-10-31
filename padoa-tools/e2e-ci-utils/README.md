# Login to acr

az acr login -n padoa

# Check existing tags in order to not erase a tag

az acr repository show-tags -n padoa --repository padoa-tools/e2e-ci-utils

# Build

docker build --platform linux/amd64 -t padoa.azurecr.io/padoa-tools/e2e-ci-utils:vX.Y.Z .

# Push

docker push padoa.azurecr.io/padoa-tools/e2e-ci-utils:vX.Y.Z
