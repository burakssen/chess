#pragma once

typedef struct Move
{
    int source;
    int target;
    bool isEnPassant = false;
} Move;