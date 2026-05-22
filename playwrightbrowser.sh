#!/bin/bash

## playwrightbrowser.sh

usage() {
    echo "Usage: $0 [BROWSER] [options] [--] [browser arguments...]"
    echo ""
    echo "Wrapper to launch Playwright-downloaded browsers (chromium, firefox, webkit)"
    echo "with optional custom profile directories."
    echo ""
    echo "Positional Browser Shorthand (optional first argument):"
    echo "  firefox, ff, f           Launch Firefox."
    echo "  chrome, cr               Launch Chromium (chrome binary)."
    echo "  chromium, chromi, ci, c  Launch Chromium."
    echo "  webkit, wk, w            Launch WebKit."
    echo ""
    echo "Options:"
    echo "  -h, --help               Show this help message."
    echo "  --pw-browser BROWSER     Specify the browser to run (chromium, firefox, webkit)."
    echo "                           Defaults to PW_BROWSER env var or 'chromium'."
    echo "  --browser BROWSER        Browser option with positional shorthand support"
    echo "                           (for example: ff, ch, ci, wk)."
    echo "  --pw-profile PROFILE     Specify a custom profile path."
    echo "                           Defaults to profiles under \$PW_PROFILES_BASE/<browser>."
    echo "  --pw-log FILE            Log stdout/stderr of the browser to a file."
    echo "                           Defaults to PW_LOG_FILE env var if set."
    echo "  --hard-timeout SECONDS   Kill the browser after SECONDS."
    echo "  --test                   Run TAP-compliant unit tests covering this script."
    echo "  --pw-self-check          Print resolved paths and launch command before running (default)."

    echo "  --no-pw-self-check       Suppress self-check output."
    echo ""
    echo "Environment Variables:"
    echo "  PW_BROWSER               Default browser to use (default: chromium)."
    echo "  PW_PROFILES_BASE         Base directory for browser profiles."
    echo "                           Defaults to <script-dir>/.browser-profiles."
    echo "  PW_SELF_CHECK            Set to 0/false/no/off to disable self-check output (default: 1)."
    echo "  PW_LOG_FILE              File to redirect browser stdout and stderr to."
    echo "  PLAYWRIGHT_BROWSERS_PATH Custom Playwright browser installation path."
    echo ""
    echo "Volume Mounting:"
    echo "  To persist profiles across container runs, mount a volume to the profile base path:"
    echo "    podman run -v \"\$PWD/.browser-profiles:/workspaces/project/.browser-profiles\" ..."
    echo "  Or:"
    echo "    podman run -v \"\${XDG_CACHE_HOME:-\$HOME/.cache}/playwright-profiles:/workspaces/project/.browser-profiles\" ..."
    echo ""
    echo "Examples:"
    echo "  $0 firefox"
    echo "  $0 ff --hard-timeout 10"
    echo "  $0 --browser=ff --hard-timeout 10"
    echo "  $0 --pw-browser=chromium --pw-log /tmp/browser.log"
    echo "  PW_SELF_CHECK=0 $0 chrome -- --new-window https://example.com"
}

run_with_logging() {
    if command -v bash >/dev/null 2>&1; then
        export PW_LOG_FILE
        printf "PW_LOG_FILE=%q\n" "${PW_LOG_FILE}"
        # Use bash -c to evaluate advanced process substitution, hiding the syntax from POSIX parsers
        bash -c '
        (set -x; "$@") \
            > >(tee >(awk '\''{print "[STDOUT]", $0; fflush()}'\'' >> "$PW_LOG_FILE")) \
            2> >(tee >(awk '\''{print "[STDERR]", $0; fflush()}'\'' >> "$PW_LOG_FILE") >&2)
        ' _ "$@"
    else
        # Fallback for strict POSIX shells where bash is unavailable
        "$@" 2>&1 | tee -a "$PW_LOG_FILE"
    fi
}

escape_cmd_with_args() {
    local arg
    local sep=""

    for arg in "$@"; do
        printf "%s" "$sep"
        if [ -z "$arg" ]; then
            printf "''"
        else
            printf "%q" "$arg"
        fi
        sep=" "
    done
}

