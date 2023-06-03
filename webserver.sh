#!/bin/bash

PORT=10000
STATIC="./static"
TEMPLATES="./templates"
LOG=true

PROXYREGEX='\/proxy\/(.+)'
TEMPLATEREGEX='\/temp\/(.+)'

CONNREGEX='Connection received on (.+)\s(.+)'
HEADREGEX='(GET|HEAD|POST|PUT|DELETE|CONNECT|OPTIONS|TRACE)\s(.*?)\sHTTP.*?'
PATHREGEX='(\/[^?]*)\??.*'
QUERYREGX='.*\?(.*)'

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

    # routing
    if [[ $RPATH =~ $PROXYREGEX ]]; then
        # proxy
        proxyurl=$(echo $RPATH | sed -E "s/$PROXYREGEX/\1/")
        response="$(curl -L $proxyurl 2>/dev/null)"
        code=200
    elif [[ $RPATH =~ $TEMPLATEREGEX ]]; then
        # templates
        templatepath="$TEMPLATES/$(echo $RPATH | sed -E "s/$TEMPLATEREGEX/\1/").template"
        if [[ -f $templatepath ]]; then
            response="$($templatepath $RADDRESS $RPORT $RMETHOD $RURL $RPATH $RQUERY)"
            code=200
        else
            response="<!DOCTYPE html><html><h1>File not found.</h1>$RPATH</html>"
            code=404
        fi
    else
        # serve file
        if [[ -f $STATIC/$RPATH ]]; then 
            response="$(cat $STATIC/$RPATH 2>/dev/null)"
            code=200
        elif [[ -f "$STATIC/${RPATH}index.html" ]]; then
            response="$(cat "$STATIC/${RPATH}index.html" 2>/dev/null)"
            code=200
        else
            response="<!DOCTYPE html><html><h1>File not found.</h1>$RPATH</html>"
            code=404
        fi      
    fi

    [[ $LOG = true ]] && echo "$RADDRESS - [$(date '+%Y/%b/%d %H:%M:%S')] $RMETHOD $RPATH $code"
    echo -e "HTTP/1.1 $code\r\n\r\n$response" >> responseFIFO
}

while true; do
    cat responseFIFO | nc -vvN -l -p $PORT 2>&1 | handleRequest
done