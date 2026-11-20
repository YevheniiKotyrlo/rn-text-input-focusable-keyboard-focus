#!/usr/bin/env bash
# Exit 1 while hardware-keyboard Tab, Shift+Tab or D-pad Down lands on a TextInput that sets tabIndex={-1} or
# focusable={false}, on the attached Android device; 0 once Tab and Shift+Tab reach both buttons, D-pad Down the second
# one, and none of them a TextInput; 2 when a walk misses a button it should reach, another view takes focus or a step
# fails.
# Needs adb with one Android device attached (ANDROID_SERIAL picks one of several), node, yarn and a JDK. Shift+Tab
# needs Android 12 (API 31) or newer, for `input keycombination`; on an older device that walk is left out.
set -u

package=com.reproducerapp
button_labels=("first button" "second button")
input_labels=("input with tabIndex -1" "input with focusable false")
# Enough presses for a walk to pass every view on the screen once, the two buttons and the two inputs, and more.
presses=6

fail_step() {
    echo "step failed: $1"
    exit 2
}

# The path as the platform's own programs take it: Git Bash's /c/... becomes C:/... for adb on Windows.
native_path() {
    if command -v cygpath > /dev/null; then
        cygpath -m "$1"
    else
        printf '%s\n' "$1"
    fi
}

# Sets the named variable to a device property, without the carriage return adb's shell ends it with.
read_device_property() {
    local value
    value="$(adb shell getprop "$2")" || fail_step "adb shell getprop $2: ${value}"
    printf -v "$1" '%s' "${value//$'\r'/}"
}

dump_window() {
    adb shell uiautomator dump /sdcard/keyboard-focus-reproducer.xml > /dev/null 2>&1
    adb exec-out cat /sdcard/keyboard-focus-reproducer.xml 2> /dev/null
    adb shell rm -f /sdcard/keyboard-focus-reproducer.xml
}

wait_for_label() {
    local label=$1 attempt hierarchy
    for ((attempt = 1; attempt <= 30; attempt += 1)); do
        hierarchy="$(dump_window)"
        if [[ "${hierarchy}" == *"content-desc=\"${label}\""* ]]; then
            return 0
        fi
        sleep 1
    done
    return 1
}

# Starts the app afresh, so no view holds focus when a walk begins.
launch_app() {
    adb shell am force-stop "${package}" > /dev/null || fail_step "adb shell am force-stop ${package}"
    adb shell am start -W -n "${package}/.MainActivity" > /dev/null || fail_step "starting ${package}"
    wait_for_label "${button_labels[1]}" || fail_step "the app showed no \"${button_labels[1]}\""
}

# Prints the content-desc of the node uiautomator reads as focused, or "(nothing focused)". A dump taken while focus
# moves out of a TextInput can catch no focused node, so a dump with none is taken again, up to three times.
focused_label() {
    local attempt hierarchy node pattern='content-desc="([^"]*)"'
    for ((attempt = 1; attempt <= 3; attempt += 1)); do
        hierarchy="$(dump_window)"
        while IFS= read -r node; do
            if [[ "${node}" == *'focused="true"'* && "${node}" =~ ${pattern} ]]; then
                printf '%s\n' "${BASH_REMATCH[1]}"
                return 0
            fi
        done <<< "${hierarchy//<node/$'\n'<node}"
        sleep 1
    done
    printf '%s\n' "(nothing focused)"
}

is_one_of() {
    local candidate=$1 label
    shift
    for label in "$@"; do
        [[ "${candidate}" == "${label}" ]] && return 0
    done
    return 1
}

press() {
    case "$1" in
        Tab) adb shell input keyevent KEYCODE_TAB > /dev/null ;;
        Shift+Tab) adb shell input keycombination KEYCODE_SHIFT_LEFT KEYCODE_TAB > /dev/null ;;
        "D-pad Down") adb shell input keyevent KEYCODE_DPAD_DOWN > /dev/null ;;
        *) return 1 ;;
    esac
}

