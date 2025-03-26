# Build stage
FROM ubuntu:22.04 AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    libpq-dev \
    dos2unix \
    libssl-dev \
    libcurl4-openssl-dev \
    libboost-all-dev \
    && rm -rf /var/lib/apt/lists/*

# Verify CMake version
RUN cmake --version

# Set working directory
WORKDIR /app

# Copy the entire project
COPY . .

# Debug: List contents before git operations
RUN echo "=== Contents before git operations ===" && \
    ls -la && \
    echo "=== Contents of src/dto ===" && \
    ls -la src/dto/

# Initialize git repository and update submodules with retry
RUN if [ ! -d .git ]; then \
    git init && \
    git config --global --add safe.directory /app && \
    git config --global user.email "builder@docker.com" && \
    git config --global user.name "Docker Builder" && \
    git add . && \
    git commit -m "Initial commit"; \
    fi

# Force update submodules with retry
RUN for i in {1..3}; do \
    echo "Attempt $i to update submodules..." && \
    git submodule deinit -f . && \
    git submodule update --init --recursive && break || \
    if [ $i -eq 3 ]; then exit 1; fi; \
    sleep 5; \
    done

# Debug: List contents after git operations
RUN echo "=== Contents after git operations ===" && \
    ls -la && \
    echo "=== Contents of src/dto ===" && \
    ls -la src/dto/ && \
    echo "=== Contents of external ===" && \
    ls -la external/

# Fix line endings and make build scripts executable
RUN dos2unix configure.sh build.sh run.sh && \
    chmod +x configure.sh build.sh run.sh

# Clean up any existing build artifacts and CMake cache
RUN rm -rf build/ CMakeCache.txt CMakeFiles/

# Set environment variables for build
ENV CMAKE_BUILD_TYPE=Debug
ENV OATPP_BUILD_TESTS=OFF
ENV OATPP_DISABLE_TESTS=TRUE
ENV OATPP_SWAGGER_BUILD_TESTS=OFF
ENV OATPP_POSTGRESQL_BUILD_TESTS=OFF

# Get number of available cores
RUN echo "Number of available cores: $(nproc)"

# Build oatpp first with parallel jobs
RUN mkdir -p build/oatpp && \
    cd build/oatpp && \
    cmake -DCMAKE_BUILD_TYPE=Debug \
    -DOATPP_BUILD_TESTS=OFF \
    -DOATPP_DISABLE_TESTS=TRUE \
    ../../external/oatpp && \
    make -j$(nproc) && \
    make install

# Debug: List contents before main build
RUN echo "=== Contents before main build ===" && \
    ls -la && \
    echo "=== Contents of src/dto ===" && \
    ls -la src/dto/

# Build the main project with parallel jobs
RUN mkdir -p build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=Debug \
    -DOATPP_BUILD_TESTS=OFF \
    -DOATPP_DISABLE_TESTS=TRUE \
    -DOATPP_SWAGGER_BUILD_TESTS=OFF \
    -DOATPP_POSTGRESQL_BUILD_TESTS=OFF \
    .. && \
    # Build with parallel jobs and memory constraints
    make -j$(nproc) VERBOSE=1 CXXFLAGS="-O2 -pipe -fno-omit-frame-pointer" || ( \
    echo "Build failed. Checking system resources..." && \
    free -h && \
    df -h && \
    echo "Checking build directory..." && \
    ls -la && \
    echo "Checking CMake cache..." && \
    cat CMakeCache.txt && \
    exit 1 \
    )

# Create artifacts directory and copy only necessary files
RUN mkdir -p /artifacts && \
    echo "=== Copying build artifacts ===" && \
    ls -la /app/build/ && \
    cp -r /app/build/* /artifacts/ && \
    echo "=== Copying configuration files ===" && \
    cp /app/docker-compose.yml /artifacts/ && \
    echo "=== Final artifacts contents ===" && \
    ls -la /artifacts/

# Runtime stage
FROM ubuntu:22.04

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libpq5 \
    libssl3 \
    libcurl4 \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy the built binary and necessary files from builder
COPY --from=builder /app/build/video-streaming .
COPY --from=builder /app/resources ./resources
COPY --from=builder /app/sql ./sql
COPY --from=builder /app/external/oatpp-swagger/res ./external/oatpp-swagger/res

# Expose the port the app runs on
EXPOSE 8000

# Run the application
CMD ["./video-streaming"]
