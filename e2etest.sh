#!/bin/sh

# e2etest.sh: Build and run Playwright e2e tests (locally or in Podman)

set -e

# Default settings
IMAGE_NAME="${IMAGE_NAME:-"localhost/e2e-test:latest"}"
PODMAN="${PODMAN:-"podman"}"
DO_BUILD="${DO_BUILD:-}"
DO_IN_CONTAINER="${DO_IN_CONTAINER:-}"
DO_INSTALL="${DO_INSTALL:-0}"
PLAYWRIGHT_BROWSERS_PATH="${PWD}/.playwright-browsers"
CONTAINER_USER="${CONTAINER_USER:-"appuser"}"

usage() {
    echo "Usage: $0 [options] [playwright-args...]"
    echo ""
    echo "Options:"
    echo "  --install       Install Playwright browsers locally to .playwright-browsers (needed for --on-host)."
    echo ""
    echo "  --on-host       Run tests locally on the host (Default)."
    echo ""
    echo "  --in-container  Run tests inside a Podman container."
    echo "  --build         Force rebuild of the container image (only for --in-container)."
    echo "  --no-build      Skip building the container image (only for --in-container)."
    echo ""
    echo "  -h/--help       Show this help message."
    echo ""
    echo "Environment Variables:"
    echo "  DO_INSTALL=1       Equivalent to --install"
    echo "  DO_IN_CONTAINER=1  Equivalent to --in-container"
    echo "  DO_BUILD=1         Equivalent to --build"
    echo "  DO_BUILD=0         Equivalent to --no-build"
    echo "  PODMAN             Override podman executable"
    echo "  CONTAINER_USER     Override user inside container (Default: appuser)"
    echo "  PLAYWRIGHT_BROWSERS_PATH  Override path to Playwright browsers (Default: \${PWD}/.playwright-browsers)"
}

is_container() {
    # Check for container environment files
    if [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then
        return 0
    fi
    return 1
}

fix_node_modules() {
    # If e2e/node_modules exists, it conflicts with root node_modules for playwright config
    if [ -d "e2e/node_modules" ]; then
        echo "NOTE: there are both e2e/node_modules and root node_modules directories"

        # Try to remove the directory itself initially
        # echo " Cleaning it..."
        # if ! rm -rf e2e/node_modules 2>/dev/null; then
        #      # If failed (e.g. mount point), remove contents
        #      find e2e/node_modules -mindepth 1 -delete
        # fi
    fi
}

install_browsers() {
    echo "## Installing Playwright browsers to ${PLAYWRIGHT_BROWSERS_PATH}..."
    export PLAYWRIGHT_BROWSERS_PATH
    mkdir -p "${PLAYWRIGHT_BROWSERS_PATH}"
    # Install browsers defined in config (just what is needed)
    (set -x; npx playwright install --list | tee "${PLAYWRIGHT_BROWSERS_PATH}/.install.0_before.txt")
    (set -x; npx playwright install chromium | tee -a "${PLAYWRIGHT_BROWSERS_PATH}/install.log")
    (set -x; npx playwright install --list | tee "${PLAYWRIGHT_BROWSERS_PATH}/.install.1_after.txt")
    
    # We ignore the error from diff because we want to proceed anyway, but exit code 1 means differences found
    (set -x; diff -Nau "${PLAYWRIGHT_BROWSERS_PATH}/.install.0_before.txt" "${PLAYWRIGHT_BROWSERS_PATH}/.install.1_after.txt" || true) 
}

e2etest_main() {
    # Initialize variables
    do_in_container="$DO_IN_CONTAINER"
    do_build="$DO_BUILD"
    do_install="$DO_INSTALL"
    test_args=""

    # Argument parsing loop
    for arg in "$@"; do
        case "$arg" in
             --install)
                do_install=1
                ;;
            --in-container)
                do_in_container=1
                ;;
            --on-host)
                do_in_container=0
                ;;
            --build)
                do_build=1
                ;;
            --no-build)
                do_build=0
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                test_args="$test_args $arg"
                ;;
        esac
    done
    
    # Trim leading space
    test_args=$(echo "$test_args" | sed 's/^ *//')

    if [ "$do_install" -eq 1 ]; then
        install_browsers
        if [ -z "$test_args" ] && [ -z "$do_in_container" ]; then
             exit 0
        fi
    fi

    # Smart Defaults Logic
    if [ -z "$do_in_container" ]; then
        if is_container; then
            echo "## Environment: Inside Container. Defaulting to --on-host (local execution)."
            do_in_container=0
        elif [ -n "$GITHUB_ACTIONS" ] || [ -n "$CI" ]; then
            echo "## Environment: CI detected. Defaulting to --on-host."
            do_in_container=0
        else
            echo "## Environment: Workstation detected. Defaulting to --in-container."
            do_in_container=1
        fi
    fi

    if [ "$do_in_container" -eq 1 ]; then
        project_name="$(basename "$PWD")"
        run_in_container "$do_build" "$test_args" "$project_name"
    else
        run_on_host "$test_args"
    fi
}

