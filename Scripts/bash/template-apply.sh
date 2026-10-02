#!/usr/bin/env -S bash

# Ensure at least one argument is provided.
if [ "$#" -lt 1 ]; then
    # Print usage information to standard error.
    echo "Error: No application specified." >&2
    echo "Usage: $0 {kitty|ghostty|foot|alacritty|wezterm|starship|fuzzel|walker|pywalfox|cava|yazi|umbriel|btop|zathura|tmux|fcitx5|bat} [dark|light]" >&2
    exit 1
fi

APP_NAME="$1"
MODE="${2:-}" # Optional second argument for dark/light mode

# --- Apply theme based on the application name ---
case "$APP_NAME" in
kitty)
    # Many configs use: include ./current-theme.conf
    # Point it at the generated theme whenever the hook runs (including when hydra.conf
    # was unchanged on disk and the hook was forced from the template processor).
    HYDRA_THEME="$HOME/.config/kitty/themes/hydra.conf"
    CURRENT_THEME="$HOME/.config/kitty/current-theme.conf"
    if [ -f "$HYDRA_THEME" ]; then
        mkdir -p "$HOME/.config/kitty"
        ln -sf "themes/hydra.conf" "$CURRENT_THEME"
    fi
    KITTY_CONF="$HOME/.config/kitty/kitty.conf"
    if [ -w "$KITTY_CONF" ]; then
        kitty +kitten themes --reload-in=all hydra
    else
        kitty +runpy "from kitty.utils import *; reload_conf_in_all_kitties()"
    fi
    # Trigger kitty's live config reload after the template has been regenerated.
    pkill -USR1 kitty >/dev/null 2>&1 || true
    ;;

ghostty)
    # Check both potential config files
    CONFIG_FILES=("$HOME/.config/ghostty/config" "$HOME/.config/ghostty/config.ghostty")
    FOUND_CONFIG=false

    for CONFIG_FILE in "${CONFIG_FILES[@]}"; do
        if [ -f "$CONFIG_FILE" ]; then
            FOUND_CONFIG=true
            # Check if theme is already set to hydra (flexible spacing)
            if grep -qE "^theme\s*=\s*hydra$" "$CONFIG_FILE"; then
                : # Already correct
            elif grep -qE "^theme\s*=" "$CONFIG_FILE"; then
                # Replace existing theme line in-place
                sed -i -E 's/^theme\s*=.*/theme = hydra/' "$CONFIG_FILE"
            else
                # Add the new theme line to the end of the file
                echo "theme = hydra" >>"$CONFIG_FILE"
            fi
        fi
    done

    if [ "$FOUND_CONFIG" = true ]; then
        # Only signal if ghostty is running
        pgrep -f ghostty >/dev/null && pkill -SIGUSR2 ghostty || true
    else
        echo "Error: No ghostty config file found at ${CONFIG_FILES[*]}" >&2
        exit 1
    fi
    ;;

foot)
    CONFIG_FILE="$HOME/.config/foot/foot.ini"

    # Check if the config file exists, create it if it doesn't.
    if [ ! -f "$CONFIG_FILE" ]; then
        # Create the config directory if it doesn't exist
        mkdir -p "$(dirname "$CONFIG_FILE")"
        # Create the config file with the hydra theme
        cat >"$CONFIG_FILE" <<'EOF'
[main]
include=~/.config/foot/themes/hydra
EOF
    else
        # Check if theme is already set to hydra
        if ! grep -q "include.*hydra" "$CONFIG_FILE"; then
            # Remove any existing theme include line to prevent duplicates.
            sed -i '/include=.*themes/d' "$CONFIG_FILE"
            if grep -q '^\[main\]' "$CONFIG_FILE"; then
                # Insert the include line after the existing [main] section header
                sed -i '/^\[main\]/a include=~/.config/foot/themes/hydra' "$CONFIG_FILE"
            else
                # If [main] doesn't exist, create it at the beginning with the include
                sed -i '1i [main]\ninclude=~/.config/foot/themes/hydra\n' "$CONFIG_FILE"
            fi
        fi
    fi
    ;;