browser_from_shorthand() {
    case "$1" in
        firefox|ff|f)
            printf "%s" "firefox"
            ;;
        webkit|wk|w)
            printf "%s" "webkit"
            ;;
        chrome|cr)
            printf "%s" "chrome"
            ;;
        chromium|chromi|ci|c)
            printf "%s" "chromium"
            ;;
        *)
            return 1
            ;;
    esac
}

browser_with_shorthand() {
    local browser="$1"
    local mapped_browser

    if mapped_browser="$(browser_from_shorthand "$browser")"; then
        printf "%s" "$mapped_browser"
    else
        printf "%s" "$browser"
    fi
}

run_tap_tests() {
    # Setup a clean temporary directory for mock ms-playwright binaries
    MOCK_DIR=$(mktemp -d)

    mkdir -p "$MOCK_DIR/firefox"
    cat << 'EOF' > "$MOCK_DIR/firefox/firefox"
#!/bin/sh
echo "MOCK FIREFOX RUN WITH: $*"
EOF
    chmod +x "$MOCK_DIR/firefox/firefox"

    cat << 'EOF' > "$MOCK_DIR/chrome"
#!/bin/sh
echo "MOCK CHROME RUN WITH: $*"
EOF
    chmod +x "$MOCK_DIR/chrome"

    cat << 'EOF' > "$MOCK_DIR/pw_run.sh"
#!/bin/sh
echo "MOCK WEBKIT RUN WITH: $*"
EOF
    chmod +x "$MOCK_DIR/pw_run.sh"

    export PLAYWRIGHT_BROWSERS_PATH="$MOCK_DIR"

    cleanup() {
        rm -rf "$MOCK_DIR"
    }
    trap cleanup EXIT

    # TAP execution and plan
    total_tests=16
    echo "1..$total_tests"

    test_num=0

    assertequal() {
        test_num=$((test_num + 1))
        local expected="$1"
        local actual="$2"
        local desc="$3"
        if [ "$expected" = "$actual" ]; then
            echo "ok $test_num - $desc"
        else
            echo "not ok $test_num - $desc"
            echo "  Expected: '$expected'"
            echo "  Actual:   '$actual'"
        fi
    }

    get_resolved_var() {
        local output="$1"
        local var_name="$2"
        echo "$output" | grep "^${var_name}=" | head -n 1 | cut -d'=' -f2- | tr -d "'"
    }

    # Test 1: Positional shorthand ff resolves to firefox
    output=$(PW_SELF_CHECK=1 "$0" ff --hard-timeout=1 2>&1)
    browser=$(get_resolved_var "$output" "BROWSER")
    assertequal "firefox" "$browser" "Positional shorthand 'ff' maps to 'firefox'"

    # Test 2: Positional shorthand chrome resolves to chrome
    output=$(PW_SELF_CHECK=1 "$0" chrome --hard-timeout=1 2>&1)
    browser=$(get_resolved_var "$output" "BROWSER")
    assertequal "chrome" "$browser" "Positional shorthand 'chrome' maps to 'chrome'"

    # Test 3: Positional shorthand wk resolves to webkit
    output=$(PW_SELF_CHECK=1 "$0" wk --hard-timeout=1 2>&1)
    browser=$(get_resolved_var "$output" "BROWSER")
    assertequal "webkit" "$browser" "Positional shorthand 'wk' maps to 'webkit'"

    # Test 4: --browser=ff resolves to firefox
    output=$(PW_SELF_CHECK=1 "$0" --browser=ff --hard-timeout=1 2>&1)
    browser=$(get_resolved_var "$output" "BROWSER")
    assertequal "firefox" "$browser" "--browser=ff resolves to 'firefox'"

    # Test 5: --browser wk resolves to webkit
    output=$(PW_SELF_CHECK=1 "$0" --browser wk --hard-timeout=1 2>&1)
    browser=$(get_resolved_var "$output" "BROWSER")
    assertequal "webkit" "$browser" "--browser wk resolves to 'webkit'"

    # Test 6: --pw-browser=ff does NOT use shorthand normalization (remains literal 'ff')
    output=$(PW_SELF_CHECK=1 "$0" --pw-browser=ff --hard-timeout=1 2>&1)
    browser=$(get_resolved_var "$output" "BROWSER")
    assertequal "ff" "$browser" "--pw-browser=ff does not apply shorthand normalization"

    # Test 7: profile options are properly appended to execution for firefox
    output=$(PW_SELF_CHECK=1 "$0" --browser=ff --pw-profile=/tmp/my-ff-prof --hard-timeout=1 2>&1)
    profile_dir=$(get_resolved_var "$output" "PROFILE_DIR")
    assertequal "/tmp/my-ff-prof" "$profile_dir" "Profile directory option is correctly set"

    # Test 8: ensure the mock runner is actually executed with correct profile args for firefox
    run_line=$(echo "$output" | grep "MOCK FIREFOX RUN WITH:")
    expected_run_line="MOCK FIREFOX RUN WITH: --profile /tmp/my-ff-prof"
    assertequal "$expected_run_line" "$run_line" "Firefox mock executable called with profile parameters"

    # Test 9: default browser maps to chromium if not specified
    output=$(PW_SELF_CHECK=1 "$0" --hard-timeout=1 2>&1)
    browser=$(get_resolved_var "$output" "BROWSER")
    assertequal "chromium" "$browser" "Default browser defaults to chromium"

    # Test 10: `--pw-log` redirects standard output & stderr to file
    TMP_LOG=$(mktemp)
    # Exclude self check so logging is captured directly
    PW_SELF_CHECK=0 "$0" ff --pw-log="$TMP_LOG" --hard-timeout=1 2>&1
    log_content=$(cat "$TMP_LOG")
    rm -f "$TMP_LOG"
    assertequal "1" "$(echo "$log_content" | grep -c "MOCK FIREFOX RUN WITH:")" "File logging captures stdout and stderr correctly"

    # Test 11: Fail fast when no browser binary can be found
    # Set PLAYWRIGHT_BROWSERS_PATH to an empty folder to force lookup failure
    EMPTY_DIR=$(mktemp -d)
    output=$(PLAYWRIGHT_BROWSERS_PATH="$EMPTY_DIR" HOME=/nonexistent "$0" ff 2>&1)
    rm -rf "$EMPTY_DIR"
    assertequal "ERROR: Could not find Playwright binary for browser: firefox" "$(echo "$output" | tail -n 1)" "Fail fast when browser executable is missing"

    # Test 12: WebKit specific arguments & resolution
    output=$(PW_SELF_CHECK=1 "$0" wk --hard-timeout=1 2>&1)
    browser_bin=$(get_resolved_var "$output" "BROWSER_BIN")
    # Verify it matches the WebKit mock mini-browser executable
    assertequal "MOCK WEBKIT RUN WITH: " "$(PW_SELF_CHECK=0 PW_LOG_FILE= "$0" wk --hard-timeout=1 2>&1 | grep -v "^INFO:" | grep -v "^+")" "WebKit executes the corrected mock executable"

    # Test 13: Chromium specific features & arguments
    output=$(PW_SELF_CHECK=1 "$0" chrome --hard-timeout=1 2>&1)
    run_line=$(echo "$output" | grep "MOCK CHROME RUN WITH:")
    # Verify Chromium-specific disable flags are appended accurately
    assertequal "MOCK CHROME RUN WITH: --user-data-dir=/workspaces/wrd-sphinx-theme/.browser-profiles/chrome --disable-features=OptimizationGuideOnDeviceModel --disable-sync" "$run_line" "Chromium receives sync and optimization-guide model disable flags"

    # Test 14: Environment variable override `PW_BROWSER`
    output=$(PW_SELF_CHECK=1 PW_BROWSER=webkit "$0" --hard-timeout=1 2>&1)
    browser=$(get_resolved_var "$output" "BROWSER")
    assertequal "webkit" "$browser" "PW_BROWSER environment variable selects default browser"

    # Test 15: `PW_SELF_CHECK=0` suppresses informational output
    # Clear PW_LOG_FILE to avoid run_with_logging logging lines and turn off xtrace inside mock script
    output=$(PW_SELF_CHECK=0 PW_LOG_FILE= "$0" ff --hard-timeout=1 2>&1 | grep -v "^+")
    info_lines=$(echo "$output" | grep -c "^INFO:")
    assertequal "0" "$info_lines" "PW_SELF_CHECK=0 suppresses self-check informational lines"

    # Test 16: `--hard-timeout` wrapping kills slow browsers
    SLOW_DIR=$(mktemp -d)
    cat << 'EOF' > "$SLOW_DIR/chrome"
#!/bin/sh
sleep 10
EOF
    chmod +x "$SLOW_DIR/chrome"
    start_time=$(date +%s)
    PLAYWRIGHT_BROWSERS_PATH="$SLOW_DIR" "$0" chrome --hard-timeout=1 2>&1
    end_time=$(date +%s)
    rm -rf "$SLOW_DIR"
    elapsed=$((end_time - start_time))
    # Assert elapsed time is short (under 5 seconds) rather than waiting 10 full seconds
    is_bounded="0"
    if [ "$elapsed" -lt 5 ]; then
        is_bounded="1"
    fi
    assertequal "1" "$is_bounded" "--hard-timeout forces termination of slow scripts"
}

