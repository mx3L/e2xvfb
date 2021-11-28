#!/bin/bash
x11vnc -forever &
x11vncpid=pidof $!
sleep 5
enigma2 | tee /tmp/enigma2.log
while true; do sleep 1; done
kill $x11vncpid

