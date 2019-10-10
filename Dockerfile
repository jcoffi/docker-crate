## -*- docker-image-name: "docker-crate" -*-
#
# Crate Dockerfile
# https://github.com/crate/docker-crate
#

FROM centos:7

RUN groupadd crate && useradd -u 1000 -g crate -d /crate crate

RUN curl --retry 8 -o /openjdk.tar.gz https://download.java.net/java/GA/jdk13/5b8a42f3905b406298b72d750b6919f6/33/GPL/openjdk-13_linux-x64_bin.tar.gz \
    && echo "5f547b8f0ffa7da517223f6f929a5055d749776b1878ccedbd6cc1334f4d6f4d */openjdk.tar.gz" | sha256sum -c - \
    && tar -C /opt -zxf /openjdk.tar.gz \
    && rm /openjdk.tar.gz

ENV JAVA_HOME /opt/jdk-13

# REF: https://github.com/elastic/elasticsearch-docker/issues/171
RUN ln -sf /etc/pki/ca-trust/extracted/java/cacerts /opt/jdk-13/lib/security/cacerts

# install crate
RUN yum install -y yum-utils https://centos7.iuscommunity.org/ius-release.rpm \
    && yum makecache \
    && yum install -y python36u openssl \
    && yum clean all \
    && rm -rf /var/cache/yum \
    && curl -fSL -O https://cdn.crate.io/downloads/releases/crate-4.0.6.tar.gz \
    && curl -fSL -O https://cdn.crate.io/downloads/releases/crate-4.0.6.tar.gz.asc \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 90C23FC6585BC0717F8FBFC37FAAE51A06F6EAEB \
    && gpg --batch --verify crate-4.0.6.tar.gz.asc crate-4.0.6.tar.gz \
    && rm -rf "$GNUPGHOME" crate-4.0.6.tar.gz.asc \
    && tar -xf crate-4.0.6.tar.gz -C /crate --strip-components=1 \
    && rm crate-4.0.6.tar.gz \
    && ln -sf /usr/bin/python3.6 /usr/bin/python3 \
    && ln -sf /usr/bin/python3.6 /usr/bin/python

COPY --chown=1000:0 config/crate.yml /crate/config/crate.yml
COPY --chown=1000:0 config/log4j2.properties /crate/config/log4j2.properties

# install crash
RUN curl -fSL -O https://cdn.crate.io/downloads/releases/crash_standalone_0.24.2 \
    && curl -fSL -O https://cdn.crate.io/downloads/releases/crash_standalone_0.24.2.asc \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 90C23FC6585BC0717F8FBFC37FAAE51A06F6EAEB \
    && gpg --batch --verify crash_standalone_0.24.2.asc crash_standalone_0.24.2 \
    && rm -rf "$GNUPGHOME" crash_standalone_0.24.2.asc \
    && mv crash_standalone_0.24.2 /usr/local/bin/crash \
    && chmod +x /usr/local/bin/crash

ENV PATH /crate/bin:$PATH
# Default heap size for Docker, can be overwritten by args
ENV CRATE_HEAP_SIZE 512M

RUN mkdir -p /data/data /data/log

VOLUME /data

WORKDIR /data

# http: 4200 tcp
# transport: 4300 tcp
# postgres protocol ports: 5432 tcp
EXPOSE 4200 4300 5432

# These COPY commands have been moved before the last one due to the following issues:
# https://github.com/moby/moby/issues/37965#issuecomment-448926448
# https://github.com/moby/moby/issues/38866
COPY --chown=1000:0 config/crate.yml /crate/config/crate.yml
COPY --chown=1000:0 config/log4j2.properties /crate/config/log4j2.properties

LABEL maintainer="Crate.io <office@crate.io>" \
    org.label-schema.schema-version="1.0" \
    org.label-schema.build-date="2019-10-03T11:40:28.456950" \
    org.label-schema.name="crate" \
    org.label-schema.description="CrateDB is a distributed SQL database handles massive amounts of machine data in real-time." \
    org.label-schema.url="https://crate.io/products/cratedb/" \
    org.label-schema.vcs-url="https://github.com/crate/docker-crate" \
    org.label-schema.vendor="Crate.io" \
    org.label-schema.version="4.0.6"

COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["crate"]
