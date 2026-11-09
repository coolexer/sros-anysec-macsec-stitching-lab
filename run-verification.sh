#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
mkdir -p results
LAB=clab-anysec-macsec-26-10

echo "[1/5] Generating traffic (Epipe 100 & VPRN 200) and capturing results..."
{
  echo "=== Epipe 100 End-to-End Ping (ce1 10.100.0.1 -> ce2 10.100.0.2) ==="
  docker exec "$LAB-ce1" ping -c 5 -W 2 10.100.0.2
  echo ""
  echo "=== VPRN 200 End-to-End Ping (ce1 192.168.10.2 -> ce2 192.168.20.2) ==="
  docker exec "$LAB-ce1" ping -c 5 -W 2 192.168.20.2
} | tee results/01-e2e-ping-verification.txt

echo "[2/5] Capturing ANYsec status and SecY counters on pe1 and pe2..."
{
  echo "==================== pe1 ANYsec & MKA Status ===================="
  ./sros.sh pe1 \
    'show anysec status' \
    'show anysec tunnel-encryption encryption-group "EG-TUNNEL" peer 10.20.1.2 detail' \
    'show macsec connectivity-association "CA-ANYSEC" detail'
  echo ""
  echo "==================== pe2 ANYsec & MKA Status ===================="
  ./sros.sh pe2 \
    'show anysec status' \
    'show anysec tunnel-encryption encryption-group "EG-TUNNEL" peer 10.20.1.1 detail' \
    'show macsec connectivity-association "CA-ANYSEC" detail'
} > results/02-anysec-verification.txt

echo "[3/5] Capturing IEEE 802.1AE MACsec status on pe2 and pe3..."
{
  echo "==================== pe2 MACsec Status (Port 1/1/c2/1) ===================="
  ./sros.sh pe2 \
    'show macsec connectivity-association "CA-MACSEC" detail' \
    'show macsec mka-session port 1/1/c2/1 sub-port 1 detail' \
    'show service id 100 macsec' \
    'show service id 200 macsec'
  echo ""
  echo "==================== pe3 MACsec Status (Port 1/1/c1/1) ===================="
  ./sros.sh pe3 \
    'show macsec connectivity-association "CA-MACSEC" detail' \
    'show macsec mka-session port 1/1/c1/1 sub-port 1 detail' \
    'show service id 100 macsec' \
    'show service id 200 macsec'
} > results/03-macsec-verification.txt

echo "[4/5] Capturing Service (Epipe 100 & VPRN 200) and Routing tables..."
{
  echo "==================== pe1 Services & VPRN 200 Routes ===================="
  ./sros.sh pe1 \
    'show router isis adjacency' \
    'show router ldp session' \
    'show router bgp summary' \
    'show service id 100 base' \
    'show router 200 route-table'
  echo ""
  echo "==================== pe2 Services & VPRN 200 Routes ===================="
  ./sros.sh pe2 \
    'show service id 100 base' \
    'show router 200 bgp summary' \
    'show router 200 route-table'
  echo ""
  echo "==================== pe3 Services & VPRN 200 Routes ===================="
  ./sros.sh pe3 \
    'show service id 100 base' \
    'show router 200 bgp summary' \
    'show router 200 route-table'
} > results/04-services-and-routing.txt

echo "[5/5] Capturing packets on the wire (needs sudo + tcpdump on the host)..."
capture() { # <title> <container> <interface> <ping-target> <pcap-filter>
  echo "=== $1 ==="
  docker exec "$LAB-ce1" ping -c 3 -i 0.2 "$4" >/dev/null 2>&1 &
  sudo timeout 3 ip netns exec "$LAB-$2" tcpdump -l -nn -e -x -c 4 -i "$3" "$5" 2>&1 || true
  wait
  echo ""
}
{
  capture "ANYsec link pe1 1/1/c1/1 <-> pe2 1/1/c1/1 (Epipe 100 ping)" pe1 e1-1-c1-1 10.100.0.2 mpls
  capture "ANYsec link pe1 1/1/c1/1 <-> pe2 1/1/c1/1 (VPRN 200 ping)" pe1 e1-1-c1-1 192.168.20.2 mpls
  capture "MACsec link pe2 1/1/c2/1 <-> pe3 1/1/c1/1 (Epipe 100 ping)" pe2 e1-1-c2-1 10.100.0.2 "ether proto 0x88e5"
  capture "MACsec link pe2 1/1/c2/1 <-> pe3 1/1/c1/1 (VPRN 200 ping)" pe2 e1-1-c2-1 192.168.20.2 "ether proto 0x88e5"
} > results/05-wire-packet-captures.txt

echo "All verification outputs saved to results/."
