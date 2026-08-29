FROM eclipse-temurin:21-jdk-jammy AS build
WORKDIR /app
COPY gradlew .
COPY gradle gradle
COPY build.gradle.kts settings.gradle.kts gradle.properties ./
RUN ./gradlew --version
COPY src src
RUN ./gradlew bootJar --no-daemon -x test

FROM eclipse-temurin:21-jre-jammy
WORKDIR /app
COPY --from=build /app/build/libs/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
