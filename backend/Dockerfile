# Multi-Stage Build für Spring Boot
  FROM maven:3.9-amazoncorretto-17 AS build
  WORKDIR /app

  # Copy pom.xml und download dependencies (cache layer)
  COPY pom.xml .
  RUN mvn dependency:go-offline

  # Copy source und build
  COPY src ./src
  RUN mvn clean package -DskipTests

  # Runtime Stage
  FROM amazoncorretto:17-alpine
  WORKDIR /app

  # Copy JAR from build stage
  COPY --from=build /app/target/*.jar app.jar

  # Expose port
  EXPOSE 8080

  # Health check
  HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:8080/api/todos/health || exit 1

  # Run application
  ENTRYPOINT ["java", "-jar", "app.jar"]