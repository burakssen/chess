#include "Board.h"
#include <iostream>
#include <bitset>

void Board::Render()
{

    RenderBoard();

    // Render highlight for the selected square
    if (m_selectedSquare != -1)
    {
        int file = m_selectedSquare % 8;
        int rank = m_selectedSquare / 8;
        DrawRectangle(m_position.x + file * m_tileSize, m_position.y + rank * m_tileSize, m_tileSize, m_tileSize, ColorAlpha(ORANGE, 0.5f));
    }

    RenderPieces();
    RenderLegalMoves();
    if (m_isDragging)
    {
        RenderDraggingPiece();
    }

    if (m_isPromoting)
    {
        RenderPromotionMenu();
    }
}

void Board::RenderBoard()
{
    for (int file = 0; file < 8; file++)
    {
        for (int rank = 0; rank < 8; rank++)
        {
            bool isWhite = (file + rank) % 2 != 0;
            Color color = isWhite ? Color{241, 217, 192, 255} : Color{166, 134, 100, 255};
            DrawRectangle(m_position.x + file * m_tileSize, m_position.y + rank * m_tileSize, m_tileSize, m_tileSize, color);
        }
    }
}

void Board::RenderPieces()
{
    for (int file = 0; file < 8; file++)
    {
        for (int rank = 0; rank < 8; rank++)
        {
            uint8_t pieceData = m_pieces[file + rank * 8].GetData();
            if (pieceData != 0b0000)
            {
                std::string pieceName = std::bitset<4>(pieceData).to_string();
                Texture2D texture = m_textureManager->GetTexture(pieceName);
                Rectangle sourceRec = {0, 0, (float)texture.width, (float)texture.height};
                Rectangle destRec = {m_position.x + file * m_tileSize, m_position.y + rank * m_tileSize, (float)m_tileSize, (float)m_tileSize};
                DrawTexturePro(texture, sourceRec, destRec, Vector2{0, 0}, 0.0f, WHITE);
            }
        }
    }
}

void Board::RenderLegalMoves()
{
    if (!m_legalMoves.empty())
    {
        for (const Move &move : m_legalMoves)
        {
            if (move.source == m_selectedSquare)
            {
                int file = move.target % 8;
                int rank = move.target / 8;
                Color color = m_pieces[move.target].GetData() != 0b0000 ? RED : BLUE;
                if (move.isEnPassant)
                    color = RED;
                DrawRectangle(m_position.x + file * m_tileSize, m_position.y + rank * m_tileSize, m_tileSize, m_tileSize, ColorAlpha(color, 0.5f));
            }
        }
    }
}

void Board::RenderDraggingPiece()
{
    std::string pieceName = std::bitset<4>(m_dragPiece.GetData()).to_string();
    Texture2D texture = m_textureManager->GetTexture(pieceName);
    Rectangle sourceRec = {0, 0, (float)texture.width, (float)texture.height};
    Rectangle destRec = {(float)GetMouseX() - m_tileSize / 2.0f, (float)GetMouseY() - m_tileSize / 2.0f, (float)m_tileSize, (float)m_tileSize};
    DrawTexturePro(texture, sourceRec, destRec, Vector2{0, 0}, 0.0f, WHITE);
}

