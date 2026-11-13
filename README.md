<p align="center">
  <img src="docs/readme/logo.webp" width="128" height="128" alt="Trilha Jujuba logo: a red jelly cube on a path of painted tiles">
</p>

<h1 align="center">Trilha Jujuba</h1>

<p align="center"><strong>A cozy slide-and-paint puzzle game. Swipe the jellies and paint each tile of the board.</strong></p>

<p align="center">
  <a href="https://godotengine.org/"><img src="https://img.shields.io/badge/Godot-4.7.2-478cbf?logo=godotengine&logoColor=white" alt="Godot 4.7.2"></a>
  <img src="https://img.shields.io/badge/platforms-Android%20%7C%20Windows-8f8cf6" alt="Platforms: Android and Windows">
  <img src="https://img.shields.io/badge/GDScript-100%25-355570" alt="GDScript">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-f2b84b" alt="License: MIT"></a>
</p>

> A free portrait mobile game, made with Godot 4.7.2 and GDScript. Each sound and each piece of music comes from code.

<p align="center">
  <img src="docs/readme/home.webp" width="260" alt="The home screen with the title Trilha Jujuba, a live demo board, the theme button at the top right and the Play, Levels and Random level buttons">
  <img src="docs/readme/swipe-paint.webp" width="260" alt="Level 8 in the middle of a swipe: four jellies slide down and leave trails of paint">
  <img src="docs/readme/result-card.webp" width="260" alt="The result card with three stars, the time, the move count, the star ranges and the Watch replay button">
</p>

## The game

- Each level is a board of floor tiles, with walls and obstacles.
- One to four jellies sit on the board. Each jelly has its own color.
- Swipe to move the jellies. Each tile that a jelly touches takes its color.
- Paint all the floor tiles to complete the level. Use as few moves as possible to get three stars.
- The game has 20 levels, a one-jelly mode and endless random levels.
- Watch a replay of your game after each win or defeat.
- Play in English or in Brazilian Portuguese, in a light or a dark theme.

## Gallery

| | |
|---|---|
| ![The level select screen: the first page of level cards, the stars of each level, the one-jelly switch and the page buttons](docs/readme/level-select.webp) | ![Level 8 at the start: four jellies, dark obstacle blocks and three curved rails](docs/readme/level-start.webp) |
| The level select screen shows your stars on three pages. A level opens when you get one star on the level before it. | Level 8 at the start, with four jellies, obstacles and curved rails. |
| ![A swipe to the right: the red and purple jellies slide and leave paint trails behind them](docs/readme/swipe-trails.webp) | ![The win wave: the tiles jump and flash while glitter flies from the last jelly](docs/readme/win-wave.webp) |
| All the jellies slide at the same time and paint their path. | The last tile starts the win wave across the board. |
| ![The HUD in tension: three moves left in red and a red frame around the move meter](docs/readme/tension.webp) | ![The defeat card: a sad jelly, the painted percentage, Retry and Watch replay](docs/readme/defeat-card.webp) |
| Near the move limit, the HUD turns red and the music becomes tense. | When the moves stop, the defeat card shows how much of the path you painted. |
| ![A replay in progress: the board plays the moves again, with the move counter and "Tap to go back" at the bottom](docs/readme/replay.webp) | ![Level 8 in one-jelly mode: one jelly and some new walls on the same board](docs/readme/one-jelly.webp) |
| Watch your own game again, move by move. | One-jelly mode: the same level with one jelly, a new puzzle and its own stars. |
| ![A random level: a new board, with "Random level" and the seed in the HUD](docs/readme/random-level.webp) | ![The pause dialog with Resume, Levels, the one-jelly switch, and the music, sound effects, vibration, reduced motion, language and dark mode rows](docs/readme/pause.webp) |
| Random levels never end. Each one has a seed and a solution. | The pause dialog holds the modes and the settings. |

### Light and dark

