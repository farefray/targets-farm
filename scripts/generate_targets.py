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

# Use hyphenated IP form to avoid sslip.io matching an earlier dotted IPv4 in the hostname
domain = f"{ip.replace('.', '-')}.sslip.io"

# Bucket allocations – tuned to exactly 1000
plan = {
    "redirect": 20,    # 3-hop
    "rl": 50,          # rate-limited
    "delay1s": 250,     # delay 1 second
    "big": 10,         # 1 MB body
    "err":  25,         # 500 error
    "waf":  100         # waf-like blocking
}

plan["ok"] = 1000 - sum(plan.values())

hosts = []

def h(prefix, idx):
    return f"{prefix}-{idx:03d}.{domain}"

# Build hostnames per bucket
for prefix in ["ok", "redirect", "rl", "delay1s", "big", "err", "waf"]:
    count = plan.get(prefix, 0)
    idx = 1
    for _ in range(count):
        hosts.append(h(prefix, idx))
        idx += 1

random.shuffle(hosts)

for hname in hosts:
    mix_protocol = random.choice(["http", "https"])
    print(f"{mix_protocol}://{hname}")