#!/bin/bash

# Exit immediately if any command fails
set -e

JSON_FILE="old.json"
MAIN_DIR=$(pwd)

# Check if JSON file exists
if [ ! -f "$MAIN_DIR/$JSON_FILE" ]; then
    echo "❌ Error: $MAIN_DIR/$JSON_FILE not found."
    exit 1
fi

# Ensure jq is installed
if ! command -v jq &> /dev/null; then
    echo "❌ Error: 'jq' is required to run this script. Please install it."
    exit 1
fi

if [ ! -d "libretro-common" ]; then
    git clone https://github.com/Data-Frog-Central/libretro-common --branch Multicore
    sed -i 's|.*CFLAGS += -I../../include.*|CFLAGS += -I../include|g' libretro-common/Makefile
fi

if [ "$#" -gt 0 ]; then
    CORES=""
    for TARGET in "$@"; do
        CORE_EXISTS=$(jq -e "has(\"$TARGET\")" "$MAIN_DIR/$JSON_FILE" 2>/dev/null || echo "false")
        if [ "$CORE_EXISTS" != "true" ]; then
            echo "Error: Core '$TARGET' not found in $MAIN_DIR/$JSON_FILE."
            echo "Available cores: $(jq -r 'keys | join(", ")' "$MAIN_DIR/$JSON_FILE")"
            exit 1
        fi
        CORES="$CORES $TARGET"
    done
    echo "Targets set to: $CORES"
else
    CORES=$(jq -r 'keys[]' "$MAIN_DIR/$JSON_FILE")
    echo "No targets specified. Processing all configured cores..."
fi

for CORE in $CORES; do
    echo "========================================="
    echo " Processing: $CORE"
    echo "========================================="

    ### Extract Mandatory Keys ###
    SOURCE=$(jq -r ".\"$CORE\".source // \"\"" "$MAIN_DIR/$JSON_FILE")
    DIRECTORY=$(jq -r ".\"$CORE\".directory // \"\"" "$MAIN_DIR/$JSON_FILE")
    MAKEFILE_DIRECTORY=$(jq -r ".\"$CORE\".make.directory // \"\"" "$MAIN_DIR/$JSON_FILE")
    BRANCH=$(jq -r ".\"$CORE\".branch // \"master\"" "$MAIN_DIR/$JSON_FILE") # defaults to master
    OUTPUT=$(jq -r ".\"$CORE\".output // \"\"" "$MAIN_DIR/$JSON_FILE")

    if [ -z "$SOURCE" ] || [ -z "$DIRECTORY" ]; then
        echo "Error: '$CORE' is missing required fields ('source' or 'directory'). Skipping..."
        continue
    fi

    MAKEFILE_DIRECTORY=${MAKEFILE_DIRECTORY:-$DIRECTORY}

    ### Git Clone and Checkout Setup ###
    if [ ! -d "$DIRECTORY" ]; then
        echo "--> Cloning repository..."
        git clone --recursive --shallow-submodules "$SOURCE" "$DIRECTORY"

        cd "$DIRECTORY"

        echo "--> Checking out branch/commit: $BRANCH"
        git checkout "$BRANCH"

        ### Run Patch Commands ###
        PATCH_CMD_COUNT=$(jq ".\"$CORE\".commands.\"patch-cmds\" // [] | length" "$MAIN_DIR/$JSON_FILE")
        if [ "$PATCH_CMD_COUNT" -gt 0 ]; then
            for ((i=0; i<PATCH_CMD_COUNT; i++)); do
                CMD=$(jq -r ".\"$CORE\".commands.\"patch-cmds\"[$i]" "$MAIN_DIR/$JSON_FILE")
                echo "--> Running patch-cmds: $CMD"
                eval "$CMD"
            done
        fi
    else 
        cd "$DIRECTORY"
    fi

    ### Run Pre-Make Commands ###
    PRE_CMD_COUNT=$(jq ".\"$CORE\".commands.\"pre-make\" // [] | length" "$MAIN_DIR/$JSON_FILE")
    if [ "$PRE_CMD_COUNT" -gt 0 ]; then
        for ((i=0; i<PRE_CMD_COUNT; i++)); do
            CMD=$(jq -r ".\"$CORE\".commands.\"pre-make\"[$i]" "$MAIN_DIR/$JSON_FILE")
            echo "--> Running pre-make: $CMD"
            eval "$CMD"
        done
    fi

    ### Parse Makefile config (using defaults if keys are missing) ###
    MAKEFILE=$(jq -r ".\"$CORE\".make.file // \"Makefile\"" "$MAIN_DIR/$JSON_FILE")
    MAKE_ARGS=$(jq -r ".\"$CORE\".make.args // \"\"" "$MAIN_DIR/$JSON_FILE")

    ### Build the make execution string ###
    MAKE_CMD="cd "$MAIN_DIR" && make CORE=$MAKEFILE_DIRECTORY MAKEFILE=-f$MAKEFILE"
    [ -n "$MAKE_ARGS" ] && MAKE_CMD="$MAKE_CMD $MAKE_ARGS"

    echo "--> Executing build: $MAKE_CMD"
    eval "$MAKE_CMD"

    ### Run Post-Make Commands ###
    POST_CMD_COUNT=$(jq ".\"$CORE\".commands.\"post-make\" // [] | length" "$MAIN_DIR/$JSON_FILE")
    if [ "$POST_CMD_COUNT" -gt 0 ]; then
        for ((i=0; i<POST_CMD_COUNT; i++)); do
            CMD=$(jq -r ".\"$CORE\".commands.\"post-make\"[$i]" "$MAIN_DIR/$JSON_FILE")
            echo "--> Running post-make: $CMD"
            eval "$CMD"
        done
    fi
    
    if [ -n "core.hcrtos" ] && ([ -f "core.hcrtos" ] || [ -n "$(find . -name "core.hcrtos" -print -quit)" ]); then
        diff -q "core.hcrtos" "output/$OUTPUT" || { rm -rf "output/$OUTPUT" && mkdir -p "$(dirname "output/$OUTPUT")" && cp "core.hcrtos" "output/$OUTPUT"; }
    fi

    if [ -n "$OUTPUT" ] && ([ -f "$OUTPUT" ] || [ -n "$(find . -name "$OUTPUT" -print -quit)" ]); then
        echo "Successfully built: $OUTPUT"
    else
        echo "Build step finished. Output tracking skipped or file not found."
    fi

    cd "$MAIN_DIR"
done
