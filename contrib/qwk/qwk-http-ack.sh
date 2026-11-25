#!/bin/sh
# qwk-http-ack.sh URL TOKEN ID: tell the hub that the packet ID (from qwk-http-fetch.sh) is posted; the hub then moves the node's last-read pointers.  Exit 0 done.
set -u
URL=${1:?usage: qwk-http-ack.sh URL TOKEN ID}; TOKEN=${2:?token}; ID=${3:?id}
curl -sf -X POST -H "Authorization: Bearer $TOKEN" "$URL/v1/qwk/packet/$ID/ack"
