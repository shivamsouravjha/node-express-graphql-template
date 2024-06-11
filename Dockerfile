FROM node:14
ARG ENVIRONMENT_NAME
ARG BUILD_NAME
ARG APP_PATH
ENV APP_PATH=${APP_PATH:-/default/path} 
RUN mkdir -p ${APP_PATH}
ADD . ${APP_PATH}
WORKDIR ${APP_PATH}
RUN --mount=type=cache,target=/root/.yarn
RUN yarn
RUN pwd
RUN yarn build:$BUILD_NAME


FROM node:14-alpine
ARG ENVIRONMENT_NAME
ARG BUILD_NAME
ARG APP_PATH
ENV APP_PATH=${APP_PATH:-/default/path} 
RUN yarn global add sequelize-cli@6.2.0 nyc@15.1.0
RUN yarn add shelljs bull dotenv pg sequelize@6.6.5
RUN apk add --no-cache dumb-init
ADD scripts/migrate-and-run.sh ${APP_PATH}/
ADD package.json ${APP_PATH}/
ADD . ${APP_PATH}/
COPY --from=0 ${APP_PATH}/dist ${APP_PATH}/dist
ADD https://keploy-enterprise.s3.us-west-2.amazonaws.com/releases/latest/assets/freeze_time_amd64.so /lib/keploy/freeze_time_amd64.so
RUN chmod +x /lib/keploy/freeze_time_amd64.so
ENV LD_PRELOAD=/lib/keploy/freeze_time_amd64.so


# Set working directory
WORKDIR ${APP_PATH}
ENTRYPOINT ["dumb-init", "--"]

# RUN echo "hi"
STOPSIGNAL SIGINT

# Set entrypoint and command
CMD [ "sh","./scripts/migrate-and-run.sh"]

# Expose port 9000
EXPOSE 9000
