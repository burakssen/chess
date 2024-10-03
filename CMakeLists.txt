cmake_minimum_required(VERSION 3.30)

project(chess)

set(CMAKE_CXX_STANDARD 23)

add_subdirectory(vendor/raylib)

file(GLOB_RECURSE SOURCES "src/*.cpp")

add_executable(chess ${SOURCES})

target_include_directories(chess PRIVATE src vendor/raylib/src)

target_link_libraries(chess raylib)

file(COPY resources DESTINATION ${CMAKE_BINARY_DIR})