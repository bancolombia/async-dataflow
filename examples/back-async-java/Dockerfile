FROM gradle:9.3.0-jdk25-alpine AS build
WORKDIR /app
COPY . .
RUN gradle bootJar --stacktrace

FROM eclipse-temurin:17-jdk-alpine
VOLUME /tmp
COPY --from=build /app/applications/app-service/build/libs/*.jar back-async.jar
ENV JAVA_OPTS=" -XX:+UseContainerSupport -Djava.security.egd=file:/dev/./urandom"
# Replace with a non-root user to avoid running the container with excessive privileges
ENTRYPOINT [ "sh", "-c", "java $JAVA_OPTS  -jar back-async.jar" ]
