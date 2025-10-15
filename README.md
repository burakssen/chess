# Chess Game

A simple chess game implemented in Zig using the Raylib library for graphics rendering.

You can check out the project here without needing to build it yourself:
[burakssen.com/chess](https://burakssen.com/chess/)

## Overview

|                      |                           |                           |
| -------------------- | ------------------------- | ------------------------- |
| ![](images/main.png) | ![](images/black_win.png) | ![](images/white_win.png) |

## Features

- Play against another player on the same machine.
- Basic move validation.
- Visual representation of the chessboard and pieces.
- Highlighting of selected pieces and possible moves.
- Check and checkmate detection.

## Todo

**Important:**

- [ ] Implement AI Opponent
- [ ] Add move history and undo functionality
- [ ] Fix stalemate detection

---

**New Ideas for later:**

- [ ] Add assets for different themes (e.g., wood, marble)
- [ ] Add sound effects for moves and captures
- [ ] Add asset loading from external files

## Requirements

- Zig programming language (version 0.15.1 or later)
- Raylib library (version 5.6.0-dev or later)

## Building and Running

1. Clone the repository:

   ```bash
    git clone https://github.com/burakssen/chess
    cd chess
   ```

2. Build the project using Zig's build system:

   - For desktop:

     ```bash
     zig build run
     ```

   - For web (It fetches emscripten):

     ```bash
     zig build -Dtarget=wasm32-emscripten -Doptimize=ReleaseSafe
     ```

     Open `zig-out/install/web/` a web server (e.g., `python -m http.server`) and navigate to `http://localhost:8000/chess.html`.

3. Run the compiled executable:
   ```bash
   ./zig-out/bin/chess
   ```

## Controls

- Click on a piece to drag and move it to a valid square.
- The game will automatically switch turns between players.
- The game will give visual feedback for check and checkmate situations.

## License

This project is licensed under the MIT License. See the [LICENSE](./LICENSE) file for details.