run_in_container() {
    should_build="$1"
    args="$2"
    project_name="$3"
    
    if [ -z "$project_name" ]; then
        echo "## Error: project_name must be specified."
        exit 1
    fi

    if is_container; then
        echo "## Error: Attempting to start a container from within a container."
        echo "## Please use --on-host or allow auto-detection."
        exit 1
    fi

    # Auto-detect build if not specified
    if [ -z "$should_build" ]; then
        if $PODMAN image exists "${IMAGE_NAME}"; then
            echo "## Image '${IMAGE_NAME}' found. Skipping build."
            should_build=0
        else
            echo "## Image '${IMAGE_NAME}' not found. Will build."
            should_build=1
        fi
    fi

    if [ "$should_build" -eq 1 ]; then
        echo "## Building Docker image..."
        $PODMAN build --security-opt=label=disable -f Dockerfile.e2e -t "${IMAGE_NAME}" .
    fi

    echo "## Running container..."
    BROWSER_MOUNT=""
    if [ -d "${PLAYWRIGHT_BROWSERS_PATH}" ]; then
         echo "## Mounting local browsers from ${PLAYWRIGHT_BROWSERS_PATH}"
         BROWSER_MOUNT="-v ${PLAYWRIGHT_BROWSERS_PATH}:/home/${CONTAINER_USER}/.cache/ms-playwright"
    fi

    (set -x; $PODMAN run --rm -it --replace \
        --security-opt=label=disable \
        -v "${PWD}:/workspaces/${project_name}" \
        -v "${PWD}/e2e-logs:/workspaces/${project_name}/e2e-logs" \
        -v /workspaces/${project_name}/e2e/node_modules \
        $BROWSER_MOUNT \
        --user="${CONTAINER_USER}" \
        --userns=keep-id \
        --name e2e-test "${IMAGE_NAME}" \
        sh -c "cd /workspaces/${project_name} && ./e2etest.sh $args")
}

run_on_host() {
    args="$1"
    
    # Environment Setup
    if is_container; then
        echo "## Detected container environment. Using system browsers."
        unset PLAYWRIGHT_BROWSERS_PATH
    else
        # On Host: Use local browser path
        export PLAYWRIGHT_BROWSERS_PATH
        echo "## Running tests on host with PLAYWRIGHT_BROWSERS_PATH=$PLAYWRIGHT_BROWSERS_PATH"
    fi
    
    # Ensure no duplicate node_modules
    fix_node_modules
    
    echo "## Args: $args"
    
    # Debug info
    if is_container; then
        whoami
        pwd
    fi

    echo "## Executing: npx playwright test $args"
    (set -x -e;
        npx playwright test --output=e2e-logs $args;
        echo "# Note: coverage output is in coverage/"
    )
}

# Start execution
e2etest_main "$@"
