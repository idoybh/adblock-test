## Purpose
A simple bash script to check if a system-wide / router level adblock is working.  
Site list taken from this now archived [project](https://github.com/d3ward/toolz/blob/master/src/data/adblock_data.json)  
Tests can be disabled by commenting / removing them out from `enabled-tests.conf`  
Specific sites / new tests categories etc can be removed / added by editing `site-data.json`

## Required packages
* [bind](https://archlinux.org/packages/extra/x86_64/bind/) (for `dig`)
* [iputils](https://archlinux.org/packages/core/x86_64/iputils/) (for `ping`)
* [bc](https://archlinux.org/packages/extra/x86_64/bc/) (for % calculation)
* [jq](https://archlinux.org/packages/extra/x86_64/bc/) (for json handling)
  
The rest are core / very common (even more common than these) packages, so it should be fine.  
