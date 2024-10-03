#pragma once

#include <cstdint>

#include <raylib.h>

enum class PieceType : uint8_t
{
    NONE = 0b000,
    KING = 0b001,
    PAWN = 0b010,
    KNIGHT = 0b011,
    BISHOP = 0b100,
    ROOK = 0b101,
    QUEEN = 0b110
};

enum class PieceColor : uint8_t
{
    COLOR_WHITE = 0b0000,
    COLOR_BLACK = 0b1000
};

class Piece
{
public:
    Piece() = default;
    Piece(PieceType type, PieceColor color) : m_data(static_cast<uint8_t>(type) | static_cast<uint8_t>(color))
    {
    }

    PieceType GetType() const { return static_cast<PieceType>(this->m_data & 0b0111); }
    PieceColor GetColor() const { return static_cast<PieceColor>(this->m_data & 0b1000); }

    uint8_t GetData() const { return this->m_data; }

private:
    Vector2 m_position = {0, 0};
    uint8_t m_data = 0b0000;
};