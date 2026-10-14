# Multi-stage Dockerfile for Spring Boot App
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY build/libs/spring-boot-gradle-demo.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