void Board::RenderPromotionMenu()
{
    if (m_isPromoting)
    {
        DrawRectangleRounded({(GetScreenWidth() - 400.0f) / 2.0f - 300.0f, GetScreenHeight() / 2.0f - 200.0f, 600, 400}, 0.1f, 20, Color{255, 255, 255, 200});
        DrawText("Promote your pawn", (GetScreenWidth() - 400.0f) / 2 - 250.0f, GetScreenHeight() / 2 - 150.0f, 20, BLACK);

        std::array<uint8_t, 4> promotionPieces;
        promotionPieces[0] = static_cast<uint8_t>(this->m_playerColor) | static_cast<uint8_t>(PieceType::QUEEN);
        promotionPieces[1] = static_cast<uint8_t>(this->m_playerColor) | static_cast<uint8_t>(PieceType::ROOK);
        promotionPieces[2] = static_cast<uint8_t>(this->m_playerColor) | static_cast<uint8_t>(PieceType::BISHOP);
        promotionPieces[3] = static_cast<uint8_t>(this->m_playerColor) | static_cast<uint8_t>(PieceType::KNIGHT);

        for (int i = 0; i < 4; i++)
        {
            std::string pieceName = std::bitset<4>(promotionPieces[i]).to_string();
            Texture2D texture = m_textureManager->GetTexture(pieceName);
            Rectangle sourceRec = {0, 0, (float)texture.width, (float)texture.height};
            Rectangle destRec = {(GetScreenWidth() - 400.0f) / 2.0f + i * 100.0f, GetScreenHeight() / 2.0f, 100, 100};
            destRec.x += (100 - m_tileSize) / 2.0f - 200;
            destRec.y += (100 - m_tileSize) / 2.0f - 50;
            // Add hover effect
            if (CheckCollisionPointRec(GetMousePosition(), destRec))
            {
                DrawRectangleRec(destRec, ColorAlpha(RED, 0.5f));
                if (IsMouseButtonPressed(MOUSE_LEFT_BUTTON))
                {
                    // Promote the pawn
                    this->m_pieces[m_promotionSource] = Piece(static_cast<PieceType>(promotionPieces[i] & 0b1111), static_cast<PieceColor>(promotionPieces[i] & 0b1000));
                    m_isPromoting = false;
                    this->GenerateMoves();
                }
            }

            DrawTexturePro(texture, sourceRec, destRec, Vector2{0, 0}, 0.0f, WHITE);
        }
    }
}

void Board::InitializeBoard()
{
    this->m_legalMoves.reserve(512);
    this->m_textureManager = &TextureManager::GetInstance();

    this->m_pieces.fill(Piece(PieceType::NONE, PieceColor::COLOR_WHITE));

    for (int i = 0; i < 8; i++)
    {
        this->m_pieces[i + 48] = Piece(PieceType::PAWN, PieceColor::COLOR_WHITE);
        this->m_pieces[i + 8] = Piece(PieceType::PAWN, PieceColor::COLOR_BLACK);
    }

    this->m_pieces[56] = Piece(PieceType::ROOK, PieceColor::COLOR_WHITE);
    this->m_pieces[57] = Piece(PieceType::KNIGHT, PieceColor::COLOR_WHITE);
    this->m_pieces[58] = Piece(PieceType::BISHOP, PieceColor::COLOR_WHITE);
    this->m_pieces[59] = Piece(PieceType::QUEEN, PieceColor::COLOR_WHITE);
    this->m_pieces[60] = Piece(PieceType::KING, PieceColor::COLOR_WHITE);
    this->m_pieces[61] = Piece(PieceType::BISHOP, PieceColor::COLOR_WHITE);
    this->m_pieces[62] = Piece(PieceType::KNIGHT, PieceColor::COLOR_WHITE);
    this->m_pieces[63] = Piece(PieceType::ROOK, PieceColor::COLOR_WHITE);

    this->m_pieces[0] = Piece(PieceType::ROOK, PieceColor::COLOR_BLACK);
    this->m_pieces[1] = Piece(PieceType::KNIGHT, PieceColor::COLOR_BLACK);
    this->m_pieces[2] = Piece(PieceType::BISHOP, PieceColor::COLOR_BLACK);
    this->m_pieces[3] = Piece(PieceType::QUEEN, PieceColor::COLOR_BLACK);
    this->m_pieces[4] = Piece(PieceType::KING, PieceColor::COLOR_BLACK);
    this->m_pieces[5] = Piece(PieceType::BISHOP, PieceColor::COLOR_BLACK);
    this->m_pieces[6] = Piece(PieceType::KNIGHT, PieceColor::COLOR_BLACK);
    this->m_pieces[7] = Piece(PieceType::ROOK, PieceColor::COLOR_BLACK);

    this->PrecomputeMoveData();
    this->GenerateMoves();
}

void Board::LoadPositionFromFen(const std::string &fen)
{
    this->m_pieces.fill(Piece(PieceType::NONE, PieceColor::COLOR_WHITE));
    std::unordered_map<char, PieceType> pieceTypeSymbol = {
        {'p', PieceType::PAWN},
        {'n', PieceType::KNIGHT},
        {'b', PieceType::BISHOP},
        {'r', PieceType::ROOK},
        {'q', PieceType::QUEEN},
        {'k', PieceType::KING}};

    std::string fenBoard = fen.substr(0, fen.find(' '));
    size_t rank = 7;
    size_t file = 0;

    for (char c : fenBoard)
    {
        if (c == '/')
        {
            rank--;
            file = 0;
        }
        else if (isdigit(c))
        {
            file += c - '0';
        }
        else
        {
            PieceType type = pieceTypeSymbol[tolower(c)];
            PieceColor color = isupper(c) ? PieceColor::COLOR_WHITE : PieceColor::COLOR_BLACK;
            this->m_pieces[file + rank * 8] = Piece(type, color);
            file++;
        }
    }

    this->GenerateMoves();
}

