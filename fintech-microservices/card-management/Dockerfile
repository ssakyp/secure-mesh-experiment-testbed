FROM maven:3.9-eclipse-temurin-17-focal AS builder
WORKDIR /app
COPY . .
RUN mvn clean package -DskipTests || mvn clean package -DskipTests
FROM eclipse-temurin:17-jre-focal
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
EXPOSE 8080
CMD ["java", "-Xmx256m", "-jar", "app.jar"]
