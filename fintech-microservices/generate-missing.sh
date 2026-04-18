#!/bin/bash
java_services=("ledger-service" "card-management")
for svc in "${java_services[@]}"; do
  mkdir -p "$svc/src/main/java/com/fintech/$svc"
  cat << 'FOM' > "$svc/pom.xml"
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
	<modelVersion>4.0.0</modelVersion>
	<parent>
		<groupId>org.springframework.boot</groupId>
		<artifactId>spring-boot-starter-parent</artifactId>
		<version>3.1.2</version>
		<relativePath/>
	</parent>
	<groupId>com.fintech</groupId>
	<artifactId>mock-service</artifactId>
	<version>0.0.1-SNAPSHOT</version>
	<properties>
		<java.version>17</java.version>
	</properties>
	<dependencies>
		<dependency>
			<groupId>org.springframework.boot</groupId>
			<artifactId>spring-boot-starter-web</artifactId>
		</dep</dep</dep</dep</dep</dep</dep</dev/aes_0<plugin>
				<groupId>org.springframework.boot</groupId>
				<artifactId>spring-boot-maven-plugin</artifactId>
			</plugin>
		</plugins>
	</build>
</project>
FOM
  pkg_name=$(echo "$svc" | sed 's/-//g')
  mkdir -p "$svc/src/main/java/com/fintech/$pkg_name"
  cat << APP > "$svc/src/main/java/com/fintech/$pkg_name/Application.java"
package com.fintech.$pkg_name;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
@SpringBootApplication
@RestController
public class Application {
	public static void main(String[] args) {
		SpringApplication.run(Application.class, args);
	}
	@GetMapping("/")
	public String hello() {
		return "Hello from $svc";
	}
}
APP
  cat << 'DOC' > "$svc/Dockerfile"
FROM eclipse-temurin:17-jdk-focal AS builder
WORKDIR /app
COPY . .
RUN ./mvnw clean package -DskipTests || mvn clean package -DskipTests
FROM eclipse-temurin:17-jre-focal
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
EXPOSE 8080
CMD ["java", "-Xmx256m", "-jar", "app.jar"]
DOC
done