void Board::HandleInput()
{
    if (m_isPromoting)
    {
        return;
    }

    Vector2 mousePos = GetMousePosition();

    if (IsMouseButtonPressed(MOUSE_LEFT_BUTTON))
    {
        int index = GetSquareIndexFromMousePos(mousePos);
        if (index >= 0 && index < 64 && this->m_pieces[index].GetData() != 0b0000)
        {
            m_isDragging = true;
            m_dragStartPos = mousePos;
            m_dragPiece = this->m_pieces[index];
            m_dragSourceIndex = index;
            m_selectedSquare = index;
            // Remove the piece from its original position
            this->m_pieces[index] = Piece(PieceType::NONE, PieceColor::COLOR_WHITE);
        }
    }
    else if (IsMouseButtonReleased(MOUSE_LEFT_BUTTON) && m_isDragging)
    {
        int targetIndex = GetSquareIndexFromMousePos(mousePos);
        if (targetIndex >= 0 && targetIndex < 64 && targetIndex != m_dragSourceIndex)
        {
            // Check if the move is legal
            bool isLegalMove = false;
            for (const Move &move : m_legalMoves)
            {
                if (move.source == m_dragSourceIndex && move.target == targetIndex)
                {
                    isLegalMove = true;
                    break;
                }
            }

            if (isLegalMove)
            {
                this->m_pieces[targetIndex] = m_dragPiece;

                // set castling rights
                if (m_dragPiece.GetType() == PieceType::KING)
                {
                    if (m_dragPiece.GetColor() == PieceColor::COLOR_WHITE)
                    {
                        m_castlingRights[0] = false;
                        m_castlingRights[1] = false;
                    }
                    else
                    {
                        m_castlingRights[2] = false;
                        m_castlingRights[3] = false;
                    }
                }
                else if (m_dragPiece.GetType() == PieceType::ROOK)
                {
                    if (m_dragPiece.GetColor() == PieceColor::COLOR_WHITE)
                    {
                        if (m_dragSourceIndex == 63)
                        {
                            m_castlingRights[1] = false;
                        }
                        else if (m_dragSourceIndex == 56)
                        {
                            m_castlingRights[0] = false;
                        }
                    }
                    else
                    {
                        if (m_dragSourceIndex == 7)
                        {
                            m_castlingRights[3] = false;
                        }
                        else if (m_dragSourceIndex == 0)
                        {
                            m_castlingRights[2] = false;
                        }
                    }
                }

                // Promotion
                if (m_dragPiece.GetType() == PieceType::PAWN && (targetIndex < 8 || targetIndex >= 56))
                {
                    m_isPromoting = true;
                    m_promotionSource = targetIndex;
                }

                // If en passant capture, remove the captured pawn
                if (m_dragPiece.GetType() == PieceType::PAWN && m_enPassantTarget == targetIndex)
                {
                    int enPassantPawnIndex = targetIndex + (m_dragPiece.GetColor() == PieceColor::COLOR_WHITE ? 8 : -8);
                    this->m_pieces[enPassantPawnIndex] = Piece(PieceType::NONE, PieceColor::COLOR_WHITE);
                }
                // Handle En Passant setup
                if (m_dragPiece.GetType() == PieceType::PAWN && abs(m_dragSourceIndex - targetIndex) == 16)
                    m_enPassantTarget = (m_dragSourceIndex + targetIndex) / 2; // The square passed over
                else
                    m_enPassantTarget = -1; // Reset if not a two-square pawn move

                // Handle castling
                if (m_dragPiece.GetType() == PieceType::KING && abs(m_dragSourceIndex - targetIndex) == 2)
                {
                    if (targetIndex == 62) // White king-side castling
                    {
                        this->m_pieces[61] = this->m_pieces[63];
                        this->m_pieces[63] = Piece(PieceType::NONE, PieceColor::COLOR_WHITE);
                    }
                    else if (targetIndex == 58) // White queen-side castling
                    {
                        this->m_pieces[59] = this->m_pieces[56];
                        this->m_pieces[56] = Piece(PieceType::NONE, PieceColor::COLOR_WHITE);
                    }
                    else if (targetIndex == 6) // Black king-side castling
                    {
                        this->m_pieces[5] = this->m_pieces[7];
                        this->m_pieces[7] = Piece(PieceType::NONE, PieceColor::COLOR_BLACK);
                    }
                    else if (targetIndex == 2) // Black queen-side castling
                    {
                        this->m_pieces[3] = this->m_pieces[0];
                        this->m_pieces[0] = Piece(PieceType::NONE, PieceColor::COLOR_BLACK);
                    }
                }

                this->m_colorToMove = (this->m_colorToMove == PieceColor::COLOR_WHITE) ? PieceColor::COLOR_BLACK : PieceColor::COLOR_WHITE;
                this->GenerateMoves();
            }
            else
            {
                // If the move is not legal, return the piece to its original position
                this->m_pieces[m_dragSourceIndex] = m_dragPiece;
            }
        }
        else
        {
            // If the move didn't happen, return the piece to its original position
            this->m_pieces[m_dragSourceIndex] = m_dragPiece;
        }

        m_isDragging = false;
        m_dragSourceIndex = -1;
    }
}

