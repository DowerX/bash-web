#!/bin/bash

TEMPLATES="./templates"
TEMPLATEREGEX='\/temp\/(.+)'

templatepath="$TEMPLATES/$(echo $RPATH | sed -E "s/$TEMPLATEREGEX/\1/").template"
if [[ -f $templatepath ]]; then
    echo "$($templatepath)"
    exit 200
else
    echo "<!DOCTYPE html><html><h1>File not found.</h1>$RPATH</html>"
    exit 404
fi