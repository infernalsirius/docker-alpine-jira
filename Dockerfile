FROM openjdk:8u121-alpine
MAINTAINER LasLabs Inc <support@laslabs.com>

ARG JIRA_VERSION=7.4.2
ARG JIRA_HOME=/var/atlassian/jira
ARG JIRA_INSTALL=/opt/atlassian/jira
ARG RUN_USER=jira
ARG RUN_GROUP=jira
ARG JIRA_DOWNLOAD_URI=https://www.atlassian.com/software/jira/downloads/binary/atlassian-jira-core-${JIRA_VERSION}.tar.gz
ARG POSTGRES_DRIVER_VERSION=42.1.1

ENV LC_ALL=C

# Setup Jira User & Group
RUN addgroup -S "${RUN_GROUP}" \
    && adduser -S -s /bin/false -G "${RUN_GROUP}" "${RUN_USER}" \
# Install build deps
    && apk add --no-cache --virtual .build-deps \
        curl \
        tar \
# Install required binaries
    && apk add --no-cache \
        bash \
        fontconfig \
        ttf-dejavu \
# Create home, install, and conf dirs
    && mkdir -p "${JIRA_HOME}" \
            "${JIRA_HOME}/caches/index" \
             "${JIRA_INSTALL}/conf/Catalina" \
# Download assets and extract to appropriate locations
    && curl -Ls "${JIRA_DOWNLOAD_URI}" \
        | tar -xz --directory "${JIRA_INSTALL}" \
            --strip-components=1 --no-same-owner \
# Update the Postgres library to allow non-archaic Postgres versions
    && cd "${JIRA_INSTALL}/lib" \
    && rm -f "${JIRA_INSTALL}/lib/postgresql-9.1-903.jdbc4-atlassian-hosted.jar" \
    && curl -Os "https://jdbc.postgresql.org/download/postgresql-${POSTGRES_DRIVER_VERSION}.jar" \
# Add MySQL driver
    && curl -Ls "https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.38.tar.gz" \
       | tar -xz --directory "${JIRA_INSTALL}/lib" --strip-components=1 --no-same-owner "mysql-connector-java-5.1.38/mysql-connector-java-5.1.38-bin.jar" \
# Setup permissions
    && chmod -R 700 "${JIRA_HOME}" \
                    "${JIRA_INSTALL}/conf" \
                    "${JIRA_INSTALL}/temp" \
                    "${JIRA_INSTALL}/logs" \
                    "${JIRA_INSTALL}/work" \
    && chown -R ${RUN_USER}:${RUN_GROUP} "${JIRA_HOME}" \
                                         "${JIRA_INSTALL}/conf" \
                                         "${JIRA_INSTALL}/temp" \
                                         "${JIRA_INSTALL}/logs" \
                                         "${JIRA_INSTALL}/work" \
# Update configs
    && sed --in-place "s/java version/openjdk version/g" "${JIRA_INSTALL}/bin/check-java.sh" \
    && echo -e "\njira.home=${JIRA_HOME}" >> "${JIRA_INSTALL}/atlassian-jira/WEB-INF/classes/jira-application.properties" \
    && touch -d "@0" "${JIRA_INSTALL}/conf/server.xml" \
# Remove build dependencies
    && apk del .build-deps

# Switch from root
USER "${RUN_USER}":"${RUN_GROUP}"

# Expose ports
EXPOSE 8080

# Persist the log and home dirs + JRE security folder (cacerts)
VOLUME ["${JIRA_INSTALL}/logs", "${JIRA_INSTALL}/conf", "${JIRA_HOME}", "${JAVA_HOME}/jre/lib/security/"]

# Set working directory to install directory
WORKDIR "${JIRA_INSTALL}"

# Run in foreground
CMD ["./bin/catalina.sh", "run"]

# Copy & set entrypoint for manual access
COPY ./docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]

# Metadata
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION
LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="JIRA - Alpine" \
      org.label-schema.description="Provides a Docker image for JIRA on Alpine Linux." \
      org.label-schema.url="https://laslabs.com/" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/LasLabs/docker-alpine-jira" \
      org.label-schema.vendor="LasLabs Inc." \
      org.label-schema.version=$VERSION \
      org.label-schema.schema-version="1.0"