alacritty)
    CONFIG_FILE="$HOME/.config/alacritty/alacritty.toml"
    NEW_THEME_PATH='~/.config/alacritty/themes/hydra.toml'

    # Check if the config file exists, create it if it doesn't.
    if [ ! -f "$CONFIG_FILE" ]; then
        # Create the config directory if it doesn't exist
        mkdir -p "$(dirname "$CONFIG_FILE")"
        # Create the config file with the hydra theme import
        cat >"$CONFIG_FILE" <<'EOF'
[general]
import = [
    "~/.config/alacritty/themes/hydra.toml"
]
EOF
    else
        # Check if hydra theme is already imported (any path variant)
        if grep -q 'hydra\.toml' "$CONFIG_FILE"; then
            # Update old relative path to new absolute path if needed
            if grep -q '"themes/hydra.toml"' "$CONFIG_FILE"; then
                sed -i 's|"themes/hydra.toml"|"'"$NEW_THEME_PATH"'"|g' "$CONFIG_FILE"
            fi
            # Already has hydra import with correct path, nothing to do
        else
            # No hydra import found, add it
            if grep -q '^\[general\]' "$CONFIG_FILE"; then
                # Check if import line already exists under [general]
                if grep -q '^import\s*=' "$CONFIG_FILE"; then
                    # Append to existing import array (before the closing bracket)
                    sed -i '/^import\s*=\s*\[/,/\]/{/\]/s|]|    "'"$NEW_THEME_PATH"'",\n]|}' "$CONFIG_FILE"
                else
                    # Add import line after [general] section header
                    sed -i '/^\[general\]/a import = ["'"$NEW_THEME_PATH"'"]' "$CONFIG_FILE"
                fi
            else
                # Create [general] section with import at the beginning of the file
                sed -i '1i [general]\nimport = ["'"$NEW_THEME_PATH"'"]\n' "$CONFIG_FILE"
            fi
        fi
    fi
    ;;

wezterm)
    CONFIG_FILE="$HOME/.config/wezterm/wezterm.lua"
    WEZTERM_SCHEME_LINE='config.color_scheme = "Hydra"'

    # Check if the config file exists.
    if [ -f "$CONFIG_FILE" ]; then

        # Check if theme is already set to Hydra (matches 'Hydra' or "Hydra")
        if ! grep -q "^\s*config\.color_scheme\s*=\s*['\"]Hydra['\"]\s*" "$CONFIG_FILE"; then
            # Not set to Hydra. Check if *any* color_scheme line exists.
            if grep -q '^\s*config\.color_scheme\s*=' "$CONFIG_FILE"; then
                # It exists, so we replace it with our desired line.
                sed -i "s|^\(\s*config\.color_scheme\s*=\s*\).*$|\1\"Hydra\"|" "$CONFIG_FILE"
            else
                # It doesn't exist, so we add it before the 'return config' line.
                if grep -q '^\s*return\s*config' "$CONFIG_FILE"; then
                    # 'return config' exists. Insert the line before it.
                    sed -i '/^\s*return\s*config/i\'"$WEZTERM_SCHEME_LINE" "$CONFIG_FILE"
                else
                    # This is a problem. We can't find the insertion point.
                    echo "Warning: 'config.color_scheme' not set and 'return config' line not found." >&2
                    echo "         Make sure $CONFIG_FILE is correct: https://wezterm.org/config/files.html" >&2
                fi
            fi
        fi
        # touching the config file fools wezterm into reloading it
        touch "$CONFIG_FILE"
    else
        echo "Error: wezterm.lua not found at $CONFIG_FILE" >&2
        echo "Instructions to create it: https://wezterm.org/config/files.html" >&2
        exit 1
    fi
    ;;

