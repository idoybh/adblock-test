#!/bin/bash

# file paths
TESTS_FILE="./enabled-tests.conf"
DATA_FILE="./site-data.json"

# colors
RED="\033[31m" # For errors / warnings
GREEN="\033[32m" # For info
YELLOW="\033[33m" # For input requests
BLUE="\033[36m" # For info
NC="\033[0m" # reset color

# functions

# $1: the URL to test
# returns "1" if the URL is blocked by any means
get_is_blocked() {
    local url="$1"
    local digres
    digres=$(dig "$url")
    if echo "$digres" | grep -q "127.0.0.1"; then
        # points to local
        echo 1
    elif echo "$digres" | grep -q "0.0.0.0"; then
        # points to non existent
        echo 1
    elif echo "$digres" | grep -q "ANSWER: 0"; then
        # no DNS records
        echo 1
    elif [[ $(curl -m 3 -s -o /dev/null -w "%{http_code}" "$1") == 404 ]]; then
        # points to a 404 server
        echo 1
    else
        echo 0
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
            # test this url
            if [[ $(get_is_blocked "$url") == 1 ]]; then
                # passed
                echo -e "${GREEN}✓ ${url}${NC}"
                (( passedSites++ ))
                (( passed++ ))
            else
                # failed
                echo -e "${RED}❌ ${url}${NC}"
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
