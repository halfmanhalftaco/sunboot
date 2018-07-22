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