int Board::GetSquareIndexFromMousePos(Vector2 mousePos)
{
    int file = (mousePos.x - this->m_position.x) / this->m_tileSize;
    int rank = (mousePos.y - this->m_position.y) / this->m_tileSize;

    if (file >= 0 && file < 8 && rank >= 0 && rank < 8)
    {
        return file + rank * 8;
    }

    return -1;
}

void Board::PrecomputeMoveData()
{
    for (int file = 0; file < 8; file++)
    {
        for (int rank = 0; rank < 8; rank++)
        {
            int numNorth = 7 - rank;
            int numSouth = rank;
            int numEast = 7 - file;
            int numWest = file;

            int squareIndex = file + rank * 8;

            m_numSquaresToEdge[squareIndex][0] = numNorth;
            m_numSquaresToEdge[squareIndex][1] = numSouth;
            m_numSquaresToEdge[squareIndex][2] = numEast;
            m_numSquaresToEdge[squareIndex][3] = numWest;
            m_numSquaresToEdge[squareIndex][4] = std::min(numNorth, numEast);
            m_numSquaresToEdge[squareIndex][5] = std::min(numSouth, numEast);
            m_numSquaresToEdge[squareIndex][6] = std::min(numSouth, numWest);
            m_numSquaresToEdge[squareIndex][7] = std::min(numNorth, numWest);
        }
    }
}

void Board::GenerateMoves()
{
    this->m_legalMoves.clear();

    for (int source = 0; source < 64; source++)
    {
        uint8_t piece = this->m_pieces[source].GetData();
        if (piece == 0b0000)
        {
            continue;
        }

        PieceColor color = this->m_pieces[source].GetColor();

        if (color != this->m_colorToMove)
        {
            continue;
        }

        PieceType type = this->m_pieces[source].GetType();

        this->GenerateMoves(source, type);
    }
}

void Board::GeneratePawnMoves(int source)
{
    int direction = this->m_pieces[source].GetColor() == PieceColor::COLOR_WHITE ? -1 : 1;
    int target = source + 8 * direction;

    // Normal one-square pawn advance
    if (this->m_pieces[target].GetData() == 0b0000)
    {
        this->m_legalMoves.emplace_back(Move{source, target});
    }

    // Two-square pawn advance (only from starting rank)
    if ((source >= 8 && source < 16 && this->m_pieces[source].GetColor() == PieceColor::COLOR_BLACK) ||
        (source >= 48 && source < 56 && this->m_pieces[source].GetColor() == PieceColor::COLOR_WHITE))
    {
        target = source + 16 * direction;
        if (this->m_pieces[target].GetData() == 0b0000)
        {
            this->m_legalMoves.emplace_back(Move{source, target});
        }
    }

    // Diagonal captures (left and right)
    for (int diagonalOffset : {7, 9})
    {
        target = source + diagonalOffset * direction;
        if (target >= 0 && target < 64 && this->m_pieces[target].GetColor() != this->m_pieces[source].GetColor() && this->m_pieces[target].GetData() != 0b0000)
        {
            this->m_legalMoves.emplace_back(Move{source, target});
        }
    }

    // En Passant capture
    for (int diagonalOffset : {7, 9})
    {
        int enPassantTarget = source + diagonalOffset * direction;
        if (enPassantTarget == m_enPassantTarget)
        {
            this->m_legalMoves.emplace_back(Move{source, m_enPassantTarget, true});
        }
    }
}

