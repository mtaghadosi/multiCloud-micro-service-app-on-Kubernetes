FROM openjdk:11-jre-slim
# Creating a non-root user (security best practice)
RUN adduser --system --group java-microservice
WORKDIR /app
COPY java-webserver.jar /app/
USER java-microservice
EXPOSE 8080
CMD ["java", "-jar", "java-webserver.jar"]