#===============
# Build Stage
#===============
FROM elixir:1.11.4-alpine as build

WORKDIR /build

# Copy the source folder into the Docker image
COPY . .

RUN mix local.hex --force

RUN mix local.rebar --force 

# Install dependencies and build Release
RUN export MIX_ENV=dev && \
    mix deps.get && \
    mix release channel_sender_ex

# Extract Release archive to /rel for copying in next stage
RUN APP_NAME="channel_sender_ex" && \
    RELEASE_DIR=`ls -d _build/dev/` && \
    mkdir /export && \
    tar -xf "$RELEASE_DIR/$APP_NAME-0.1.1.tar.gz" -C /export

#===================
# Deployment Stage
#===================
FROM alpine

RUN apk add --no-cache \
      ncurses-libs \
      zlib \
      openssl \
      ca-certificates \
      bash

WORKDIR /app

COPY --from=build /export/ .

CMD ["bin/channel_sender_ex", "start"]