void Board::GenerateKnightMoves(int source)
{
    // Predefined offsets for knight moves
    static const int knightOffsets[8] = {-17, -15, -10, -6, 6, 10, 15, 17};

    for (int offset : knightOffsets)
    {
        int target = source + offset;

        // Make sure the target is within the bounds of the board
        if (target >= 0 && target < 64)
        {
            // Calculate the file and rank of the source and target squares
            int sourceFile = source % 8;
            int targetFile = target % 8;

            // Ensure the move doesn't wrap around the board horizontally
            if (abs(sourceFile - targetFile) <= 2)
            {
                PieceColor targetColor = this->m_pieces[target].GetColor();
                PieceType targetType = this->m_pieces[target].GetType();

                // If the target square is empty or contains an opponent's piece, it's a valid move
                if (targetType == PieceType::NONE || targetColor != this->m_pieces[source].GetColor())
                {
                    this->m_legalMoves.emplace_back(Move{source, target});
                }
            }
        }
    }
}

void Board::GenerateKingMoves(int source)
{
    // Predefined offsets for king moves
    static const int kingOffsets[8] = {-9, -8, -7, -1, 1, 7, 8, 9};

    for (int offset : kingOffsets)
    {
        int target = source + offset;

        // Make sure the target is within the bounds of the board
        if (target >= 0 && target < 64)
        {
            // Calculate the file and rank of the source and target squares
            int sourceFile = source % 8;
            int targetFile = target % 8;

            // Ensure the move doesn't wrap around the board horizontally
            if (abs(sourceFile - targetFile) <= 1)
            {
                PieceColor targetColor = this->m_pieces[target].GetColor();
                PieceType targetType = this->m_pieces[target].GetType();

                // If the target square is empty or contains an opponent's piece, it's a valid move
                if (targetType == PieceType::NONE || targetColor != this->m_pieces[source].GetColor())
                {
                    this->m_legalMoves.emplace_back(Move{source, target});
                }
            }
        }
    }

    // Castling
    if (this->m_pieces[source].GetColor() == PieceColor::COLOR_WHITE)
    {
        // White king-side castling
        if (source == 60 && this->m_pieces[61].GetData() == 0b0000 && this->m_pieces[62].GetData() == 0b0000 && this->m_castlingRights[0])
        {
            this->m_legalMoves.emplace_back(Move{source, 62});
        }

        // White queen-side castling
        if (source == 60 && this->m_pieces[59].GetData() == 0b0000 && this->m_pieces[58].GetData() == 0b0000 && this->m_pieces[57].GetData() == 0b0000 && this->m_castlingRights[1])
        {
            this->m_legalMoves.emplace_back(Move{source, 58});
        }
    }
    else
    {
        // Black king-side castling
        if (source == 4 && this->m_pieces[5].GetData() == 0b0000 && this->m_pieces[6].GetData() == 0b0000 && this->m_castlingRights[2])
        {
            this->m_legalMoves.emplace_back(Move{source, 6});
        }

        // Black queen-side castling
        if (source == 4 && this->m_pieces[3].GetData() == 0b0000 && this->m_pieces[2].GetData() == 0b0000 && this->m_pieces[1].GetData() == 0b0000 && this->m_castlingRights[3])
        {
            this->m_legalMoves.emplace_back(Move{source, 2});
        }
    }
}

