#include "Chess.h"

Chess::Chess()
{
    InitWindow(this->m_size.x, this->m_size.y, this->m_title.c_str());
    SetTargetFPS(60);

    TextureManager::Initialize();

    this->m_board.SetPosition({40, 40});
    this->m_board.SetTileSize(100);
    this->m_board.InitializeBoard();
}

Chess::~Chess()
{
    TextureManager::Shutdown();
    CloseWindow();
}

void Chess::Initialize()
{
    if (Chess::s_Instance != nullptr)
    {
        throw std::runtime_error("Chess is already initialized");
    }

    Chess::s_Instance = new Chess();
}

Chess &Chess::GetInstance()
{
    if (Chess::s_Instance == nullptr)
    {
        throw std::runtime_error("Chess is not initialized");
    }

    return *Chess::s_Instance;
}

void Chess::Shutdown()
{
    if (Chess::s_Instance == nullptr)
    {
        throw std::runtime_error("Chess is not initialized");
    }

    delete Chess::s_Instance;
    Chess::s_Instance = nullptr;
}

void Chess::Run()
{
    while (!WindowShouldClose())
    {
        this->HandleInput();
        this->Update();
        this->Render();
    }
}

void Chess::HandleInput()
{
    if (IsKeyPressed(KEY_SPACE))
    {
        this->m_board.LoadPositionFromFen("1nbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");
    }

    this->m_board.HandleInput();
}

void Chess::Update()
{
}

void Chess::Render()
{
    BeginDrawing();
    ClearBackground({34, 34, 34, 255});
    this->m_board.Render();

    // Draw Score Board
    DrawRectangleRounded({880, 40, 365, 800}, 0.05f, 10, {50, 50, 50, 255});

    DrawText("Score Board", 900, 50, 30, WHITE);

    DrawText("White", 900, 100, 20, WHITE);
    DrawText("Black", 900, 200, 20, WHITE);

    // Draw Moves
    DrawRectangleRounded({895, 325, 335, 500}, 0.05f, 10, {30, 30, 30, 255});

    DrawText("Moves", 910, 335, 30, WHITE);

    EndDrawing();
}