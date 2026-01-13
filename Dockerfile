# collect Maven dependencies
FROM --platform=$BUILDPLATFORM maven:3.9.12-eclipse-temurin-21 AS mvn
WORKDIR /olca-ipc
COPY pom.xml .
RUN mvn package

# Native libraries stage - FORCE AMD64 since no ARM64 libs exist
FROM --platform=linux/amd64 eclipse-temurin:21-jre AS native-downloader
WORKDIR /tmp

# Download x64 native libraries (only platform available)
RUN apt-get update && apt-get install -y curl unzip && \
    mkdir -p /app/native && \
    echo "Downloading x64 native libraries..." && \
    curl -fSL -o native.zip "https://github.com/GreenDelta/olca-native/releases/download/v0.0.1/olca-native-blas-linux-x64.zip" && \
    unzip native.zip -d /tmp/extracted && \
    find /tmp/extracted -name "*.so" -exec cp {} /app/native/ \; && \
    rm -rf native.zip /tmp/extracted && \
    echo "Native library contents:" && ls -la /app/native/

# Final image - FORCE AMD64
FROM --platform=linux/amd64 eclipse-temurin:21-jre
WORKDIR /app

# Install libgfortran4 which is required by OpenBLAS (compiled with GCC 7)
# Ubuntu 22.04 (jammy) doesn't have libgfortran4, need to get from Ubuntu 20.04 (focal)
RUN apt-get update && \
    apt-get install -y --no-install-recommends software-properties-common && \
    echo "deb http://archive.ubuntu.com/ubuntu focal main universe" > /etc/apt/sources.list.d/focal.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends libgfortran4 && \
    rm /etc/apt/sources.list.d/focal.list && \
    apt-get update && \
    rm -rf /var/lib/apt/lists/* && \
    echo "Installed libgfortran4:" && ldconfig -p | grep gfortran

COPY --from=mvn /olca-ipc/target/lib /app/lib
COPY --from=native-downloader /app/native /app/native
COPY run.sh /app
RUN chmod +x /app/run.sh

# Verify native libraries can load
RUN echo "=== Final native lib check ===" && ls -la /app/native/ && \
    echo "=== Checking library dependencies ===" && \
    ldd /app/native/libopenblas64_.so && \
    echo "=== All dependencies satisfied ===" || echo "WARNING: Some dependencies missing"

ENTRYPOINT ["/app/run.sh"]
