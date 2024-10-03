#pragma once

#include <string>

#include <raylib.h>

#include "Board.h"
#include "TextureManager.h"

class Chess
{
private:
    Chess();
    ~Chess();

public:
    static void Initialize();
    static Chess &GetInstance();
    static void Shutdown();

    void Run();

private:
    void HandleInput();
    void Update();
    void Render();

private:
    inline static Chess *s_Instance = nullptr;

    std::string m_title = "Chess";
    Vector2 m_size = {1280, 880};

    Board m_board;
};