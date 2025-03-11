#===============
# Build Stage
#===============
FROM elixir:1.17.3-otp-27-alpine as build

ARG BUILD_ENV=prod

WORKDIR /build

# Copy the source folder into the Docker image
COPY . .

RUN mix local.hex --force

RUN mix local.rebar --force 

# Install dependencies and build Release
RUN export MIX_ENV=${BUILD_ENV} && \
    mix deps.get && \
    mix release channel_sender_ex

# Extract Release archive to /rel for copying in next stage
RUN RELEASE_FILE=`ls -d _build/${BUILD_ENV}/*.gz` && \
    mkdir /export && \
    cp container_utils/runner.sh /export && \
    tar -xf "${RELEASE_FILE}" -C /export

#===================
# Deployment Stage
#===================
FROM alpine:3.21.3

RUN apk upgrade --no-cache && \
    apk add --no-cache \
      ncurses-libs \
      libstdc++ \
      libgcc \
      zlib \
      openssl \
      ca-certificates \
      bash

RUN addgroup -S adfuser && adduser -S adfuser -G adfuser

WORKDIR /app

COPY --from=build --chown=adfuser:adfuser /export/ .

USER adfuser

VOLUME /app/config

ENTRYPOINT ["/bin/bash"]
CMD ["/app/runner.sh"]  

