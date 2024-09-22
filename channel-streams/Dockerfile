#===============
# Build Stage
#===============
FROM elixir:1.16-otp-26-alpine as build

RUN apk upgrade --no-cache && \
    apk add --no-cache \
    git 

ARG BUILD_ENV=prod

WORKDIR /build

# Copy the source folder into the Docker image
COPY . .

RUN mix local.hex --force

RUN mix local.rebar --force 

# Install dependencies and build Release
RUN export MIX_ENV=${BUILD_ENV} && \
    mix deps.get && \
    mix release adf_streams

# copy binaries
RUN mkdir /export && \
    cp container_utils/runner.sh /export && \
    cp -r _build/${BUILD_ENV}/. /export

#==============================
# Build image for runtime stage
#==============================
FROM alpine:3.17 as runtime

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

