#!/bin/bash

pushd () {
    command pushd "$@" > /dev/null
}
popd () {
    command popd "$@" > /dev/null
}
error_exit() {
    echo $@
    exit 1
}
normal_ether() {
    local e1 e2 e3 e4 e5 e6
    IFS=: read -r e1 e2 e3 e4 e5 e6  <<< $1 
    printf "%02X:%02X:%02X:%02X:%02X:%02X" 0x$e1 0x$e2 0x$e3 0x$e4 0x$e5 0x$e6
}
iphex() {
    local i1 i2 i3 i4
    IFS=. read -r i1 i2 i3 i4 <<< $1
    printf "%02X%02X%02X%02X" $i1 $i2 $i3 $i4
}
getnetwork() {
    local i1 i2 i3 i4 m1 m2 m3 m4
    IFS=. read -r i1 i2 i3 i4 <<< $1
    IFS=. read -r m1 m2 m3 m4 <<< $2
    printf "%d.%d.%d.%d\n" "$((i1 & m1))" "$((i2 & m2))" "$((i3 & m3))" "$((i4 & m4))"
}

# from https://stackoverflow.com/questions/4023830/how-to-compare-two-strings-in-dot-separated-version-format-in-bash
vercomp () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}