fuzzel)
    CONFIG_FILE="$HOME/.config/fuzzel/fuzzel.ini"

    # Check if the config file exists, create it if it doesn't.
    if [ ! -f "$CONFIG_FILE" ]; then
        # Create the config directory if it doesn't exist
        mkdir -p "$(dirname "$CONFIG_FILE")"
        # Create the config file with the hydra theme
        cat >"$CONFIG_FILE" <<'EOF'
include=~/.config/fuzzel/themes/hydra
EOF
    else
        # Check if theme is already set to hydra
        if grep -q "^include=~/.config/fuzzel/themes/hydra$" "$CONFIG_FILE"; then
            : # Already correct
        elif grep -q "^include=.*themes" "$CONFIG_FILE"; then
            # Replace existing theme include line in-place
            sed -i 's|^include=.*themes.*|include=~/.config/fuzzel/themes/hydra|' "$CONFIG_FILE"
        else
            # Add the new theme include line
            echo "include=~/.config/fuzzel/themes/hydra" >>"$CONFIG_FILE"
        fi
    fi
    ;;

walker)
    CONFIG_FILE="$HOME/.config/walker/config.toml"

    # Check if the config file exists.
    if [ -f "$CONFIG_FILE" ]; then
        # Check if theme is already set to hydra (flexible spacing)
        if grep -qE '^theme\s*=\s*"hydra"' "$CONFIG_FILE"; then
            : # Already correct
        elif grep -qE '^theme\s*=' "$CONFIG_FILE"; then
            # Replace existing theme line in-place
            sed -i -E 's/^theme\s*=.*/theme = "hydra"/' "$CONFIG_FILE"
        else
            echo 'theme = "hydra"' >>"$CONFIG_FILE"
        fi
    else
        echo "Error: walker config file not found at $CONFIG_FILE" >&2
        exit 1
    fi
    ;;

vicinae)
    # Apply the theme
    vicinae theme set hydra
    ;;

pywalfox)
    # Set dark/light mode first if MODE is specified
    if [ -n "$MODE" ]; then
        if [ "$MODE" = "dark" ] || [ "$MODE" = "light" ]; then
            pywalfox "$MODE"
        else
            echo "Warning: Invalid mode '$MODE'. Expected 'dark' or 'light'. Skipping mode switch." >&2
        fi
    fi
    # Update the theme
    pywalfox update
    ;;

cava)
    CONFIG_FILE="$HOME/.config/cava/config"
    THEME_MODIFIED=false

    # Check if the config file exists.
    if [ -f "$CONFIG_FILE" ]; then
        # Check if [color] section exists
        if grep -q '^\[color\]' "$CONFIG_FILE"; then
            # Check if theme is already set to hydra under [color] (flexible spacing)
            if sed -n '/^\[color\]/,/^\[/p' "$CONFIG_FILE" | grep -qE '^theme\s*=\s*"hydra"'; then
                : # Already correct
            elif sed -n '/^\[color\]/,/^\[/p' "$CONFIG_FILE" | grep -qE '^theme\s*='; then
                # Replace existing theme line under [color]
                sed -i -E '/^\[color\]/,/^\[/{s/^theme\s*=.*/theme = "hydra"/}' "$CONFIG_FILE"
                THEME_MODIFIED=true
            else
                # Add theme line after [color]
                sed -i '/^\[color\]/a theme = "hydra"' "$CONFIG_FILE"
                THEME_MODIFIED=true
            fi
        else
            # Add [color] section with theme at the end of file
            echo "" >>"$CONFIG_FILE"
            echo "[color]" >>"$CONFIG_FILE"
            echo 'theme = "hydra"' >>"$CONFIG_FILE"
            THEME_MODIFIED=true
        fi

        # Reload cava if it's running, but only if it's not using stdin config
        if pgrep -f cava >/dev/null; then
            # Check if Cava is running with -p /dev/stdin (standalone cava)
            if ! pgrep -af cava | grep -q -- "-p.*stdin"; then
                pkill -USR1 cava
            fi
        fi
    else
        echo "Error: cava config file not found at $CONFIG_FILE" >&2
        exit 1
    fi
    ;;

