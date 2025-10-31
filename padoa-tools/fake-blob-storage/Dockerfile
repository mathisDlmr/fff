FROM node:20.16.0-slim AS dist

ARG BUILD_ENV

RUN apt update && apt install -y faketime 

WORKDIR /src

COPY package.json yarn.lock /src/

RUN npm run yarn

COPY . /src

RUN mkdir ./data

EXPOSE 10000

COPY ./libfaketime.sh /libfaketime.sh

ENTRYPOINT [ "/libfaketime.sh", "docker-entrypoint.sh" ]

CMD ["npm", "start"]
