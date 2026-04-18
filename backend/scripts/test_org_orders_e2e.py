#!/usr/bin/env python3
"""End-to-end API smoke test for organisations + orders flow.

Usage:
  python scripts/test_org_orders_e2e.py --base-url http://127.0.0.1:8000

Optional flags:
  --creator-password <password>
  --joiner-password <password>
  --timeout 20
"""

from __future__ import annotations

import argparse
import random
import string
import sys
from datetime import datetime, timedelta, timezone
from typing import Any

import requests


class E2EError(Exception):
    pass


def _rand(n: int = 6) -> str:
    return "".join(random.choices(string.ascii_lowercase + string.digits, k=n))


def _iso_in(minutes: int) -> str:
    return (datetime.now(timezone.utc) + timedelta(minutes=minutes)).isoformat()


def _check(resp: requests.Response, expected: int | tuple[int, ...], step: str) -> dict[str, Any]:
    if isinstance(expected, int):
        expected = (expected,)

    content_type = resp.headers.get("Content-Type", "")
    try:
        payload = resp.json() if "application/json" in content_type else {"raw": resp.text}
    except Exception:
        payload = {"raw": resp.text}

    if resp.status_code not in expected:
        raise E2EError(
            f"{step} failed: HTTP {resp.status_code}, expected {expected}. Response: {payload}"
        )

    print(f"[OK] {step}: HTTP {resp.status_code}")
    return payload


def _register_user(base_url: str, username: str, email: str, password: str, timeout: int) -> None:
    payload = {
        "username": username,
        "email": email,
        "password": password,
        "phone": random.randint(9000000000, 9999999999),
        "hostel": "A",
        "gender": "Male",
    }

    resp = requests.post(f"{base_url}/users/register/", json=payload, timeout=timeout)

    # Accept either created or already-exists in case of retries.
    if resp.status_code == 201:
        print(f"[OK] register {username}: HTTP 201")
        return

    if resp.status_code == 400:
        try:
            body = resp.json()
        except Exception:
            body = {"raw": resp.text}
        if any(k in body for k in ["username", "email"]):
            print(f"[OK] register {username}: already exists (HTTP 400)")
            return

    raise E2EError(f"register {username} failed: HTTP {resp.status_code} {resp.text}")


def _login(base_url: str, username: str, password: str, timeout: int) -> str:
    resp = requests.post(
        f"{base_url}/users/login/",
        json={"username": username, "password": password},
        timeout=timeout,
    )
    data = _check(resp, 200, f"login {username}")
    token = data.get("access")
    if not token:
        raise E2EError(f"login {username} succeeded but no access token was returned")
    return token


