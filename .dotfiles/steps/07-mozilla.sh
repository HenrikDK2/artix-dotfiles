#!/bin/bash

PROFILE="cl7mquq4.default"
PROFILE2="hnb58kl4.default-release"

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "$0")" && pwd)}"
DOTFILES="$SCRIPT_DIR/files/user/mozilla/firefox"

merge_prefs() {
    local src="$1" dst="$2" skip="$3" key line

    [[ -f "$src" && -f "$dst" ]] || return

    while read -r line; do
        [[ -z "$line" || "$line" == //* ]] && continue

        key=$(grep -oP '(?<=user_pref\(")[^"]+' <<< "$line") || continue
        [[ " $skip " =~ " $key " ]] && continue

        if grep -qF "\"$key\"" "$dst"; then
            sed -i "s|.*\"$key\".*|$line|" "$dst"
        else
            echo "$line" >> "$dst"
        fi
    done < "$src"
}

setup_profile() {
    local base="$1" skip="$2" user="$3" group="$4"

    mkdir -p "$base"

    # Copy Firefox profile metadata
    for file in installs.ini profiles.ini; do
        if [[ -f "$DOTFILES/$file" ]]; then
            cp -f "$DOTFILES/$file" "$base/"
        fi
    done

    # Copy default profile as release profile only if missing
    if [[ ! -d "$base/$PROFILE2" ]]; then
        if [[ -d "$DOTFILES/$PROFILE" ]]; then
            cp -r "$DOTFILES/$PROFILE" "$base/$PROFILE2"
        else
            echo "Missing dotfile profile: $DOTFILES/$PROFILE"
        fi
    fi

    # Also create original profile folder if missing
    if [[ ! -d "$base/original" ]]; then
        if [[ -d "$DOTFILES/$PROFILE" ]]; then
            cp -r "$DOTFILES/$PROFILE" "$base/original"
        else
            echo "Missing dotfile profile: $DOTFILES/$PROFILE"
        fi
    fi

    # Merge prefs and copy chrome
    while IFS= read -r -d '' prefs; do
        target="${prefs%/*}"

        merge_prefs "$DOTFILES/$PROFILE/prefs.js" "$prefs" "$skip"

        [[ "$base" == *"/firefox" ]] || continue

        rm -rf "$target/chrome"

        if [[ -d "$DOTFILES/$PROFILE/chrome" ]]; then
            cp -r "$DOTFILES/$PROFILE/chrome" "$target/"
        fi
    done < <(find "$base" -mindepth 2 -maxdepth 2 -name prefs.js -print0)

    chown -R "$user:$user" "$base"
}

killall firefox firefox-bin thunderbird thunderbird-bin 2>/dev/null

while pgrep -x firefox >/dev/null ||
      pgrep -x firefox-bin >/dev/null ||
      pgrep -x thunderbird >/dev/null ||
      pgrep -x thunderbird-bin >/dev/null; do
    sleep .5
done

for home in /home/*; do
    [[ -d "$home" ]] || continue

    user="${home##*/}"

    [[ "$(getent passwd "$user" | cut -d: -f6)" == "$home" ]] || continue

    group=$(id -gn "$user")

    echo "Processing user: $user"

    setup_profile \
        "$home/.var/app/org.mozilla.firefox/config/mozilla/firefox" \
        "browser.uiCustomization.state" \
        "$user" "$group"

    setup_profile \
        "$home/.config/mozilla/firefox" \
        "browser.uiCustomization.state" \
        "$user" "$group"

    setup_profile \
        "$home/.var/app/org.mozilla.Thunderbird/.thunderbird" \
        "browser.uiCustomization.state toolkit.legacyUserProfileCustomizations.stylesheets" \
        "$user" "$group"

    setup_profile \
        "$home/.thunderbird" \
        "browser.uiCustomization.state toolkit.legacyUserProfileCustomizations.stylesheets" \
        "$user" "$group"

    echo "  ✔ Finished: $user"
done
