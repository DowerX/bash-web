#!/bin/bash

PORT=10000
LOG=true
ROUTES='./routes'

CONNREGEX='Connection received on (.+)\s(.+)'
HEADREGEX='(GET|HEAD|POST|PUT|DELETE|CONNECT|OPTIONS|TRACE)\s(.*?)\sHTTP.*?'
PATHREGEX='(\/[^?]*)\??.*'
QUERYREGX='.*\?(.*)'
ROUTINGREGEX="location '(\\\/.*)' \{ (.+) \}"

HEADERTYPES=('HOST' 'ACCEPT' 'ACCEPT-ENCODING' 'ACCEPT-LANGUAGE' 'USER-AGENT' 'COOKIE')

export SHEADERS="Server: $(bash --version | head -1); netcat; $(sed --version | head -1); $(wget --version | head -1); ($(uname -o))"

rm -f responseFIFO
mkfifo responseFIFO

function handleRequest() {
    # parse request
    CONNSET=false
    HEADSET=false
    while read line; do
        trim=$(echo "$line" | tr -d "[\r\n]")
        if [[ -z "$trim" ]]; then
            break
        fi

        if [[ $CONNSET == false ]] && [[ "$line" =~ $CONNREGEX ]]; then
            local RADDRESS=$(echo $line | sed -E "s/$CONNREGEX/\1/")
            local RPORT=$(echo $line | sed -E "s/$CONNREGEX/\2/")
            CONNSET=true
        fi

        if [[ $HEADSET == false ]] && [[ "$line" =~ $HEADREGEX ]]; then
            line=$(echo "$line" | sed -E "s/(\*)/\\\*/g" | sed -E "s#\./#/#g")
            local RMETHOD=$(echo $line | sed -E "s/$HEADREGEX/\1/")
            local RURL=$(echo $line | sed -E "s/$HEADREGEX/\2/")
            local RPATH=$(echo $RURL | sed -E "s/$PATHREGEX/\1/")
            if [[ "$RURL" =~ $QUERYREGX ]]; then
                RQUERY=$(echo $RURL | sed -E "s/$QUERYREGX/\1/")
            fi
            HEADSET=true
        fi

        declare -A RHEADERS
        for header in ${HEADERTYPES[@]}; do
            regex="^$header: (.+)$"
            if [[ -z "${RHEADERS[header]}" ]] &&
               [[ "$(echo $line | tr a-z A-Z)" =~ $regex ]]; then                
                RHEADERS[$header]=$(echo "$line" | sed -E "s#$regex#\1#I")
            fi
        done
    done


    # export request variables for subscripts
    for i in ${!RHEADERS[@]}; do
        export "R$(echo $i | tr '-' '_')"="${RHEADERS[$i]}"
    done
    export RADDRESS=$RADDRESS
    export RPORT=$RPORT
    export RMETHOD=$RMETHOD
    export RURL=$RURL
    export RPATH=$RPATH
    export RQUERY=$RQUERY

    echo -en "HTTP/1.0 " > response

    # routing
    while IFS= read -r line; do
        regex=$(echo $line | sed -E "s#$ROUTINGREGEX#\1#")
        func=$(echo $line | sed -E "s#$ROUTINGREGEX#\2#")
        if [[ $RPATH =~ $regex ]]; then
            $ROUTES/$func.sh
            break
        fi
    done < "default.routes"

    # send response
    cat response >> responseFIFO
    [[ $LOG = true ]] && echo "$RADDRESS - [$(date '+%Y/%m/%d %H:%M:%S')] $func: $RMETHOD $RPATH $(head -1 response | cut -d ' ' -f 2)"
    rm response
}

while true; do
    cat responseFIFO | nc -vvN -l -p $PORT 2>&1 | handleRequest
done