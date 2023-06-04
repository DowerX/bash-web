#!/bin/bash

TEMPLATES="./templates"
TEMPLATEREGEX='\/temp\/(.+)'

templatepath="$TEMPLATES/$(echo $RPATH | sed -E "s/$TEMPLATEREGEX/\1/").template"
if [[ -f $templatepath ]]; then
    echo -e "200 OK\r\n$SHEADERS\r\n" >> response
    echo "$($templatepath)" >> response
else
    echo -e "404 Not Found\r\n$SHEADERS\r\n" >> response
    echo "<!DOCTYPE html><html><h1>File not found.</h1>$RPATH</html>"
fi