yazi)
    CONFIG_FILE="$HOME/.config/yazi/theme.toml"

    # Create config directory if it doesn't exist
    mkdir -p "$(dirname "$CONFIG_FILE")"

    if [ ! -f "$CONFIG_FILE" ]; then
        cat >"$CONFIG_FILE" <<'EOF'
[flavor]
dark  = "hydra"
light = "hydra"
EOF
    else
        # Check if [flavor] section exists
        if grep -q '^\[flavor\]' "$CONFIG_FILE"; then
            # Update or add dark/light lines under [flavor]
            if sed -n '/^\[flavor\]/,/^\[/p' "$CONFIG_FILE" | grep -q '^dark\s*='; then
                sed -i '/^\[flavor\]/,/^\[/{s/^dark\s*=.*/dark  = "hydra"/}' "$CONFIG_FILE"
            else
                sed -i '/^\[flavor\]/a dark  = "hydra"' "$CONFIG_FILE"
            fi
            if sed -n '/^\[flavor\]/,/^\[/p' "$CONFIG_FILE" | grep -q '^light\s*='; then
                sed -i '/^\[flavor\]/,/^\[/{s/^light\s*=.*/light = "hydra"/}' "$CONFIG_FILE"
            else
                sed -i '/^\[flavor\]/,/^dark/a light = "hydra"' "$CONFIG_FILE"
            fi
        else
            # Add [flavor] section at the end
            echo "" >>"$CONFIG_FILE"
            echo "[flavor]" >>"$CONFIG_FILE"
            echo 'dark  = "hydra"' >>"$CONFIG_FILE"
            echo 'light = "hydra"' >>"$CONFIG_FILE"
        fi
    fi
    ;;

umbriel)
    case "${XDG_CACHE_HOME:-}" in
        /*) CACHE_HOME="$XDG_CACHE_HOME" ;;
        *) CACHE_HOME="$HOME/.cache" ;;
    esac
    SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
    python3 "$SCRIPT_DIR/../python/umbriel_config.py" theme "$CACHE_HOME/hydra/umbriel-theme.toml"
    ;;

btop)
    CONFIG_FILE="$HOME/.config/btop/btop.conf"

    if [ -f "$CONFIG_FILE" ]; then
        # Check if theme is already set to hydra (flexible spacing)
        if grep -qE '^color_theme\s*=\s*"hydra"' "$CONFIG_FILE"; then
            : # Already correct
        elif grep -qE '^color_theme\s*=' "$CONFIG_FILE"; then
            # Replace existing color_theme line in-place
            sed -i -E 's/^color_theme\s*=.*/color_theme = "hydra"/' "$CONFIG_FILE"
        else
            echo 'color_theme = "hydra"' >>"$CONFIG_FILE"
        fi

        if pgrep -x btop >/dev/null; then
            pkill -SIGUSR2 -x btop
        fi
    else
        echo "Warning: btop config file not found at $CONFIG_FILE" >&2
    fi
    ;;

zathura)
    ZATHURA_INSTANCES=$(dbus-send --session \
        --dest=org.freedesktop.DBus \
        --type=method_call \
        --print-reply \
        /org/freedesktop/DBus \
        org.freedesktop.DBus.ListNames |
        grep -o 'org.pwmt.zathura.PID-[0-9]*')

    for id in $ZATHURA_INSTANCES; do
        dbus-send --session \
            --dest="$id" \
            --type=method_call \
            /org/pwmt/zathura \
            org.pwmt.zathura.ExecuteCommand \
            string:"source"
    done
    ;;