void Board::GenerateQueenMoves(int source)
{
    int sourceRank = source / 8;
    int sourceFile = source % 8;

    for (int direction : m_directions)
    {
        for (int n = 1; n < 8; n++) // A queen can move up to 7 squares in any direction
        {
            int target = source + direction * n;

            // Check if the move is within bounds
            if (target < 0 || target >= 64)
            {
                break; // Outside board boundaries
            }

            int targetRank = target / 8;
            int targetFile = target % 8;

            // Check for horizontal wrapping
            if (std::abs(direction) == 1 || std::abs(direction) == 7 || std::abs(direction) == 9)
            {
                if (std::abs(sourceFile - targetFile) != n)
                {
                    break; // Move wraps around the board horizontally
                }
            }

            // Check for vertical wrapping
            if (std::abs(sourceRank - targetRank) > 7)
            {
                break; // Move wraps around the board vertically
            }

            PieceColor targetColor = this->m_pieces[target].GetColor();
            PieceType targetType = this->m_pieces[target].GetType();

            // If the target square is empty or contains an opponent's piece, it's a valid move
            if (targetType == PieceType::NONE || targetColor != this->m_pieces[source].GetColor())
            {
                this->m_legalMoves.emplace_back(Move{source, target});
            }

            // Stop sliding if we hit any piece (whether opponent's or own piece)
            if (targetType != PieceType::NONE)
            {
                break;
            }
        }
    }
}

void Board::GenerateRookMoves(int source)
{
    int sourceRank = source / 8;
    int sourceFile = source % 8;

    std::array<int, 4> directions = {-8, -1, 1, 8};

    for (int direction : directions)
    {
        for (int n = 1; n < 8; n++) // A rook can move up to 7 squares in any direction
        {
            int target = source + direction * n;

            // Check if the move is within bounds
            if (target < 0 || target >= 64)
            {
                break; // Outside board boundaries
            }

            int targetRank = target / 8;
            int targetFile = target % 8;

            // Check for horizontal wrapping
            if (std::abs(direction) == 1)
            {
                if (std::abs(sourceFile - targetFile) != n)
                {
                    break; // Move wraps around the board horizontally
                }
            }

            // Check for vertical wrapping
            if (std::abs(sourceRank - targetRank) > 7)
            {
                break; // Move wraps around the board vertically
            }

            PieceColor targetColor = this->m_pieces[target].GetColor();
            PieceType targetType = this->m_pieces[target].GetType();

            // If the target square is empty or contains an opponent's piece, it's a valid move
            if (targetType == PieceType::NONE || targetColor != this->m_pieces[source].GetColor())
            {
                this->m_legalMoves.emplace_back(Move{source, target});
            }

            // Stop sliding if we hit any piece (whether opponent's or own piece)
            if (targetType != PieceType::NONE)
            {
                break;
            }
        }
    }
}

void Board::GenerateBishopMoves(int source)
{
    int sourceRank = source / 8;
    int sourceFile = source % 8;

    std::array<int, 4> directions = {-9, -7, 7, 9};

    for (int direction : directions)
    {
        for (int n = 1; n < 8; n++) // A bishop can move up to 7 squares in any direction
        {
            int target = source + direction * n;

            // Check if the move is within bounds
            if (target < 0 || target >= 64)
            {
                break; // Outside board boundaries
            }

            int targetRank = target / 8;
            int targetFile = target % 8;

            // Check for horizontal wrapping
            if (std::abs(sourceFile - targetFile) != n)
            {
                break; // Move wraps around the board horizontally
            }

            // Check for vertical wrapping
            if (std::abs(sourceRank - targetRank) > 7)
            {
                break; // Move wraps around the board vertically
            }

            PieceColor targetColor = this->m_pieces[target].GetColor();
            PieceType targetType = this->m_pieces[target].GetType();

            // If the target square is empty or contains an opponent's piece, it's a valid move
            if (targetType == PieceType::NONE || targetColor != this->m_pieces[source].GetColor())
            {
                this->m_legalMoves.emplace_back(Move{source, target});
            }

            // Stop sliding if we hit any piece (whether opponent's or own piece)
            if (targetType != PieceType::NONE)
            {
                break;
            }
        }
    }
}

void Board::GenerateMoves(int source, PieceType type)
{
    switch (type)
    {
    case PieceType::PAWN:
        this->GeneratePawnMoves(source);
        break;
    case PieceType::KNIGHT:
        this->GenerateKnightMoves(source);
        break;
    case PieceType::KING:
        this->GenerateKingMoves(source);
        break;
    case PieceType::QUEEN:
        this->GenerateQueenMoves(source);
        break;
    case PieceType::ROOK:
        this->GenerateRookMoves(source);
        break;
    case PieceType::BISHOP:
        this->GenerateBishopMoves(source);
        break;
    default:
        break;
    }
}
