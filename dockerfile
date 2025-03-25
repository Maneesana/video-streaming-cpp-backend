# Build stage
FROM ubuntu:22.04 AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    libpq-dev \
    dos2unix \
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

# Initialize git repository and update submodules
RUN if [ ! -d .git ]; then \
    git init && \
    git config --global --add safe.directory /app && \
    git config --global user.email "builder@docker.com" && \
    git config --global user.name "Docker Builder" && \
    git add . && \
    git commit -m "Initial commit"; \
    fi

# Force update submodules
RUN git submodule deinit -f . && \
    git submodule update --init --recursive

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

# Build oatpp first
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

# Build the main project
RUN mkdir -p build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=Debug \
    -DOATPP_BUILD_TESTS=OFF \
    -DOATPP_DISABLE_TESTS=TRUE \
    -DOATPP_SWAGGER_BUILD_TESTS=OFF \
    -DOATPP_POSTGRESQL_BUILD_TESTS=OFF \
    .. && \
    make -j$(nproc)

# Runtime stage
FROM ubuntu:22.04

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libpq5 \
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