starship)
            PALETTE_FILE="$HOME/.cache/hydra/starship-palette.toml"

            # Respect STARSHIP_CONFIG env var, then fall back to standard lookup order
            if [ -n "$STARSHIP_CONFIG" ]; then
                CONFIG_FILE="$STARSHIP_CONFIG"
            elif [ -f "$HOME/.config/starship.toml" ]; then
                CONFIG_FILE="$HOME/.config/starship.toml"
            elif [ -f "$HOME/.config/starship/starship.toml" ]; then
                CONFIG_FILE="$HOME/.config/starship/starship.toml"
            else
                CONFIG_FILE="$HOME/.config/starship.toml"
            fi

            if [ ! -f "$PALETTE_FILE" ]; then
                echo "Error: Starship palette file not found at $PALETTE_FILE" >&2
                return 1
            fi

            MARKER_BEGIN='# >>> HYDRA STARSHIP PALETTE >>>'
            MARKER_END='# <<< HYDRA STARSHIP PALETTE <<<'

            # Create config file from scratch if it doesn't exist yet
            if [ ! -f "$CONFIG_FILE" ]; then
                mkdir -p "$(dirname "$CONFIG_FILE")"
                {
                    printf 'palette = "hydra"\n\n'
                    printf '%s\n' "$MARKER_BEGIN"
                    cat "$PALETTE_FILE"
                    printf '%s\n' "$MARKER_END"
                } > "$CONFIG_FILE"
                return 0
            fi

            # Follow symlinks so we edit the real file (safe for stow / dotfile managers)
            if [ -L "$CONFIG_FILE" ]; then
                CONFIG_FILE="$(readlink -f "$CONFIG_FILE")"
            fi

            # Set or insert top-level  palette = "hydra"
            if grep -qE '^[[:space:]]*palette[[:space:]]*=' "$CONFIG_FILE"; then
                sed -i -E 's/^([[:space:]]*)palette([[:space:]]*)=.*/\1palette\2= "hydra"/' "$CONFIG_FILE"
            elif grep -qE '^[[:space:]]*"\$schema"' "$CONFIG_FILE"; then
                sed -i '/^[[:space:]]*"\$schema"/a palette = "hydra"' "$CONFIG_FILE"
            else
                sed -i '1i palette = "hydra"' "$CONFIG_FILE"
            fi

            # Remove existing palette block using awk for literal string matching
            # (avoids sed misinterpreting >, #, or other chars in the markers as regex)
            if grep -qF "$MARKER_BEGIN" "$CONFIG_FILE"; then
                awk -v begin="$MARKER_BEGIN" -v end="$MARKER_END" '
                    $0 == begin { skip = 1; next }
                    $0 == end   { skip = 0; next }
                    !skip
                ' "$CONFIG_FILE" > "${CONFIG_FILE}.hydra.tmp" \
                    && mv "${CONFIG_FILE}.hydra.tmp" "$CONFIG_FILE"
            fi

            # Append fresh palette block, ensuring a clean newline boundary
            {
                printf '\n%s\n' "$MARKER_BEGIN"
                cat "$PALETTE_FILE"
                # Guard: ensure palette file ends with newline before closing marker
                tail -c1 "$PALETTE_FILE" | grep -q $'\n' || printf '\n'
                printf '%s\n' "$MARKER_END"
            } >> "$CONFIG_FILE"
            ;;

tmux)
    command -v tmux >/dev/null 2>&1 || exit 0
    case "${XDG_CONFIG_HOME:-}" in
        /*) CONFIG_HOME="$XDG_CONFIG_HOME" ;;
        *) CONFIG_HOME="$HOME/.config" ;;
    esac
    THEME_FILE="$CONFIG_HOME/tmux/themes/hydra.conf"
    [ -f "$THEME_FILE" ] || exit 0
    # -N forbids server creation, including if it exits between these commands.
    if tmux -N has-session >/dev/null 2>&1; then
        tmux -N source-file "$THEME_FILE"
    fi
    ;;

fcitx5)
    # --check addresses only an existing owner, preventing DBus activation.
    if command -v fcitx5-remote >/dev/null 2>&1; then
        fcitx5-remote --check -r >/dev/null 2>&1 || true
    fi
    ;;

bat)
    if command -v bat >/dev/null 2>&1; then
        bat cache --build
    fi
    ;;

*)
    # Handle unknown application names.
    echo "Error: Unknown application '$APP_NAME'." >&2
    exit 1
    ;;
esac
