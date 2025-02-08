FROM eclipse-temurin:17-jdk-alpine
VOLUME /tmp
COPY *.jar back-async.jar
ENV JAVA_OPTS=" -XX:+UseContainerSupport -Djava.security.egd=file:/dev/./urandom"
# Replace with a non-root user to avoid running the container with excessive privileges
ENTRYPOINT [ "sh", "-c", "java $JAVA_OPTS  -jar back-async.jar" ]
