#pragma once

#include <string>
#include <unordered_map>
#include <filesystem>

#include <raylib.h>

class TextureManager
{
private:
    TextureManager();
    ~TextureManager();

public:
    static void Initialize();
    static TextureManager &GetInstance();
    static void Shutdown();

    Texture2D &GetTexture(const std::string &path);

private:
    inline static TextureManager *s_Instance = nullptr;
    std::unordered_map<std::string, Texture2D> m_Textures;
};