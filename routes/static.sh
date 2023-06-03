#!/bin/bash

STATIC="./static"

if [[ -f $STATIC/$RPATH ]]; then 
    cat "$STATIC/${RPATH}" 2>/dev/null
    exit 200
elif [[ -f "$STATIC/${RPATH}index.html" ]]; then
    cat "$STATIC/${RPATH}index.html" 2>/dev/null
    exit 200
else
    echo "<!DOCTYPE html><html><h1>File not found.</h1>$RPATH</html>"
    exit 404
fi    