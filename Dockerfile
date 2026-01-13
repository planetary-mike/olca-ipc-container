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

# Install libgfortran which is required by OpenBLAS
# libgfortran4 for older OpenBLAS builds, libgfortran5 for newer
RUN apt-get update && \
    apt-get install -y --no-install-recommends libgfortran5 && \
    rm -rf /var/lib/apt/lists/* && \
    # Create symlink for libgfortran.so.4 if only libgfortran.so.5 exists
    if [ -f /usr/lib/x86_64-linux-gnu/libgfortran.so.5 ] && [ ! -f /usr/lib/x86_64-linux-gnu/libgfortran.so.4 ]; then \
        ln -s /usr/lib/x86_64-linux-gnu/libgfortran.so.5 /usr/lib/x86_64-linux-gnu/libgfortran.so.4; \
    fi

COPY --from=mvn /olca-ipc/target/lib /app/lib
COPY --from=native-downloader /app/native /app/native
COPY run.sh /app
RUN chmod +x /app/run.sh

# Verify native libraries can load
RUN echo "Final native lib check:" && ls -la /app/native/ && \
    echo "Checking library dependencies:" && \
    ldd /app/native/libopenblas64_.so || echo "ldd check complete"

ENTRYPOINT ["/app/run.sh"]
