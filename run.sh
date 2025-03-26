#!/bin/bash

# Set the swagger resources path
export OATPP_SWAGGER_RES_PATH="$(pwd)/external/oatpp-swagger/res"

# Change to build directory and run the application
cd build && ./Debug/video-streaming