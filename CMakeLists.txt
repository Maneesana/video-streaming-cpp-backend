cmake_minimum_required(VERSION 3.20)

project(video-streaming)

set(CMAKE_CXX_STANDARD 17)

# Ensure Oat++ is found correctly
add_subdirectory(external/oatpp)
add_subdirectory(external/oatpp-swagger)
add_subdirectory(external/oatpp-postgresql)

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
    src/dto/Dtos.hpp
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
        -DOATPP_SWAGGER_RES_PATH="${CMAKE_CURRENT_SOURCE_DIR}/external/oatpp-swagger/res"

        # Path to config file #
        -DCONFIG_PATH="${CMAKE_CURRENT_LIST_DIR}/resources/config.json"

        ## Path to database migration scripts
        -DDATABASE_MIGRATIONS="${CMAKE_CURRENT_SOURCE_DIR}/sql"
)

# Ensure Oat++ is properly linked
target_link_libraries(${PROJECT_NAME}-lib PRIVATE oatpp oatpp-swagger oatpp-postgresql)

# Create the main executable
add_executable(${PROJECT_NAME} src/App.cpp)

# Link the library to the main executable
target_link_libraries(${PROJECT_NAME} PRIVATE ${PROJECT_NAME}-lib)
