#!/bin/bash

PORT=10000
LOG=true
ROUTES='./routes'

CONNREGEX='Connection received on (.+)\s(.+)'
HEADREGEX='(GET|HEAD|POST|PUT|DELETE|CONNECT|OPTIONS|TRACE)\s(.*?)\sHTTP.*?'
PATHREGEX='(\/[^?]*)\??.*'
QUERYREGX='.*\?(.*)'

ROUTINGREGEX="location '(\\\/.*)' \{ (.+) \}"

rm -f responseFIFO
mkfifo responseFIFO

function handleRequest() {
    #parse request
    CONNSET=0
    HEADSET=0
    while read line; do
        trim=$(echo "$line" | tr -d "[\r\n]")
        if [[ -z "$trim" ]]; then
            break
        fi

        if [[ $CONNSET -eq 0 ]] && [[ "$line" =~ $CONNREGEX ]]; then
            RADDRESS=$(echo $line | sed -E "s/$CONNREGEX/\1/")
            RPORT=$(echo $line | sed -E "s/$CONNREGEX/\2/")
            CONNSET=1
        fi

        if [[ $HEADSET -eq 0 ]] && [[ "$line" =~ $HEADREGEX ]]; then
            RMETHOD=$(echo $line | sed -E "s/$HEADREGEX/\1/")
            RURL=$(echo $line | sed -E "s/$HEADREGEX/\2/")
            RPATH=$(echo $RURL | sed -E "s/$PATHREGEX/\1/")
            if [[ "$RURL" =~ $QUERYREGX ]]; then
                RQUERY=$(echo $RURL | sed -E "s/$QUERYREGX/\1/")
                declare -A RPARAMS
                for par in $(echo $RQUERY | tr '&' ' '); do
                    RPARAMS[$(echo $par | cut -d '=' -f 1)]=$(echo $par | cut -d '=' -f 2)
                done
            fi
            HEADSET=1
        fi
    done

    export RADDRESS=$RADDRESS
    export RPORT=$RPORT
    export RMETHOD=$RMETHOD
    export RURL=$RURL
    export RPATH=$RPATH
    export RQUERY=$RQUERY

    # routing
    rm -f codeFIFO
    while IFS= read -r line; do
        regex=$(echo $line | sed -E "s#$ROUTINGREGEX#\1#")
        func=$(echo $line | sed -E "s#$ROUTINGREGEX#\2#")
        if [[ $RPATH =~ $regex ]]; then
            response=$($ROUTES/$func.sh)
            code=$?
            break
        fi
    done < "default.routes"

    [[ $LOG = true ]] && echo "$RADDRESS - [$(date '+%Y/%m/%d %H:%M:%S')] $func: $RMETHOD $RPATH $code"
    echo -e "HTTP/1.1 $code\r\n\r\n$response" >> responseFIFO
}

while true; do
    cat responseFIFO | nc -vvN -l -p $PORT 2>&1 | handleRequest
done