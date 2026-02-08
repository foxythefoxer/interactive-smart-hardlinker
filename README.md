# Interactive-Smart-Hardlinker

Interactive Bash script for creating hardlinks with hierarchical directory navigation and smart duplicate detection. Browse directories level-by-level, automatically skip already-hardlinked files via inode checking, and optionally save detailed logs.

## Features

- **Interactive Hierarchical Navigation** - Browse directories one level at a time instead of being overwhelmed by nested structures
- **Smart Duplicate Prevention** - Automatically detects and skips files that are already hardlinked (inode checking)
- **Clean Console Output** - Minimal logging during execution with optional detailed log file generation
- **Timeout Protection** - Auto-exits on inactivity to prevent hanging sessions
- **Recursive Hardlinking** - Preserves directory structure when creating hardlinks
- **Cross-Platform** - Works on any Linux system with Bash

## Use Cases

- Media server automation (Sonarr/Radarr/Plex setups following Trash Guides)
- Backup systems requiring hardlinks
- Data deduplication projects
- File organization without duplicating storage
- Maintaining seeding torrents while organizing media libraries

## How It Works

The script walks you through selecting source and destination directories via interactive menus. For each level of your directory tree, you can:
- Select a subdirectory to navigate deeper
- Go back to the parent directory
- Use the current directory
- Enter a custom path

After selecting paths, it recursively creates hardlinks while checking inode counts to prevent accidentally hardlinking files multiple times. Optionally save a detailed log file with timestamps for troubleshooting.

## Requirements

- Linux system with Bash
- Basic utilities: `find`, `stat`, `ln`, `mkdir`

## Usage

```bash
./Interactive-Smart-Hardlinker.sh
```

Run via SSH or any interactive terminal. The script will guide you through the process with prompts and menus.

## Installation

```bash
git clone https://github.com/foxythefoxer/Interactive-Smart-Hardlinker.git
cd Interactive-Smart-Hardlinker
chmod +x Interactive-Smart-Hardlinker.sh
./Interactive-Smart-Hardlinker.sh
```

## Configuration

By default, the script is configured for Unraid/Trash Guides directory structures:
- `BASE_SOURCE="/mnt/user/data/torrents"`
- `BASE_DEST="/mnt/user/data/media"`

To use on any Linux system, edit these paths at the top of the script:
```bash
BASE_SOURCE="/"  # Start from root
BASE_DEST="/"    # Or any desired base path
```

## Example Workflow

1. Run the script
2. Navigate to your source directory (e.g., `/torrents/movies/`)
3. Navigate to your destination directory (e.g., `/media/movies/`)
4. Confirm the operation
5. Review the summary statistics
6. Optionally save a detailed log file

## Log Files

When you choose to save a log file, it will be timestamped and saved with the format:
```
hardlink_log_2026-02-06_22-45-35.txt
```

The log includes:
- Full operation details
- Every file processed
- Already-hardlinked files (skipped)
- Errors encountered
- Summary statistics

## Created By

FoxyTheFoxer with assistance from Claude AI (Anthropic) - February 2026

## License

MIT License - Feel free to use, modify, and distribute.
