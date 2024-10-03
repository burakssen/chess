#pragma once

#include <unordered_map>
#include <vector>
#include <raylib.h>
#include <array>
#include "Piece.h"
#include "TextureManager.h"
#include "Move.h"

class Board
{
public:
    void Render();
    void InitializeBoard();
    void SetPosition(Vector2 pos) { m_position = pos; }
    void SetTileSize(int size) { m_tileSize = size; }
    void LoadPositionFromFen(const std::string &fen);
    void HandleInput();

private:
    int GetSquareIndexFromMousePos(Vector2 mousePos);
    void PrecomputeMoveData();
    void GenerateMoves();
    void GenerateMoves(int source, PieceType type);

    void RenderBoard();
    void RenderPieces();
    void RenderLegalMoves();
    void RenderDraggingPiece();
    void RenderPromotionMenu();

    void GeneratePawnMoves(int source);
    void GenerateKnightMoves(int source);
    void GenerateBishopMoves(int source);
    void GenerateRookMoves(int source);
    void GenerateQueenMoves(int source);
    void GenerateKingMoves(int source);

private:
    Vector2 m_position = {0, 0};
    int m_tileSize = 10;
    std::array<Piece, 64> m_pieces;
    TextureManager *m_textureManager = nullptr;

    bool m_isDragging = false;
    Vector2 m_dragStartPos = {0, 0};
    Vector2 m_dragOffset = {0, 0};
    Piece m_dragPiece;
    int m_dragSourceIndex = -1;
    int m_selectedSquare = -1;
    int m_enPassantTarget = -1;
    bool m_isPromoting = false;
    int m_promotionSource = -1;
    bool m_castlingRights[4] = {true, true, true, true};

    std::array<int, 8> m_directions = {-8, -1, 1, 8, -9, -7, 7, 9};
    std::array<std::array<int, 8>, 64> m_numSquaresToEdge;
    std::vector<Move> m_legalMoves;
    PieceColor m_colorToMove = PieceColor::COLOR_WHITE;
    PieceColor m_playerColor = PieceColor::COLOR_WHITE;
};