def _auth_headers(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def run(base_url: str, timeout: int, creator_password: str, joiner_password: str) -> None:
    base_url = base_url.rstrip("/")
    uniq = _rand(8)

    creator_username = f"creator_{uniq}"
    joiner_username = f"joiner_{uniq}"
    creator_email = f"{creator_username}@example.com"
    joiner_email = f"{joiner_username}@example.com"

    org_name = f"CartBuddy University {uniq}"
    org_code = f"CB{uniq[:5].upper()}"

    print("\n=== Preparing users ===")
    _register_user(base_url, creator_username, creator_email, creator_password, timeout)
    _register_user(base_url, joiner_username, joiner_email, joiner_password, timeout)

    creator_token = _login(base_url, creator_username, creator_password, timeout)
    joiner_token = _login(base_url, joiner_username, joiner_password, timeout)

    creator_headers = _auth_headers(creator_token)
    joiner_headers = _auth_headers(joiner_token)

    print("\n=== Organisations flow ===")
    org_resp = requests.post(
        f"{base_url}/organisations/",
        json={
            "name": org_name,
            "short_code": org_code,
            "domain": "example.edu",
            "metadata": {"kind": "university"},
        },
        headers=creator_headers,
        timeout=timeout,
    )
    org_data = _check(org_resp, 201, "create organisation")
    org_id = org_data["id"]

    campus_resp = requests.post(
        f"{base_url}/organisations/campuses/",
        json={
            "organisation": org_id,
            "name": "Main Campus",
            "city": "Delhi",
            "state": "Delhi",
            "country": "India",
        },
        headers=creator_headers,
        timeout=timeout,
    )
    campus_data = _check(campus_resp, 201, "create campus")
    campus_id = campus_data["id"]

    # We need joiner user id from profile endpoint.
    joiner_profile = requests.get(f"{base_url}/users/me/", headers=joiner_headers, timeout=timeout)
    joiner_data = _check(joiner_profile, 200, "joiner profile")
    joiner_id = joiner_data["id"]

    member_resp = requests.post(
        f"{base_url}/organisations/memberships/",
        json={
            "organisation": org_id,
            "user": joiner_id,
            "role": "MEMBER",
            "status": "ACTIVE",
        },
        headers=creator_headers,
        timeout=timeout,
    )
    _check(member_resp, 201, "add joiner membership")

    my_memberships_resp = requests.get(
        f"{base_url}/organisations/me/memberships/",
        headers=joiner_headers,
        timeout=timeout,
    )
    _check(my_memberships_resp, 200, "joiner membership list")

    print("\n=== Orders flow ===")
    order_resp = requests.post(
        f"{base_url}/orders/",
        json={
            "organisation": org_id,
            "campus": campus_id,
            "title": "Pizza Night",
            "restaurant_name": "Dominos",
            "external_platform": "SWIGGY",
            "external_reference": f"ext_{uniq}",
            "meeting_point": "Hostel A Gate",
            "meeting_notes": "Bring student ID",
            "max_participants": 5,
            "currency": "INR",
            "platform_fee": "10.00",
            "delivery_fee": "20.00",
            "other_fee": "0.00",
            "cutoff_at": _iso_in(45),
            "expected_delivery_at": _iso_in(90),
        },
        headers=creator_headers,
        timeout=timeout,
    )
    order_data = _check(order_resp, 201, "create order")
    order_id = order_data["id"]

    list_resp = requests.get(
        f"{base_url}/orders/?organisation={org_id}",
        headers=joiner_headers,
        timeout=timeout,
    )
    _check(list_resp, 200, "joiner list visible orders")

    join_resp = requests.post(
        f"{base_url}/orders/{order_id}/participants/",
        json={
            "user": joiner_id,
            "amount_due": "150.00",
            "amount_paid": "0.00",
            "role": "JOINER",
            "status": "JOINED",
        },
        headers=joiner_headers,
        timeout=timeout,
    )
    join_data = _check(join_resp, 201, "join order as participant")
    participant_id = join_data["id"]

    item_resp = requests.post(
        f"{base_url}/orders/{order_id}/items/",
        json={
            "name": "Pepperoni Pizza",
            "quantity": 1,
            "unit_price": "150.00",
            "line_total": "150.00",
            "special_instructions": "Extra cheese",
        },
        headers=joiner_headers,
        timeout=timeout,
    )
    _check(item_resp, 201, "add order item")

    for step_name, new_status in [
        ("lock order", "LOCKED"),
        ("mark in progress", "IN_PROGRESS"),
        ("mark delivered", "DELIVERED"),
    ]:
        s_resp = requests.post(
            f"{base_url}/orders/{order_id}/status/",
            json={"status": new_status, "reason": step_name},
            headers=creator_headers,
            timeout=timeout,
        )
        _check(s_resp, 200, step_name)

    otp_resp = requests.post(
        f"{base_url}/orders/{order_id}/handover-otp/me/",
        json={"expires_in_minutes": 15},
        headers=joiner_headers,
        timeout=timeout,
    )
    otp_data = _check(otp_resp, 201, "generate handover otp")
    otp_plain = otp_data["otp"]

    verify_resp = requests.post(
        f"{base_url}/orders/{order_id}/handover-otp/verify/",
        json={"participant_id": participant_id, "otp": otp_plain},
        headers=creator_headers,
        timeout=timeout,
    )
    _check(verify_resp, 200, "verify handover otp")

    complete_resp = requests.post(
        f"{base_url}/orders/{order_id}/status/",
        json={"status": "COMPLETED", "reason": "handover done"},
        headers=creator_headers,
        timeout=timeout,
    )
    _check(complete_resp, 200, "complete order")

    history_resp = requests.get(
        f"{base_url}/orders/{order_id}/status-history/",
        headers=creator_headers,
        timeout=timeout,
    )
    history_data = _check(history_resp, 200, "fetch status history")
    if not isinstance(history_data, list) or len(history_data) < 4:
        raise E2EError(
            "status history validation failed: expected at least 4 transitions in history"
        )

    print("\n=== SUCCESS ===")
    print("Organisation + Orders E2E flow completed successfully.")
    print(f"Created organisation id: {org_id}")
    print(f"Created order id: {order_id}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run end-to-end org+orders API tests")
    parser.add_argument("--base-url", default="http://127.0.0.1:8000", help="API base URL")
    parser.add_argument("--creator-password", default="Pass@1234", help="Password for generated creator user")
    parser.add_argument("--joiner-password", default="Pass@1234", help="Password for generated joiner user")
    parser.add_argument("--timeout", type=int, default=20, help="Request timeout in seconds")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        run(
            base_url=args.base_url,
            timeout=args.timeout,
            creator_password=args.creator_password,
            joiner_password=args.joiner_password,
        )
        return 0
    except E2EError as exc:
        print(f"\n[FAIL] {exc}", file=sys.stderr)
        return 1
    except requests.RequestException as exc:
        print(f"\n[FAIL] Network error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
