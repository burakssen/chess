#include <iostream>
#include "Chess.h"

int main()
{
    try
    {
        Chess::Initialize();
        Chess &chess = Chess::GetInstance();
        chess.Run();
        Chess::Shutdown();
    }
    catch (const std::exception &e)
    {
        std::cerr << e.what() << std::endl;
    }
    return 0;
}