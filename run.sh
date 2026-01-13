#!/bin/bash

# Use JAVA_MAX_RAM_PERCENTAGE if set, otherwise default to 70%
# This allows docker-compose to control memory via mem_limit
MAX_RAM_PERCENTAGE=${JAVA_MAX_RAM_PERCENTAGE:-70}

# Use OLCA_TIMEOUT if set, otherwise default to 600 seconds (10 min for large matrices)
TIMEOUT=${OLCA_TIMEOUT:-600}

# Check if native libraries exist
if [ -d "/app/native" ] && [ "$(ls -A /app/native 2>/dev/null)" ]; then
    echo "Native libraries found in /app/native:"
    ls -la /app/native/
    NATIVE_FLAG="-native /app/native"
else
    echo "WARNING: No native libraries found in /app/native - calculations may fail!"
    NATIVE_FLAG=""
fi

echo "Starting OpenLCA IPC Server..."
echo "  Max RAM Percentage: ${MAX_RAM_PERCENTAGE}%"
echo "  Calculation Timeout: ${TIMEOUT}s"
echo "  Native libraries: ${NATIVE_FLAG:-none}"
echo "  Arguments: $@"

exec java \
    -XX:+UseContainerSupport \
    -XX:MaxRAMPercentage=${MAX_RAM_PERCENTAGE} \
    -XX:+ExitOnOutOfMemoryError \
    -Djava.library.path=/app/native \
    -cp "/app/lib/*" \
    org.openlca.ipc.Server \
    -timeout ${TIMEOUT} \
    ${NATIVE_FLAG} \
    -data /app/data \
    "$@"
