#!/bin/bash

# file paths
TESTS_FILE="./enabled-tests.conf"
DATA_FILE="./site-data.json"
BLOCKING_METHODS=("localhost" "0.0.0.0" "No DNS")

# colors
RED="\033[31m" # For errors / warnings
GREEN="\033[32m" # For info
YELLOW="\033[33m" # For input requests
BLUE="\033[36m" # For info
NC="\033[0m" # reset color

# functions

# $1 the URL
# overwrite ipList below with a human readable list of IPs for given URL
ipList=""
populate_ip_list() {
    local url="$1"
    local digOut
    digOut=$(dig "$url" | tr -s '\n' | grep -v \; | grep -w "IN" | grep -w "A")
    ipList=""
    while read -r line; do
        line=$(echo "$line" | xargs)
        if [[ $ipList == "" ]]; then
            ipList="${line##* }"
        else
            ipList="${ipList}, ${line##* }"
        fi
    done <<< "$digOut"
}

# $1: the URL to test
# returns "0" if the URL isn't blocked by any means, index for method + 1 otherwise
get_is_blocked() {
    local url="$1"
    local digres
    digres=$(dig -r "$url")
    if echo "$digres" | grep -q "127.0.0.1"; then
        # points to local
        echo 1
    elif echo "$digres" | grep -q "0.0.0.0"; then
        # points to non existent
        echo 2
    else
        populate_ip_list "$url"
        if [[ $ipList == "" ]]; then
            # failed to resolve. abort here
            # no DNS records
            echo 3
        else # try another way
            echo 0
        fi
    fi
}

# $1: the percentage to test as integer
# returns the escape code for this percentage
get_percent_color() {
    local pc="$1"
    if [[ $pc == 100 ]]; then
        echo "${GREEN}"
    elif [[ $pc == 0 ]]; then
        echo "${RED}"
    else
        echo "${YELLOW}"
    fi
}

# init
json=$(cat "$DATA_FILE")
passed=0
total=0
sites=()
sitesPass=()
sitesCount=()
tests=()
while read -r line; do
    [[ "$line" == *'#'* ]] && continue
    tests+=("$line")
done < "$TESTS_FILE"

# main loop
for test in "${tests[@]}"; do
    echo -e "${RED}======= ${test}: =======${NC}"
    siteKeys=$(echo "$json" | jq ".\"${test}\" | keys")
    siteNum=$(echo "$siteKeys" | jq "length")
    for (( i = 0; i < siteNum; i++ )); do
        siteName=$(echo "$siteKeys" | jq -r ".[$i]")
        echo
        echo -e "${BLUE}${siteName}:${NC}"
        urlArr=$(echo "$json" | jq ".\"${test}\".\"${siteName}\"")
        urlNum=$(echo "$urlArr" | jq "length")
        sites+=("$siteName")
        sitesCount+=("$urlNum")
        total=$(( total + urlNum ))
        passedSites=0
        for (( j = 0; j < urlNum; j++ )); do
            url=$(echo "$urlArr" | jq -r ".[$j]")
            tput sc
            echo -en "${YELLOW}? ${url}${NC}"
            tput rc
            # test this url
            res=$(get_is_blocked "$url")
            if [[ $res -gt 0 ]]; then
                # passed
                (( res-- ))
                method="${BLOCKING_METHODS[$res]}"
                tput el
                echo -e "${GREEN}✓ ${url} (${method})${NC}"
                (( passedSites++ ))
                (( passed++ ))
            else
                # failed
                [[ $res != 3 ]] && populate_ip_list "$url"
                ips="$ipList"
                [[ $ips == "" ]] && ips="ERR"
                ping="❌"
                if ping -c 1 -W 1 "$url" > /dev/null 2>&1; then
                    ping="✓"
                fi
                tput el
                echo -e "${RED}❌ ${url} (IP: ${ips} Ping: ${ping})${NC}"
            fi
        done
        sitesPass+=("$passedSites")
        percent=$(echo "scale=2; (($passedSites / $urlNum) * 100) / 1" | bc -l | cut -d "." -f 1)
        echo -e "${BLUE}${passedSites} / ${urlNum} (${percent}%)${NC}"
    done
    echo
done

# summary
percent=$(echo "scale=2; (($passed / $total) * 100) / 1" | bc -l | cut -d "." -f 1)
color=$(get_percent_color "$percent")
echo -e "Testing done. Passed: ${color}${passed}/${total} (${percent}%)${NC}"
echo
echo "Per site:"
i=0
for site in "${sites[@]}"; do
    passes="${sitesPass[$i]}"
    tCount="${sitesCount[$i]}"
    percent=$(echo "scale=2; (($passes / $tCount) * 100) / 1" | bc -l | cut -d "." -f 1)
    color=$(get_percent_color "$percent")
    echo -e "${BLUE}${site}: ${color}${passes} / ${tCount} (${percent}%)${NC}"
    (( i++ ))
done
