#!/usr/bin/env python3
import sys
import random
import socket

# Usage: ./generate_targets.py <PUBLIC_IP> > targets.txt
if len(sys.argv) != 2:
    print("Usage: generate_targets.py <PUBLIC_IP>", file=sys.stderr)
    sys.exit(1)

ip = sys.argv[1]

# Basic IP validation
try:
    socket.inet_aton(ip)
    if '.' not in ip or ip.count('.') != 3:
        raise ValueError("Invalid IP format")
except:
    print(f"Error: '{ip}' is not a valid IPv4 address", file=sys.stderr)
    sys.exit(1)

domain = f"{ip}.sslip.io"

# Bucket allocations – tuned to exactly 1000
plan = {
    "ok": 400,          # fast baseline
    "redirect": 100,    # 3-hop
    "rl": 100,          # rate-limited
    "delay1s": 150,     # delay 1 second
    "big": 100,         # 1 MB body
    "err":  50,         # 500 error
    "waf":  100         # waf-like blocking
}
assert sum(plan.values()) == 1000, "Bucket plan must sum to 1000"

hosts = []

def h(prefix, idx):
    return f"{prefix}-{idx:03d}.{domain}"

# Build hostnames per bucket
i = 1
for count in [plan.get("ok",0), plan.get("redirect",0), plan.get("rl",0), plan.get("delay1s",0), plan.get("big",0), plan.get("err",0), plan.get("waf",0)]:
    prefix = ["ok", "redirect", "rl", "delay1s", "big", "err", "waf"][i-1]
    for _ in range(count):
        hosts.append(h(prefix, i))
    i += 1

random.shuffle(hosts)

# Print as plain hostnames (Nuclei accepts host:port or URL depending on template)
for hname in hosts:
    print(f"http://{hname}")