| Light | Dark |
|---|---|
| ![The home screen in the light theme, with the moon button at the top right](docs/readme/theme-home-light.webp) | ![The home screen in the dark theme, with the sun button at the top right](docs/readme/theme-home-dark.webp) |
| ![The level select screen in the light theme](docs/readme/theme-levels-light.webp) | ![The level select screen in the dark theme](docs/readme/theme-levels-dark.webp) |
| ![Level 8 in the middle of a swipe, in the light theme](docs/readme/theme-play-light.webp) | ![Level 8 in the middle of a swipe, in the dark theme](docs/readme/theme-play-dark.webp) |
| ![The pause dialog in the light theme](docs/readme/theme-pause-light.webp) | ![The pause dialog in the dark theme](docs/readme/theme-pause-dark.webp) |

The jellies keep the same colors in the two themes. Tap the moon or the sun at the top right of the home screen to change the theme.

## Contents

- [The game](#the-game)
- [Gallery](#gallery)
- [How to play](#how-to-play)
- [Modes](#modes)
- [Features](#features)
- [Download](#download)
- [Build from source](#build-from-source)
- [For developers](#for-developers)
- [License](#license)

## How to play

### The swipe

- Swipe up, down, left or right. On a computer, use the arrow keys or WASD.
- All the jellies move in the same direction, at the same time.
- A jelly slides until a wall, an obstacle or a stopped jelly stops it.
- A curved rail turns a jelly to a new direction while it slides.
- When two jellies go to the same tile, one jelly goes first and the other stops behind it.

### The paint

- Each jelly starts on a tile that already has its color.
- Each tile that a jelly enters takes the color of that jelly.
- A jelly can paint a tile again with a different color. The tile stays painted.
- The bar at the bottom of the screen shows the painted percentage.

### Moves

- A swipe counts as a move only when at least one jelly changes its position.
- A swipe into a wall does not count. The jellies only give a small nudge.
- Each level has a move limit. The HUD shows the moves that remain.
- Near the limit, the tension starts: the meter turns red and the music changes.

### Win, lose and stars

- You win when each floor tile has paint.
- You lose when you use all the moves and some tiles have no paint. There is no time limit.
- The game knows the minimum number of moves for each level. A solver calculates it.
- You get 3 stars near the minimum, 2 stars with some more moves and 1 star up to the limit.
- The move meter shows the star ranges. When a move drops a star, the star falls from the HUD.
- The result card shows your time, your moves and the move range for 3 stars.

## Modes

### Levels

- 20 levels on three pages of the level select screen. You can get 60 stars.
- Level 1 is always open. A level opens when you get one star on the level before it, in any mode.
- The level hints teach the rules: the curved rails, a stopped jelly as a wall, and two jellies that go to the same tile.

### One-jelly mode

- Turn it on with the "1 jelly" switch on the level select screen, or with the "One jelly" switch in the pause dialog.
- Each level with two or more jellies becomes a new puzzle with one jelly. Some floor tiles become walls.
- Levels 1 to 3 have one jelly already, so they do not change.
- The mode has its own minimum moves, its own stars and its own records.
- When you change the mode in the pause dialog, the level starts again when you continue.

### Random levels

- Push "Random level" on the home screen, or "New random" on the result card or the defeat card.
- Each random level comes from a seed. The HUD shows the seed.
- The game makes a new board, solves it and keeps it only when the puzzle is good. A short loading screen can show during this work.
- A random level has 1 or 2 jellies, or 1 jelly in one-jelly mode.
- Random levels give stars, but the game keeps no record of them.

### Replay

- After a win or a defeat, push "Watch replay" on the card.
- The board goes back to the start and plays your moves again, one by one.
- Tap the screen, or push Esc, to stop the replay.

## Features

- **20 levels** with 1 to 4 jellies, obstacles and curved rails. Each level has a name.
- **Star score and records.** The game keeps the stars, the best move count and the best time of each level, in each mode.
- **Two languages.** English and Brazilian Portuguese, with the level names. The game uses the language of the device. Change it in the pause dialog.
- **Light and dark themes.** A dark "night candy" palette. Use the round button at the top right of the home screen, or the "Dark mode" row below "Language" in the pause dialog. The theme changes at once, behind a short cover. The game stays on the same screen and in the same state, also in a replay or a random level. The game keeps your choice. With no choice, it follows the device.
- **Procedural audio.** A script makes all 17 sound effects and the 2 music loops from code. The game keeps them as WAV files.
- **Adaptive music.** A calm loop plays during the level. The tense loop starts near the move limit, on the beat.
- **The music opens as you paint.** A filter on the music opens as the board fills with paint.
- **Juice.** Squash on stop, paint splashes, impact rings, board shake, hit-stop, glitter and confetti.
- **Win and defeat ceremonies.** The tiles jump in a wave when you win. When you lose, the jellies deflate and the empty tiles pulse. A tap skips a ceremony.
- **Live demo board.** The home screen plays a small level again and again behind the buttons.
- **Reduced motion.** A switch in the pause dialog makes the shake, the waves, the hit-stop and the particles smaller.
- **Haptics.** A short vibration when the jellies stop, on phones only. A switch in the pause dialog turns it off.
- **Performance panel.** Press F3, or long-press the title of the pause dialog. It shows FPS, frame, script, draw and render times, draw calls and the device and GPU names.
- **Light on the GPU.** The board art and the vector UI art are baked into atlases, to keep the draw calls low on phones.
- **Keyboard.** Arrow keys or WASD to swipe, R to restart, Esc or P to pause, F3 for the performance panel.

## Download

Get the Android APK and the Windows EXE from the [latest release](https://github.com/salvimateus/slide-blocks-the-game/releases/latest).

> [!NOTE]
> The Windows EXE has no code signing certificate. Windows can show "Windows protected your PC" at the first start. Click "More info", then "Run anyway".

## Build from source

### Requirements

- [Godot 4.7.2](https://godotengine.org/download/archive/) (standard build, not .NET).
- The Godot 4.7.2 export templates, for the exports.
- For Android: the Android SDK and a Java JDK 17, set in the Godot editor settings.

### Open the project

```sh
git clone https://github.com/salvimateus/slide-blocks-the-game.git
```

1. Start Godot 4.7.2.
2. Click "Import" and select the `project.godot` file of the clone.
3. Press F5 to play.

The project uses the Compatibility renderer, a 720 x 1280 portrait viewport and a 540 x 960 window on the computer.

### Export

`export_presets.cfg` has two presets. Each preset writes into `build/`, which git ignores.

| Preset | Output | Notes |
|---|---|---|
| `Windows Desktop` | `build/windows/trilha-jujuba.exe` | x86_64, with the game data in the EXE. |
| `Android` | `build/android/trilha-jujuba-debug.apk` | arm64-v8a, package `com.sandbox.trilhajujuba`, signed with the debug keystore of the editor. |

Export from the editor with Project > Export, or from the command line:

```sh
godot --headless --path . --export-release "Windows Desktop" build/windows/trilha-jujuba.exe
godot --headless --path . --export-debug "Android" build/android/trilha-jujuba-debug.apk
```

On WSL, `tools/export.sh` does the full export. It checks the levels, loads each script, does a boot test, exports the two presets and verifies the APK signature.

## For developers

### Project structure

- `autoload/`: the global nodes: `Game`, `Bus` (signals), `Save`, `Sfx`, `Music`, `Feel`, `Tuning`, `Harness` and `PerfPanel`.
- `scenes/main/`: the main scene. `scenes/dev/` holds the board and UI lab scenes, which the exports do not include.
- `scripts/core/`: the pure rules: level parser, level data, par data, slide rules, score rules, session, solver, one-jelly variants and the random level generator.
- `scripts/board/`: the board view: jellies, swipe playback, replay, ceremonies, effects, texture bank and the demo board.
- `scripts/ui/`: the screens, the HUD, the cards, the pause dialog, the loading screen, the replay overlay, the text strings in two languages and the theme.
- `scripts/audio/`: the audio bank and the audio tuning. `scripts/input/` holds the swipe input.
- `tools/`: the audio bake, the level solver, the random level check, the load check and `export.sh`.
- `audio/`: the baked WAV files. `art/icon/` holds the Android icons. `ui/fonts/` holds the Nunito font.
- `docs/readme/`: the images of this README.
- `PRIMITIVES.md`: the inventory of the shared contracts of the code.

### Levels and audio tools

Check that each level has a solution and that `par_data.gd` agrees with it:

```sh
godot --headless --path . --script res://tools/levels_tool.gd -- --check
```

After a level change, write the new minimum moves and the one-jelly variants into `par_data.gd`:

```sh
godot --headless --path . --script res://tools/levels_tool.gd -- --write
```

Check the random level generator on 200 seeds:

```sh
godot --headless --path . --script res://tools/random_tool.gd -- --count=200
```

Make all the WAV files again from the code in `tools/audio/`:

```sh
godot --headless --path . --script res://tools/bake_audio.gd
```

### Scripted runs and screenshots

The `Harness` autoload reads arguments after `--`. With no argument, it does nothing.

| Argument | What it does |
|---|---|
| `--level=<n>` | Starts level n (1 to 20). |
| `--moves=<UDLR>` | Sends the swipes as touch drags, for example `--moves=URUUR`. |
| `--keys=<UDLR>` | Sends the swipes as key presses. |
| `--solve` | Plays the solution of the level with the minimum moves. It also works in one-jelly mode and on a random level. |
| `--play-all` | Solves each level in sequence. |
| `--screen=home\|levels\|pause` | Opens that screen. `pause` opens after the scripted moves. |
| `--page=<n>` | With `--screen=levels`, opens page n of the level select screen. |
| `--solo` | Turns on the one-jelly mode. Needs `--save`. `--solve` and `--play-all` then play the one-jelly version. |
| `--random[=<seed>]` | Plays a random level, with this seed or a new seed. Does not combine with `--level`, `--play-all` or `--screen`. |
| `--random-hold=<ms>` | Holds the random level for this time, so the loading screen shows. |
| `--random-map` | Prints each row of the random map. |
| `--replay` | Plays the replay when the result card or the defeat card is at rest. Needs `--level` or `--random`. |
| `--replay-stop-at=<n>` | Stops the replay at move n. |
| `--lang=pt\|en` | Forces the language for this run. The save does not change. |
| `--set-lang=pt\|en` | Changes the language through the save at the last state of the run. Needs `--save`. |
| `--theme=light\|dark` | Forces the theme for this run. The save does not change. |
| `--switch-theme=light\|dark` | Changes the theme through the save at the `--switch-on` event, as the dark mode row does. |
| `--switch-on=<event>` | Sets the event for `--switch-theme` (`home` by default). |
| `--tap=theme` | Sends a real touch to the theme button of the home screen at the `--tap-on` event. |
| `--tap-on=<event>` | Sets the event for `--tap` (`home` by default). |
| `--shot=<png> --frames=<n>` | Saves one screenshot after n frames, then quits. |
| `--shots=<dir> --shot-on=<events>` | Saves a screenshot at each named event. `*` captures all events. |
| `--quit-at=<event>` | Quits at that event. |
| `--save=<file>` | Uses this save file, not the save of the player. |
| `--unlock-all` | Opens all the levels, in memory only. |
| `--reduced-motion` | Turns on reduced motion. |
| `--move-gap=<ms>` | Sets the time between scripted swipes (250 ms by default). |
| `--freeze-at=<s>` | Pauses the game after s seconds. |
| `--state-log` | Prints the state after each swipe and the result at the end. |
| `--perf-summary`, `--frame-log` | Prints the frame times, or logs each frame above 25 ms. |
| `--timeout=<s>` | Stops a stuck run (60 s by default). |
| `--time-scale=<f>` | Sets the base time scale of the game. |

The events are `home`, `levels`, `level_ready`, `move_<n>_mid`, `move_<n>_end`, `tense`, `win_wave`, `result`, `defeat_wave`, `defeat_card`, `pause`, `loading`, `random_ready`, `replay_start`, `replay_move_<n>`, `replay_end`, `lang`, `theme_switched` and `tap`.

Run screenshots in a window, never with `--headless`, because the headless renderer draws nothing. Use `--fixed-fps 60`, so each frame lands at the same moment in each run. Always pass `--save` with a test file, so the run does not change your own save. This command solves level 8 and saves a screenshot at each event:

```sh
godot --path . --fixed-fps 60 --audio-driver Dummy -- --save=/absolute/path/to/test-save.cfg --theme=light --lang=en --unlock-all --level=8 --solve --shots=/absolute/path/to/shots --shot-on='*'
```

## License

MIT. Made by [salvimateus](https://github.com/salvimateus). See [LICENSE](LICENSE).
