# tmux-persist

Snapshot and restore tmux sessions across reboots — preserving window layouts, pane splits, working directories, and running commands.

## Install

```bash
# Copy to somewhere on your PATH
sudo cp tmux-freeze tmux-thaw /usr/local/bin/
sudo chmod +x /usr/local/bin/tmux-freeze /usr/local/bin/tmux-thaw

# tmux-thaw requires jq
sudo apt install jq   # Debian/Ubuntu
brew install jq        # macOS
```

## Quick Start

```bash
# Freeze all current tmux sessions
tmux-freeze

# Reboot...

# Restore everything
tmux-thaw
```

## tmux-freeze

Captures each session's windows, pane layout, working directories, and the command running in each pane into a JSON snapshot.

```bash
tmux-freeze              # freeze all sessions
tmux-freeze mysession    # freeze just one
tmux-freeze --list       # see saved snapshots
tmux-freeze --delete NAME  # remove a snapshot
```

Snapshots are saved to `~/.tmux-freeze/` with timestamps. A `latest.json` symlink always points to the most recent freeze.

### What gets captured

| Data                   | Captured? |
|------------------------|-----------|
| Session names          | ✓         |
| Window names & indices | ✓         |
| Pane layout (splits)   | ✓         |
| Working directories    | ✓         |
| Running commands       | ✓         |
| Python virtualenvs     | ✓         |
| Shell type per pane    | ✓         |
| Shell history          | ✗         |
| Unsaved file buffers   | ✗         |

## tmux-thaw

Recreates sessions from a snapshot — rebuilds windows, splits panes to match the saved layout, `cd`s into the right directories, and re-runs commands.

```bash
tmux-thaw                        # restore from latest snapshot
tmux-thaw snapshot.json          # restore from specific file
tmux-thaw --dry-run              # preview without doing anything
tmux-thaw --no-commands          # restore layout only, skip commands
tmux-thaw --interactive          # prompt before each command
```

### Safety features

- **Stateful command skipping**: Commands like `claude`, `aider`, `cursor` that can't be meaningfully restarted are auto-skipped. This list is [user-configurable](#skip-patterns).
- **Dangerous command detection**: Commands like `rm`, `dd`, `mkfs` are auto-skipped with a warning.
- **Interactive mode** (`--interactive`): Prompts you before running each command, with options to skip, edit, or skip all remaining.
- **No-commands mode** (`--no-commands`): Restores the full layout without executing any commands.
- **Existing session protection**: Won't clobber a session that already exists.
- **Missing directory fallback**: If a saved directory no longer exists, falls back to `$HOME`.

## Auto-freeze on shutdown

To automatically freeze before reboot/shutdown:

### systemd (Linux)

```bash
cat > ~/.config/systemd/user/tmux-freeze.service << 'EOF'
[Unit]
Description=Freeze tmux sessions before shutdown
DefaultDependencies=no
Before=shutdown.target reboot.target halt.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/tmux-freeze
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl --user enable tmux-freeze.service
```

### cron + @reboot (auto-thaw on boot)

```bash
# Add to crontab:
@reboot /usr/local/bin/tmux-thaw --no-commands 2>&1 | logger -t tmux-thaw
```

### tmux hook (freeze on detach)

```bash
# Add to ~/.tmux.conf:
set-hook -g client-detached 'run-shell "tmux-freeze"'
```

## Configuration

| Variable             | Default                                     | Description                |
|----------------------|---------------------------------------------|----------------------------|
| `TMUX_FREEZE_DIR`    | `~/.tmux-freeze`                            | Where snapshots are saved  |
| `TMUX_THAW_SKIP_FILE`| `~/.config/tmux-freeze/skip-patterns`      | Custom skip patterns file  |

### Skip patterns

During thaw, some commands should not be automatically restarted (e.g. interactive AI sessions that hold state). These are matched by extended regex patterns and skipped with a warning.

**Built-in defaults** (always active):

```
^claude$, ^claude , ^aider$, ^aider , ^cursor$
```

**Adding your own**: create `~/.config/tmux-freeze/skip-patterns` with one pattern per line:

```bash
mkdir -p ~/.config/tmux-freeze
cat > ~/.config/tmux-freeze/skip-patterns << 'EOF'
# Stateful tools that shouldn't auto-restart
^my-custom-repl$
^jupyter-notebook
EOF
```

Blank lines and lines starting with `#` are ignored. Patterns are extended regex (same as `grep -E`). Custom patterns are added alongside the built-ins, not replacing them.

Override the config file location with `TMUX_THAW_SKIP_FILE`.

## Example snapshot (JSON)

```json
{
  "frozen_at": "2026-03-09T14:30:00+00:00",
  "hostname": "mybox",
  "tmux_version": "3.4",
  "sessions": [
    {
      "session_name": "dev",
      "base_index": 0,
      "active_window": 1,
      "windows": [
        {
          "index": 0,
          "name": "editor",
          "layout": "bb62,213x52,0,0{142x52,0,0,0,70x52,143,0,1}",
          "active": false,
          "active_pane": 0,
          "panes": [
            {
              "index": 0,
              "path": "/home/user/project",
              "command": "nvim .",
              "shell": "zsh",
              "width": 142,
              "height": 52
            },
            {
              "index": 1,
              "path": "/home/user/project",
              "command": "",
              "shell": "zsh",
              "width": 70,
              "height": 52
            }
          ]
        }
      ]
    }
  ]
}
```

## Testing

```bash
./tests/run-tests.sh           # run all tests
./tests/run-tests.sh --unit    # skip tmux integration tests
```

## Limitations

- **Stateful processes**: Programs like `vim` with unsaved buffers will restart fresh — they won't recover in-progress state. Interactive tools like `claude` and `aider` are auto-skipped entirely (see [skip patterns](#skip-patterns)).
- **SSH sessions**: The `ssh` command will be re-run, but you'll need to re-authenticate (use ssh-agent or keys for seamless reconnection).
- **Background jobs**: Jobs backgrounded with `&` or `Ctrl-Z` are not captured.
- **Scrollback**: Pane scrollback/output is not captured (to avoid leaking secrets in snapshots).
