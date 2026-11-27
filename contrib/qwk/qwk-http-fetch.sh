#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# qwk-http-fetch.sh: take the QWK packet of a node from an MK hub through the JSON API (API.md, "QWK packets for a node"), and send the reply packet.
#
#   qwk-http-fetch.sh URL TOKEN DIR [REPLY.REP]
#
#   URL    the hub, for example https://hub.example.org:2341      TOKEN  the token of the node (mkapitoken add ... -s qwk,qwk:reply -u "Node User")
#   DIR    where the packet goes: DIR/<BBSID>.QWK              REPLY  a reply packet (<BBSID>.REP) to send first
#
# The packet is acknowledged only when YOU say it is safe: this script leaves it in DIR and prints the id; run  qwk-http-ack.sh URL TOKEN ID  after you have tossed it.  (mk -G does this by itself.)
# Exit: 0 a packet is in DIR (its id on the last line), 3 nothing new, 1 an error.  Needs curl and sha256sum.
set -u
URL=${1:?usage: qwk-http-fetch.sh URL TOKEN DIR [REPLY.REP]}; TOKEN=${2:?token}; DIR=${3:?directory}; REP=${4:-}
mkdir -p "$DIR" || exit 1
H=$(mktemp) || exit 1; T=$(mktemp) || exit 1; trap 'rm -f "$H" "$T"' EXIT
if [ -n "$REP" ]; then
    code=$(curl -s -o "$T" -w '%{http_code}' -X PUT -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/zip' --data-binary @"$REP" "$URL/v1/qwk/reply")
    if [ "$code" != 200 ]; then echo "the hub did not take the reply packet: $code $(cat "$T")" >&2; exit 1; fi
    echo "reply packet: $(cat "$T")" >&2
fi
code=$(curl -s -D "$H" -o "$T" -w '%{http_code}' -H "Authorization: Bearer $TOKEN" "$URL/v1/qwk/packet")
case "$code" in
    204) echo "nothing new" >&2; exit 3 ;;
    200) ;;
    *) echo "the hub answered $code: $(cat "$T")" >&2; exit 1 ;;
esac
hdr() { awk -F': ' -v k="$1" 'tolower($1)==k {sub(/\r$/, "", $2); print $2}' "$H"; }
ID=$(hdr x-qwk-packet); SUM=$(hdr x-qwk-sha256)
NAME=$(hdr content-disposition | sed -n 's/.*filename="\([^"]*\)".*/\1/p')
[ -n "$NAME" ] || NAME="packet.QWK"
[ "$(sha256sum "$T" | cut -d' ' -f1)" = "$SUM" ] || { echo "the packet is damaged (SHA-256)" >&2; exit 1; }
mv "$T" "$DIR/$NAME" && echo "$ID"
