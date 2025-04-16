# Config
Varous Config Files

Most important is the .bashrc that includes various comfort functions for Ubuntu:

## Key Components

- **Prompt Customization**:
  - Displays username, hostname, and current directory with color support.
  - Indicates Git repository status with a `*` for modified files.

- **Environment Variables**:
  - Adds `~/bin` and `~/.local/bin` to `PATH` if present.
  - Configures `LESS` with `-R` for raw control character output.

- **History Settings**:
  - Ignores duplicate commands and spaces (`HISTCONTROL=ignoreboth`).
  - Appends to history file (`shopt -s histappend`).
  - Sets `HISTSIZE=1000` and `HISTFILESIZE=2000`.

- **Shell Options**:
  - Updates window size after commands (`shopt -s checkwinsize`).
  - Enables programmable completion via `/usr/share/bash-completion/bash_completion`.

- **Aliases**:
  - `ls`: Adds `--color=auto` for colored output.
  - `grep`, `fgrep`, `egrep`: Enables colored output.
  - `ll`: Long listing (`ls -l`).
  - `la`: Lists all files, including hidden (`ls -A`).
  - `l`: Long listing with all files (`ls -lA`).
  - `alert`: Sends notifications for long-running commands.

- **Custom Functions**:
  - `mkdircd`: Creates a directory and changes into it (e.g., `mkdircd new_folder`).
