import os
import ipaddress
import boto3

IPV4_SET_NAME = os.getenv("IPV4_SET_NAME", "problematic-ips")
IPV4_SET_ID   = os.getenv("IPV4_SET_ID",   "f159f337-4595-4a42-a913-571b718679ec")
WAF_SCOPE     = os.getenv("WAF_SCOPE",     "REGIONAL")

waf = boto3.client("wafv2")

def lambda_handler(event, context):
    ip_raw = extract_ip(event)
    cidr = to_cidr(ip_raw)

    get_resp = waf.get_ip_set(Name=IPV4_SET_NAME, Scope=WAF_SCOPE, Id=IPV4_SET_ID)
    current = get_resp["IPSet"]["Addresses"]
    lock    = get_resp["LockToken"]

    if cidr in current:
        return {"status": "noop", "reason": "already present", "address": cidr, "count": len(current)}

    new_addrs = current + [cidr]

    upd = waf.update_ip_set(
        Name=IPV4_SET_NAME,
        Scope=WAF_SCOPE,
        Id=IPV4_SET_ID,
        Addresses=new_addrs,
        LockToken=lock,
    )

    return {"status": "updated", "added": cidr, "count": len(new_addrs), "metadata": upd.get("ResponseMetadata", {})}

def extract_ip(event):
    if isinstance(event, dict):
        if "httpRequest" in event and "clientIp" in event["httpRequest"]:
            return event["httpRequest"]["clientIp"]
        for k in ("ip", "clientIp", "sourceIp"):
            if k in event:
                return event[k]
        try:
            return event["requestContext"]["http"]["sourceIp"]
        except Exception:
            pass
    raise KeyError("Could not find an IP address in the event payload")

def to_cidr(ip):
    if "/" in ip:
        ipaddress.ip_network(ip, strict=False)
        return ip
    try:
        ipaddress.IPv4Address(ip)
        return f"{ip}/32"
    except ipaddress.AddressValueError:
        ipaddress.IPv6Address(ip)
        return f"{ip}/128"