# walk <key> <label>...: starts the app afresh and presses the key `presses` times, printing the view that holds focus
# after each press. Sets `walk_verdict` to input (a TextInput took focus), clean (each label given took focus, and no
# TextInput or other view) or other, and `walk_text` to what the walk did.
walk() {
    local key=$1 count label stops=() input_stops="" other_stops="" missing=""
    shift
    launch_app
    echo "== ${key}, ${presses} presses from a fresh launch"
    for ((count = 1; count <= presses; count += 1)); do
        press "${key}" || fail_step "pressing ${key}"
        sleep 1
        label="$(focused_label)"
        echo "  ${key} ${count}: \"${label}\" holds focus"
        stops+=("${label}")
        if is_one_of "${label}" "${input_labels[@]}"; then
            [[ "${input_stops}" == *"\"${label}\""* ]] || input_stops+="${input_stops:+ and }\"${label}\""
        elif ! is_one_of "${label}" "${button_labels[@]}"; then
            [[ "${other_stops}" == *"\"${label}\""* ]] || other_stops+="${other_stops:+ and }\"${label}\""
        fi
    done
    for label in "$@"; do
        is_one_of "${label}" "${stops[@]}" || missing+="${missing:+ and }the ${label}"
    done
    if [[ -n "${other_stops}" ]]; then
        walk_verdict=other
        walk_text="${key} lands on ${other_stops}"
    elif [[ -n "${missing}" ]]; then
        walk_verdict=other
        walk_text="${key} never reaches ${missing}"
    elif [[ -n "${input_stops}" ]]; then
        walk_verdict=input
        walk_text="${key} lands on ${input_stops}"
    else
        walk_verdict=clean
        walk_text="${key} lands on no TextInput"
    fi
}

# Walks Tab and Shift+Tab (API 31 or newer), each of which should reach both buttons, and D-pad Down, which should
# reach the second button, and exits with the verdict.
check_navigation() {
    local sdk=$1 verdicts=() summary=""
    walk Tab "${button_labels[@]}"
    verdicts+=("${walk_verdict}")
    summary+="${walk_text}"
    if [[ "${sdk}" -ge 31 ]]; then
        walk Shift+Tab "${button_labels[@]}"
        verdicts+=("${walk_verdict}")
        summary+="; ${walk_text}"
    else
        echo "== Shift+Tab left out: \`input keycombination\` needs API 31, and this device runs API ${sdk}"
    fi
    walk "D-pad Down" "${button_labels[1]}"
    verdicts+=("${walk_verdict}")
    summary+="; ${walk_text}"

    if is_one_of other "${verdicts[@]}"; then
        echo "SUMMARY: inconclusive: ${summary}"
        exit 2
    fi
    if is_one_of input "${verdicts[@]}"; then
        echo "SUMMARY: a TextInput with tabIndex={-1} or focusable={false} takes keyboard focus: ${summary}"
        exit 1
    fi
    echo "SUMMARY: no TextInput with tabIndex={-1} or focusable={false} takes keyboard focus: ${summary}"
    exit 0
}

main() {
    local here app
    here="$(cd "$(dirname "$0")" && pwd)"
    app="${here}/ReproducerApp"

    local system node_version java_version
    system="$(uname -sm)"
    node_version="$(node --version 2>&1)" || fail_step "node --version: ${node_version}"
    java_version="$(java -version 2>&1)" || fail_step "java -version: ${java_version}"
    echo "${system}, node ${node_version}, ${java_version%%$'\n'*}"

    local device_state
    device_state="$(adb get-state 2>&1)"
    [[ "${device_state}" == "device" ]] || fail_step "adb get-state: ${device_state}"
    local model release sdk abi
    read_device_property model ro.product.model
    read_device_property release ro.build.version.release
    read_device_property sdk ro.build.version.sdk
    read_device_property abi ro.product.cpu.abi
    echo "device: ${model}, Android ${release} (API ${sdk}), ${abi}"

    local install_output react_native_version
    install_output="$(cd "${app}" && yarn install --frozen-lockfile --non-interactive 2>&1)" ||
        { printf '%s\n' "${install_output}" | tail -n 20; fail_step "yarn install"; }
    react_native_version="$(cd "${app}" && node -p 'require("react-native/package.json").version' 2>&1)" ||
        fail_step "reading react-native's version: ${react_native_version}"
    echo "react-native ${react_native_version}"

    echo "== ./gradlew :app:assembleRelease -PreactNativeArchitectures=${abi}"
    local build_output
    build_output="$(cd "${app}/android" && ./gradlew --no-daemon --console=plain :app:assembleRelease \
        "-PreactNativeArchitectures=${abi}" 2>&1)" ||
        { printf '%s\n' "${build_output}" | tail -n 40; fail_step "the release build"; }

    local apk install_result
    apk="$(native_path "${app}/android/app/build/outputs/apk/release/app-release.apk")"
    install_result="$(adb install -r "${apk}" 2>&1)" || fail_step "adb install: ${install_result}"

    check_navigation "${sdk}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
