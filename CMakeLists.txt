cmake_minimum_required(VERSION 3.30)

project(chess)

set(CMAKE_CXX_STANDARD 23)

add_subdirectory(vendor/raylib)

file(GLOB_RECURSE SOURCES "src/*.cpp")

# Add a custom target to run the script before building the executable
if (UNIX)
    add_custom_command(
        OUTPUT ${CMAKE_BINARY_DIR}/svg_support_unix
        COMMAND sh svg_support.sh vendor/raylib/src/config.h
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Running svg_support.sh for UNIX"
        VERBATIM
    )
    add_custom_target(run_svg_support ALL DEPENDS ${CMAKE_BINARY_DIR}/svg_support_unix)
elseif(WIN32)
    add_custom_command(
        OUTPUT ${CMAKE_BINARY_DIR}/svg_support_win
        COMMAND cmd /c svg_support.bat vendor/raylib/src/config.h
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Running svg_support.bat for Windows"
        VERBATIM
    )
    add_custom_target(run_svg_support ALL DEPENDS ${CMAKE_BINARY_DIR}/svg_support_win)
endif()

add_executable(chess ${SOURCES})

# Ensure the custom target runs before building the executable
add_dependencies(chess run_svg_support)

target_include_directories(chess PRIVATE src vendor/raylib/src)

target_link_libraries(chess raylib)

# Copy resources to the build directory
file(COPY resources DESTINATION ${CMAKE_BINARY_DIR})
