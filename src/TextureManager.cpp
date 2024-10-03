#include "TextureManager.h"

TextureManager::TextureManager()
{
    // Search for all files in the resources directory
    for (const auto &entry : std::filesystem::directory_iterator("resources"))
    {
        if (entry.is_regular_file())
        {
            std::string path = entry.path().string();
            std::string filename = entry.path().filename().replace_extension("").string();
            Image image = LoadImageSvg(path.c_str(), 450.0f, 450.0f);
            Texture2D texture = LoadTextureFromImage(image);
            this->m_Textures[filename] = texture;
            UnloadImage(image);
        }
    }
}

TextureManager::~TextureManager()
{
    for (auto &texture : this->m_Textures)
    {
        UnloadTexture(texture.second);
    }
}

void TextureManager::Initialize()
{
    if (TextureManager::s_Instance != nullptr)
    {
        throw std::runtime_error("TextureManager is already initialized");
    }

    TextureManager::s_Instance = new TextureManager();
}

TextureManager &TextureManager::GetInstance()
{
    if (TextureManager::s_Instance == nullptr)
    {
        throw std::runtime_error("TextureManager is not initialized");
    }

    return *TextureManager::s_Instance;
}

void TextureManager::Shutdown()
{
    if (TextureManager::s_Instance == nullptr)
    {
        throw std::runtime_error("TextureManager is not initialized");
    }

    delete TextureManager::s_Instance;
    TextureManager::s_Instance = nullptr;
}

Texture2D &TextureManager::GetTexture(const std::string &path)
{
    if (this->m_Textures.find(path) == this->m_Textures.end())
    {
        this->m_Textures[path] = LoadTexture(path.c_str());
    }

    return this->m_Textures[path];
}
