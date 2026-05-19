#!/usr/bin/env bash
# test.sh — verify both engines reproduce the published 1966 transcript and
# agree with each other.

set -e
cd "$(dirname "$0")"

python eliza_compile.py doctor.script doctor.json >/dev/null

python eliza_tokens.py doctor.script < transcript.txt > /tmp/tokens.out
python eliza_regex.py  doctor.json   < transcript.txt > /tmp/regex.out

if ! diff -q /tmp/tokens.out /tmp/regex.out > /dev/null; then
    echo "FAIL: engines disagree"
    diff /tmp/tokens.out /tmp/regex.out
    exit 1
fi
echo "OK: engines agree"

if ! diff -q /tmp/tokens.out expected.txt > /dev/null; then
    echo "FAIL: output differs from published 1966 transcript"
    diff expected.txt /tmp/tokens.out
    exit 1
fi
echo "OK: matches published 1966 transcript"
