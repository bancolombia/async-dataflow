FROM eclipse-temurin:17-jdk-alpine

# Set environment variables
ENV JAVA_OPTS=" -XX:+UseContainerSupport -Djava.security.egd=file:/dev/./urandom"

# Define user and group ID (change if needed)
ENV APP_USER=appuser
ENV APP_UID=1001
ENV APP_GID=1001

# Create a group and user
RUN addgroup -g $APP_GID $APP_USER && \
    adduser -D -u $APP_UID -G $APP_USER $APP_USER

# Set up app directory
WORKDIR /app

# Copy the jar and set correct permissions
COPY *.jar /app/back-async.jar
RUN chown -R $APP_USER:$APP_USER /app

# Switch to non-root user
USER $APP_USER

# Define volume
VOLUME /tmp

# Use ENTRYPOINT with exec form for signal handling
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/back-async.jar"]
