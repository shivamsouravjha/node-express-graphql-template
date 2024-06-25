FROM node:18
ARG ENVIRONMENT_NAME
ARG BUILD_NAME
ENV NODE_OPTIONS=--openssl-legacy-provider

RUN mkdir -p /app-build
ADD . /app-build
WORKDIR /app-build
RUN --mount=type=cache,target=/root/.yarn YARN_CACHE_FOLDER=/root/.yarn yarn --frozen-lockfile
RUN yarn
RUN yarn build:$BUILD_NAME


FROM node:18-alpine
ARG ENVIRONMENT_NAME
ARG BUILD_NAME
ENV NODE_OPTIONS=--openssl-legacy-provider

RUN mkdir -p /dist
RUN apk add yarn
RUN yarn global add sequelize-cli@6.2.0
RUN yarn add shelljs bull dotenv pg sequelize@6.6.5
ADD scripts/migrate-and-run.sh /
ADD package.json /
ADD . /
COPY --from=0 /app-build/dist ./dist


CMD ["sh", "./migrate-and-run.sh"]
EXPOSE 9000