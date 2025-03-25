cmake_minimum_required(VERSION 3.20)

project(video-streaming)

set(CMAKE_CXX_STANDARD 17)
# # Force Release mode
# if(NOT CMAKE_BUILD_TYPE)
#     set(CMAKE_BUILD_TYPE Release CACHE STRING "Choose Release or Debug" FORCE)
# endif()

# # Set the same runtime for all libraries
# set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

# Ensure Oat++ and its modules use the same mode
set(OATPP_BUILD_TESTS OFF CACHE BOOL "Disable Oat++ tests" FORCE)

# Disable tests in Oat++ libraries to avoid conflicts
set(OATPP_BUILD_TESTS OFF CACHE BOOL "Disable Oat++ tests" FORCE)
set(OATPP_DISABLE_TESTS TRUE CACHE BOOL "Disable Oat++ tests" FORCE)
set(OATPP_SWAGGER_BUILD_TESTS OFF CACHE BOOL "Disable Oat++ Swagger tests" FORCE)
set(OATPP_POSTGRESQL_BUILD_TESTS OFF CACHE BOOL "Disable Oat++ PostgreSQL tests" FORCE)

# Ensure Oat++ is found correctly
add_subdirectory(external/oatpp)
add_subdirectory(external/oatpp-swagger EXCLUDE_FROM_ALL)
add_subdirectory(external/oatpp-postgresql EXCLUDE_FROM_ALL)

# DOWNLOAD ALL SUBMODULES
find_package(Git QUIET)
if(!GIT_FOUND AND EXISTS "${PROJECT_SOURCE_DIR}/.git")
    message(FATAL_ERROR "Git not found, but this project is a git repository. Git is required to download submodules.")
endif()

if(GIT_FOUND AND EXISTS "${PROJECT_SOURCE_DIR}/.git")
# Update submodules as needed
    option(GIT_SUBMODULE "Check submodules during build" ON)
    if(GIT_SUBMODULE)
        message(STATUS "Updating git submodules")
        execute_process(COMMAND ${GIT_EXECUTABLE} submodule update --init --recursive
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
            RESULT_VARIABLE GIT_SUBMOD_RESULT)
        if(NOT GIT_SUBMOD_RESULT EQUAL "0")
            message(FATAL_ERROR "git submodule update --init failed with ${GIT_SUBMOD_RESULT}, please checkout submodules")
        endif()
    endif()
endif()

# Check all the submodules
if(NOT EXISTS "${PROJECT_SOURCE_DIR}/external/oatpp/CMakeLists.txt")
    message(FATAL_ERROR "The submodules were not downloaded! GIT_SUBMODULE was turned off or failed. Please update submodules and try again.")
endif()

# Create a static library for the main project
add_library(${PROJECT_NAME}-lib STATIC 
    src/controller/MyController.cpp
    src/controller/MyController.hpp    
    src/AppComponent.hpp
    src/dto/dtos.hpp
    src/SwaggerComponent.hpp
)

# Include Oat++ headers properly
target_include_directories(${PROJECT_NAME}-lib PUBLIC 
    src
    external/oatpp/src  # oatpp headers   
    external/oatpp-swagger/src  # oatpp-swagger headers
    external/oatpp-postgresql/src  # oatpp-postgresql headers
    ${CMAKE_BINARY_DIR}  # Include generated headers
)
add_definitions(
        # Path to swagger-ui resources #
        -DOATPP_SWAGGER_RES_PATH="${PROJECT_SOURCE_DIR}/external/oatpp-swagger/res"

        # Path to config file #
        -DCONFIG_PATH="${PROJECT_SOURCE_DIR}/resources/config.json"

        ## Path to database migration scripts
        -DDATABASE_MIGRATIONS="${PROJECT_SOURCE_DIR}/sql"
)

# Ensure Oat++ is properly linked
target_link_libraries(${PROJECT_NAME}-lib 
    PUBLIC oatpp 
    PUBLIC oatpp-test
    PUBLIC oatpp-swagger 
    PUBLIC oatpp-postgresql
)

# Create the main executable
add_executable(${PROJECT_NAME} src/App.cpp)

# Link the library to the main executable
target_link_libraries(${PROJECT_NAME} PRIVATE ${PROJECT_NAME}-lib)
