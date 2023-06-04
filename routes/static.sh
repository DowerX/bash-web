#!/bin/bash

STATIC="./static"

if [[ -f $STATIC/$RPATH ]]; then 
    echo -e "200 OK\r\n$SHEADERS\r\n" >> response
    cat "$STATIC/${RPATH}" 2>/dev/null >> response
elif [[ -f "$STATIC/${RPATH}index.html" ]]; then
    echo -e "200 OK\r\n$SHEADERS\r\n" >> response
    cat "$STATIC/${RPATH}index.html" 2>/dev/null >> response
else
    echo -e "404 Not Found\r\n$SHEADERS\r\n<!DOCTYPE html><html><h1>File not found.</h1>$RPATH</html>" >> response
fi