#!/usr/bin/env python3
"""Smoke-test /api/v1/auth/anonymous then /api/v1/suggestions using fixture payloads."""

from __future__ import annotations

import argparse
import json
import uuid
from pathlib import Path

import httpx
from dotenv import load_dotenv

DEFAULT_FIXTURE_PATH = Path(__file__).resolve().parents[1] / "tests" / "mock_extension_payloads.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", default="http://127.0.0.1:8000")
    parser.add_argument("--fixture", default="rizzcoach_chill_friend_get_reply")
    parser.add_argument("--fixture-path", type=Path, default=DEFAULT_FIXTURE_PATH)
    parser.add_argument("--timeout", type=float, default=30.0)
    return parser.parse_args()


def load_fixture(fixture_path: Path, fixture_name: str) -> dict:
    with fixture_path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)

    requests = data.get("suggestion_requests", [])
    for item in requests:
        if item.get("name") == fixture_name:
            return item

    if requests:
        print(
            f"WARNING: fixture '{fixture_name}' not found. Falling back to '{requests[0].get('name')}'."
        )
        return requests[0]

    raise ValueError("No suggestion_requests found in fixture file.")


def main() -> int:
    load_dotenv()
    args = parse_args()

    payload = load_fixture(args.fixture_path, args.fixture)
    base = args.base_url.rstrip("/")
    auth_url = f"{base}/api/v1/auth/anonymous"
    suggestions_url = f"{base}/api/v1/suggestions"

    device_id = f"smoke-{uuid.uuid4()}"

    try:
        with httpx.Client(timeout=args.timeout) as client:
            auth_resp = client.post(auth_url, json={"device_id": device_id})
            if auth_resp.status_code >= 400:
                print(f"ERROR: auth failed ({auth_resp.status_code}).")
                print(auth_resp.text[:500])
                return 2

            auth_data = auth_resp.json()
            token = auth_data.get("data", {}).get("access_token")
            if not token:
                print("ERROR: missing access_token in auth response.")
                print(auth_resp.text[:500])
                return 2

            sugg_resp = client.post(
                suggestions_url,
                headers={
                    "Authorization": f"Bearer {token}",
                    "Content-Type": "application/json",
                    "Idempotency-Key": str(uuid.uuid4()),
                },
                json={
                    "conversation": payload["conversation"],
                    "goal": payload["goal"],
                    "tone": payload["tone"],
                    "relationship_type": payload.get("relationship_type"),
                    "context": payload.get("context"),
                    "thread_context": payload.get("thread_context"),
                },
            )
    except httpx.TimeoutException:
        print("ERROR: request timed out.")
        return 3
    except httpx.HTTPError as exc:
        print(f"ERROR: network call failed: {exc}")
        return 3

    print(f"Suggestions status: {sugg_resp.status_code}")
    if sugg_resp.status_code >= 400:
        print("ERROR: suggestions request failed.")
        print(sugg_resp.text[:1000])
        return 4

    data = sugg_resp.json()
    suggestions = data.get("data", {}).get("suggestions", [])
    suggestion_set_id = data.get("data", {}).get("suggestion_set_id")

    if not suggestions:
        print("ERROR: suggestions response had no suggestions.")
        print(sugg_resp.text[:1000])
        return 5

    print(f"Fixture: {payload.get('name')}")
    print(f"Suggestion set: {suggestion_set_id}")
    print(f"Count: {len(suggestions)}")
    print(f"Top suggestion: {suggestions[0].get('text', '')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
