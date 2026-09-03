# ============================================================================
# Zero Count game-server — production-style image (E4.1).
#
# Multi-stage: Maven build → slim JRE runtime, non-root user, healthcheck.
# Build context is the backend/ PARENT (multi-module Maven build):
#   docker build -f backend/Dockerfile .
# ============================================================================

# ---- stage 1: build ----
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /src

# Cache dependencies before copying sources (faster rebuilds).
COPY backend/pom.xml backend/pom.xml
COPY backend/game-engine/pom.xml backend/game-engine/pom.xml
COPY backend/game-server/pom.xml backend/game-server/pom.xml
RUN mvn -q -f backend/pom.xml -pl game-server -am dependency:go-offline

COPY backend/game-engine/src backend/game-engine/src
COPY backend/game-server/src backend/game-server/src
RUN mvn -q -f backend/pom.xml -pl game-server -am package -DskipTests

# ---- stage 2: runtime ----
FROM eclipse-temurin:17-jre
WORKDIR /app

# Non-root (standards §3: least privilege).
RUN groupadd -r zerocount && useradd -r -g zerocount zerocount
USER zerocount

COPY --from=build /src/backend/game-server/target/game-server-*.jar app.jar

EXPOSE 8080

# Liveness via Spring Actuator (wget ships in the temurin base image).
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
  CMD wget -qO- http://localhost:8080/actuator/health | grep -q '"status":"UP"' || exit 1

# All config via env (see application.yml): DB_URL, DB_USER, DB_PASSWORD,
# JWT_SECRET, AUTH_PROVIDER, FIREBASE_PROJECT_ID, ROOMS_STORE, REDIS_URL, ...
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "app.jar"]
