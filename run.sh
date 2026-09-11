#!/bin/bash
if [ ! -d "NoNoTurtle.app" ]; then
    ./build.sh
fi
echo "🐢 Launching NoNoTurtle in Menu Bar..."
open NoNoTurtle.app
