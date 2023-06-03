#!/bin/bash

PROXYREGEX='\/proxy\/(.+)'

proxyurl=$(echo $RPATH | sed -E "s/$PROXYREGEX/\1/")
echo "$(curl -L $proxyurl 2>/dev/null)"
exit 200