main() {
    BROWSER="${PW_BROWSER:-chromium}"
    SELF_CHECK_RAW="${PW_SELF_CHECK:-1}"
    case "$SELF_CHECK_RAW" in
        0|false|FALSE|no|NO|off|OFF)
            SELF_CHECK=0
            ;;
        *)
            SELF_CHECK=1
            ;;
    esac
    # Default volume mount friendly directory inside the workspace/repo
    DEFAULT_BASE="$(cd "$(dirname "$0")" && pwd)/.browser-profiles"
    PROFILES_BASE="${PW_PROFILES_BASE:-$DEFAULT_BASE}"
    PROFILE_DIR=""

    # Positional shorthand: allow first arg as browser name.
    if [ $# -gt 0 ]; then
        if BROWSER_FROM_ARG="$(browser_from_shorthand "$1")"; then
            shift
            BROWSER="$BROWSER_FROM_ARG"
        fi
    fi

    # Parse wrapper arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            --pw-browser)
                BROWSER="$2"
                shift 2
                ;;
            --pw-browser=*)
                BROWSER="${1#*=}"
                shift
                ;;
            --browser)
                BROWSER="$(browser_with_shorthand "$2")"
                shift 2
                ;;
            --browser=*)
                BROWSER="$(browser_with_shorthand "${1#*=}")"
                shift
                ;;
            --pw-profile)
                PROFILE_DIR="$2"
                shift 2
                ;;
            --pw-profile=*)
                PROFILE_DIR="${1#*=}"
                shift
                ;;
            --pw-log)
                PW_LOG_FILE="$2"
                shift 2
                ;;
            --pw-log=*)
                PW_LOG_FILE="${1#*=}"
                shift
                ;;
            --hard-timeout)
                HARD_TIMEOUT="$2"
                shift 2
                ;;
            --hard-timeout=*)
                HARD_TIMEOUT="${1#*=}"
                shift
                ;;
            --test)
                run_tap_tests
                exit 0
                ;;
            --pw-self-check)
                SELF_CHECK=1
                shift
                ;;

            --no-pw-self-check)
                SELF_CHECK=0
                shift
                ;;
            --)
                shift
                break
                ;;
            *)
                # Stop parsing at the first non-wrapper argument
                break
                ;;
        esac
    done

    # Default to placing profiles under the base directory
    if [ -z "$PROFILE_DIR" ]; then
        PROFILE_DIR="$PROFILES_BASE/$BROWSER"
    fi

    # Ensure profile directory exists for volume mounts
    if ! mkdir -p "$PROFILE_DIR"; then
        echo "ERROR: Could not create profile directory: $PROFILE_DIR" >&2
        exit 1
    fi

    case "$BROWSER" in
        firefox)
            FIND_ARGS="-path */firefox/firefox"
            PROFILE_FLAG="--profile"
            CHROME_MODEL_FLAG=""
            ;;
        webkit)
            FIND_ARGS="-name pw_run.sh -o -name MiniBrowser"
            # WebKit driver handles profiles differently, omit for now.
            PROFILE_FLAG=""
            CHROME_MODEL_FLAG=""
            ;;
        *)
            FIND_ARGS="-name chrome"
            PROFILE_FLAG="--user-data-dir="
            CHROME_MODEL_FLAG="--disable-features=OptimizationGuideOnDeviceModel"
            CHROME_SIGNIN_FLAG="--disable-sync"
            ;;
    esac

    # Find the browser executable
    BROWSER_BIN=""
    if [ -n "$PLAYWRIGHT_BROWSERS_PATH" ] && [ -d "$PLAYWRIGHT_BROWSERS_PATH" ]; then
        BROWSER_BIN=$(eval find "$PLAYWRIGHT_BROWSERS_PATH" $FIND_ARGS -type f -executable 2>/dev/null | sort -r | head -n 1)
    fi
    if [ -z "$BROWSER_BIN" ]; then
        BROWSER_BIN=$(eval find ~/.cache/ms-playwright $FIND_ARGS -type f -executable 2>/dev/null | sort -r | head -n 1)
    fi
    if [ -z "$BROWSER_BIN" ]; then
        LOCAL_BROWSERS_DIR="$(cd "$(dirname "$0")" && pwd)/.playwright-browsers"
        if [ -d "$LOCAL_BROWSERS_DIR" ]; then
            BROWSER_BIN=$(eval find "$LOCAL_BROWSERS_DIR" $FIND_ARGS -type f -executable 2>/dev/null | sort -r | head -n 1)
        fi
    fi

    if [ -z "$BROWSER_BIN" ]; then
        echo "ERROR: Could not find Playwright binary for browser: $BROWSER" >&2
        exit 1
    fi

    # Argument construction and execution
    if [ -n "$PROFILE_FLAG" ]; then
        if [ "$BROWSER" = "firefox" ]; then
            set -- "$BROWSER_BIN" "$PROFILE_FLAG" "$PROFILE_DIR" "$@"
        else
            set -- "$BROWSER_BIN" "${PROFILE_FLAG}${PROFILE_DIR}" "$CHROME_MODEL_FLAG" "$CHROME_SIGNIN_FLAG" "$@"
        fi
    else
        set -- "$BROWSER_BIN" "$@"
    fi

    if [ "$SELF_CHECK" -eq 1 ]; then
        if [ -n "$HARD_TIMEOUT" ]; then
            echo "INFO: Running browser with --hard-timeout=$HARD_TIMEOUT seconds:" >&2
            set -- timeout -v "$HARD_TIMEOUT" "$@"
        else
            echo "INFO: Running browser" >&2
        fi
        {
            echo   "INFO: Self-check"
            printf "BROWSER=%q\n" "$BROWSER"
            printf "BROWSER_BIN=%q\n" "$BROWSER_BIN"
            printf "PROFILES_BASE=%q\n" "$PROFILES_BASE"
            printf "PROFILE_DIR=%q\n" "$PROFILE_DIR"
            printf "PW_LOG_FILE=%q\n" ${PW_LOG_FILE:+"${PW_LOG_FILE}"}
            printf "HARD_TIMEOUT=%q\n" ${HARD_TIMEOUT:+"${HARD_TIMEOUT}"}
            printf "_PWLAUNCHCMDQ=%q\n" "${*}";
            printf "_PWLAUNCHCMD_='"
            escape_cmd_with_args "$@"
            printf "'\n"
            echo
        } >&2
    else
        if [ -n "$HARD_TIMEOUT" ]; then
            set -- timeout -v "$HARD_TIMEOUT" "$@"
        fi
    fi

    set -x

    if [ -n "$PW_LOG_FILE" ]; then
        mkdir -p "$(dirname "$PW_LOG_FILE")"
        run_with_logging "$@"
    else
        exec "$@"
    fi
}

main "$@"
