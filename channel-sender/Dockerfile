#===============
# Build Stage
#===============
FROM elixir:1.12-alpine as build

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
    tar -xf "${RELEASE_FILE}" -C /export

#===================
# Deployment Stage
#===================
FROM alpine:3.17

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

WORKDIR /home/adfuser

COPY --from=build --chown=adfuser:adfuser /export/ .

USER adfuser

ENTRYPOINT ["/home/adfuser/bin/channel_sender_ex"]
CMD ["start"]   
