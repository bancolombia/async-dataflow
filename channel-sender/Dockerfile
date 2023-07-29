#===============
# Build Stage
#===============
FROM elixir:1.12-alpine as build

ARG BUILD_ENV=prod
ARG BUILD_VER=0.1.3

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
RUN RELEASE_DIR=`ls -d _build/${BUILD_ENV}/` && \
    mkdir /export && \
    tar -xf "${RELEASE_DIR}/channel_sender_ex-${BUILD_VER}.tar.gz" -C /export

#===================
# Deployment Stage
#===================
FROM alpine:3.17

ARG BUILD_REL=channel_sender_ex

RUN apk upgrade --no-cache && \
    apk add --no-cache \
      ncurses-libs \
      libstdc++ \
      libgcc \
      zlib \
      openssl \
      ca-certificates \
      bash

WORKDIR /app

COPY --from=build /export/ .

ENTRYPOINT ["/app/bin/channel_sender_ex"]
CMD ["start"]   
