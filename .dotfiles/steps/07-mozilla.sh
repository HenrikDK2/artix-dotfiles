#!/bin/bash
set -u

PROFILE="cl7mquq4.default"
PROFILE2="hnb58kl4.default-release"

DOTFILES="$SCRIPT_DIR/files/user/mozilla/firefox"

# Extract the user_pref key from a line, no subprocess spawned.
# Sets $key; returns 1 if the line isn't a user_pref line.
extract_key() {
    if [[ $1 =~ user_pref\(\"([^\"]+)\" ]]; then
        key="${BASH_REMATCH[1]}"
        return 0
    fi
    return 1
}

# Parse a prefs.js file into a nameref associative array (key -> full line),
# skipping any keys listed in $skip. Done once per source file per caller,
# instead of once per destination profile.
load_prefs() {
    local src="$1" skip="$2"
    local -n out_arr="$3"
    local line key

    [[ -f "$src" ]] || return

    local -A skip_set=()
    local s
    for s in $skip; do skip_set["$s"]=1; done

    while IFS= read -r line; do
        [[ -z "$line" || "$line" == //* ]] && continue
        extract_key "$line" || continue
        [[ -n "${skip_set[$key]+x}" ]] && continue
        out_arr["$key"]="$line"
    done < "$src"
}

# Merge pre-parsed overrides into a single destination prefs.js.
merge_prefs() {
    local dst="$1"
    local -n overrides="$2"

    [[ -f "$dst" ]] || return
    [[ ${#overrides[@]} -eq 0 ]] && return

    local tmp line key
    local -A written=()
    tmp=$(mktemp)

    while IFS= read -r line; do
        if extract_key "$line" && [[ -n "${overrides[$key]+x}" ]]; then
            printf '%s\n' "${overrides[$key]}" >> "$tmp"
            written["$key"]=1
        else
            printf '%s\n' "$line" >> "$tmp"
        fi
    done < "$dst"

    # Append overrides that never existed in the destination
    for key in "${!overrides[@]}"; do
        [[ -n "${written[$key]+x}" ]] && continue
        printf '%s\n' "${overrides[$key]}" >> "$tmp"
    done

    mv "$tmp" "$dst"
}

setup_profile() {
    local base="$1" skip="$2" user="$3" group="$4"

    mkdir -p "$base"

    # Copy Firefox profile metadata
    local file
    for file in installs.ini profiles.ini; do
        [[ -f "$DOTFILES/$file" ]] && cp -f "$DOTFILES/$file" "$base/"
    done

    # Copy default profile into any missing target dirs
    local dest
    for dest in "$base/$PROFILE2" "$base/original"; do
        [[ -d "$dest" ]] && continue
        if [[ -d "$DOTFILES/$PROFILE" ]]; then
            cp -r "$DOTFILES/$PROFILE" "$dest"
        else
            echo "Missing dotfile profile: $DOTFILES/$PROFILE"
        fi
    done

    # Parse the source prefs.js ONCE for this base, reused for every
    # destination profile found below (previously re-parsed every time).
    local -A src_overrides=()
    load_prefs "$DOTFILES/$PROFILE/prefs.js" "$skip" src_overrides

    # Merge prefs and copy chrome
    local prefs target
    while IFS= read -r -d '' prefs; do
        target="${prefs%/*}"

        merge_prefs "$prefs" src_overrides

        [[ "$base" == *"/firefox" ]] || continue

        rm -rf "$target/chrome"
        [[ -d "$DOTFILES/$PROFILE/chrome" ]] && cp -r "$DOTFILES/$PROFILE/chrome" "$target/"
    done < <(find "$base" -mindepth 2 -maxdepth 2 -name prefs.js -print0)

    chown -R "$user:$group" "$base"
}

while pgrep -x firefox >/dev/null ||
      pgrep -x firefox-bin >/dev/null ||
      pgrep -x thunderbird >/dev/null ||
      pgrep -x thunderbird-bin >/dev/null; do
    killall firefox firefox-bin thunderbird thunderbird-bin 2>/dev/null
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
