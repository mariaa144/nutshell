#!/bin/bash
# Mint + tailscaled entrypoint (fly.io). The mint reaches its LND REST
# backend DIRECTLY over the tailnet (hal's tailnet-only :10443 serve,
# hosts/hal/tailscale.nix in nixos-config) instead of via the public
# Tailscale Funnel — the fly->funnel->hal relay chain dropped or lost the
# responses of 3 of 4 melt incidents (docs/session-notes/2026-10-24-*,
# 2026-11-05-*, 2026-11-19-* in nixos-config).
#
# TUN mode (kernel tailnet interface), same as dawson-mcrelay
# (~/Workspace/fly/mcrelay): /dev/net/tun exists on fly machines; the node
# keeps its identity + tag:cashu-mint via the state persisted on the /data
# volume, so the TS_AUTHKEY secret only matters on first boot.
set -euo pipefail
mkdir -p /data/tailscale /var/run/tailscale /dev/net
[ -e /dev/net/tun ] || mknod /dev/net/tun c 10 200

tailscaled \
  --state=/data/tailscale/tailscaled.state \
  --socket=/var/run/tailscale/tailscaled.sock \
  --tun=tailscale0 &
TS_SOCK="--socket=/var/run/tailscale/tailscaled.sock"
sleep 5

# hal's tailnet IP is pinned (100.118.216.3, since 2026-09-15) and the
# ts.net cert covers both serve ports, so /etc/hosts replaces MagicDNS
# (accept-dns=false) and the endpoint URL keeps matching its certificate.
echo "100.118.216.3 hal.note-teeth.ts.net" >> /etc/hosts
if ! tailscale $TS_SOCK status --peers=false >/dev/null 2>&1; then
  tailscale $TS_SOCK up \
    --authkey="$TS_AUTHKEY" --hostname="cashu-mint" --accept-dns=false
fi

# Image CMD (or the machine's cmd) is the mint command; fall back to the
# historical image CMD if fly ever regenerates an empty command (the
# 2026-10-24 empty-command crash-loop lesson).
if [ "$#" -eq 0 ]; then
  set -- poetry run mint
fi
"$@" &

# A half-alive mint is worse than a dead one (dawson-mcrelay rule): if
# tailscaled OR the mint dies, exit so fly's restart policy reboots the
# whole machine.
wait -n
exit 1
