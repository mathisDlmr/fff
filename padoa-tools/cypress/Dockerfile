ARG NODE_VERSION

FROM cypress/base:"${NODE_VERSION}" as e2e-base

# Installing CLI utilities, used by our own Cypress plugin
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    curl \
    libgbm-dev \
    postgresql-client \
    redis-tools \
    chromium \
  && rm -rf /var/lib/apt/lists/*


# Installing Cypress, but replacing the binaries with the last "unlocked" ones
# https://currents.dev/readme/integration-with-cypress/alternative-cypress-binaries
RUN yarn global add cypress@12.17.4 \
  && npx cypress cache clear \
  && CYPRESS_DOWNLOAD_MIRROR=https://cy-cdn.currents.dev npx cypress install \
  && yarn cache clean \
  && rm -rf /usr/local/share/.cache/yarn/
