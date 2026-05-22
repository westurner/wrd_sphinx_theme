#!/bin/sh

## playwrightbrowser.sh

usage() {
    echo "Usage: $0 [BROWSER] [options] [--] [browser arguments...]"
    echo ""
    echo "Wrapper to launch Playwright-downloaded browsers (chromium, firefox, webkit)"
    echo "with optional custom profile directories."
    echo ""
    echo "Positional Browser Shorthand (optional first argument):"
    echo "  firefox, ff, f           Launch Firefox."
    echo "  chrome, ch               Launch Chromium (chrome binary)."
    echo "  chromium, chromi, ci, c  Launch Chromium."
    echo "  webkit, wk, w            Launch WebKit."
    echo ""
    echo "Options:"
    echo "  -h, --help               Show this help message."
    echo "  --pw-browser BROWSER     Specify the browser to run (chromium, firefox, webkit)."
    echo "                           Defaults to PW_BROWSER env var or 'chromium'."
    echo "  --pw-profile PROFILE     Specify a custom profile path."
    echo "                           Defaults to profiles under \$PW_PROFILES_BASE/<browser>."
    echo "  --pw-log FILE            Log stdout/stderr of the browser to a file."
    echo "                           Defaults to PW_LOG_FILE env var if set."
    echo "  --hard-timeout SECONDS   Kill the browser after SECONDS."
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
    echo "  $0 --pw-browser=chromium --pw-log /tmp/browser.log"
    echo "  PW_SELF_CHECK=0 $0 chrome -- --new-window https://example.com"
}

run_with_logging() {
    if command -v bash >/dev/null 2>&1; then
        export PW_LOG_FILE
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
        case "$1" in
            firefox|ff|f)
                shift
                name=firefox
                set -- --pw-browser="$name" "$@"
                ;;
            webkit|wk|w)
                shift
                name=webkit
                set -- --pw-browser="$name" "$@"
                ;;
            chrome|ch)
                shift
                name=chrome
                set -- --pw-browser="$name" "$@"
                ;;
            chromium|chromi|ci|c)
                shift
                name=chromium
                set -- --pw-browser="$name" "$@"
                ;;
        esac
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
    BIN_PATH=$(eval find ~/.cache/ms-playwright $FIND_ARGS -type f -executable 2>/dev/null | sort -r | head -n 1)
    if [ -z "$BIN_PATH" ]; then
        LOCAL_BROWSERS_DIR="${PLAYWRIGHT_BROWSERS_PATH:-$(cd "$(dirname "$0")" && pwd)/.playwright-browsers}"
        if [ -d "$LOCAL_BROWSERS_DIR" ]; then
            BIN_PATH=$(eval find "$LOCAL_BROWSERS_DIR" $FIND_ARGS -type f -executable 2>/dev/null | sort -r | head -n 1)
        fi
    fi

    if [ -z "$BIN_PATH" ]; then
        echo "ERROR: Could not find Playwright binary for browser: $BROWSER" >&2
        exit 1
    fi

    # Argument construction and execution
    if [ -n "$PROFILE_FLAG" ]; then
        if [ "$BROWSER" = "firefox" ]; then
            set -- "$BIN_PATH" "$PROFILE_FLAG" "$PROFILE_DIR" "$@"
        else
            set -- "$BIN_PATH" "${PROFILE_FLAG}${PROFILE_DIR}" "$CHROME_MODEL_FLAG" "$CHROME_SIGNIN_FLAG" "$@"
        fi
    else
        set -- "$BIN_PATH" "$@"
    fi

    if [ -n "$HARD_TIMEOUT" ]; then
        echo "INFO: Running browser with --hard-timeout=$HARD_TIMEOUT seconds:" >&2
        set -- timeout -v "$HARD_TIMEOUT" "$@"
    else
        echo "INFO: Running browser"
    fi

    if [ "$SELF_CHECK" -eq 1 ]; then
        {
            echo "INFO: Self-check"
            echo "  Browser: $BROWSER"
            echo "  Browser binary: $BIN_PATH"
            echo "  Profile base: $PROFILES_BASE"
            echo "  Profile dir: $PROFILE_DIR"
            echo "  Log file: ${PW_LOG_FILE:-<none>}"
            echo "  Hard timeout: ${HARD_TIMEOUT:-<none>}"
            echo "  Launch command:"
            printf "    %s\n" "$*"
        } >&2
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
