# Multi-stage build pour optimiser la taille de l'image
FROM openjdk:17-jdk-slim as builder

# Installer Maven
RUN apt-get update && apt-get install -y maven

# Définir le répertoire de travail
WORKDIR /app

# Copier les fichiers de configuration Maven
COPY pom.xml .
COPY mvnw .
COPY .mvn .mvn

# Télécharger les dépendances (optimisation des couches Docker)
RUN mvn dependency:go-offline -B

# Copier le code source
COPY src ./src

# Construire l'application
RUN mvn clean package -DskipTests

# Image finale légère
FROM openjdk:17-jre-slim

# Métadonnées
LABEL maintainer="GESCOM Team"
LABEL description="Application de gestion commerciale GESCOM"
LABEL version="1.0"

# Créer un utilisateur non-root pour la sécurité
RUN useradd -r -s /bin/false -m gescom

# Installer des packages utiles et nettoyer
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Définir le répertoire de travail
WORKDIR /app

# Copier le JAR depuis l'étape de build
COPY --from=builder /app/target/*.jar app.jar

# Changer le propriétaire du fichier
RUN chown gescom:gescom app.jar

# Basculer vers l'utilisateur non-root
USER gescom

# Exposer le port
EXPOSE 8080

# Variables d'environnement par défaut
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"
ENV SPRING_PROFILES_ACTIVE=docker

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

# Point d'entrée
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]