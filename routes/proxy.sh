#!/bin/bash

PROXYREGEX='\/proxy\/(.+)'

proxyurl=$(echo $RPATH | sed -E "s/$PROXYREGEX/\1/")
echo -e "200 OK\r\n$SHEADERS\r\n" >> response
wget -O - $proxyurl 2>/dev/null >> response