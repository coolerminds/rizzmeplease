#!/usr/bin/env python3
"""Smoke-test xAI Grok chat completions with soft handling for no-credit accounts."""

from __future__ import annotations

import argparse
import os
import sys

import httpx
from dotenv import load_dotenv


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", default=os.getenv("OPENAI_MODEL", "grok-beta"))
    parser.add_argument("--base-url", default=os.getenv("XAI_BASE_URL", "https://api.x.ai/v1"))
    parser.add_argument("--timeout", type=float, default=30.0)
    return parser.parse_args()


def main() -> int:
    load_dotenv()
    args = parse_args()

    api_key = os.getenv("XAI_API_KEY") or os.getenv("OPENAI_API_KEY")
    if not api_key:
        print("ERROR: Set XAI_API_KEY (or OPENAI_API_KEY) before running this script.")
        return 2

    url = args.base_url.rstrip("/") + "/chat/completions"
    payload = {
        "model": args.model,
        "messages": [
            {
                "role": "user",
                "content": "Reply with one short sentence proving connectivity.",
            }
        ],
        "temperature": 0.2,
        "max_tokens": 60,
    }

    try:
        with httpx.Client(timeout=args.timeout) as client:
            response = client.post(
                url,
                headers={
                    "Content-Type": "application/json",
                    "Authorization": f"Bearer {api_key}",
                },
                json=payload,
            )
    except httpx.TimeoutException:
        print("ERROR: Timeout while reaching xAI API.")
        return 3
    except httpx.HTTPError as exc:
        print(f"ERROR: Network failure calling xAI API: {exc}")
        return 3

    print(f"Status: {response.status_code}")
    if response.status_code == 402:
        print("Soft-fail: xAI account likely missing credits. Add billing, then rerun.")
        print(f"Body: {response.text[:500]}")
        return 0
    if response.status_code == 401:
        print("ERROR: Invalid xAI API key (401). Check XAI_API_KEY.")
        print(f"Body: {response.text[:500]}")
        return 4
    if response.status_code >= 400:
        print(f"ERROR: xAI API returned {response.status_code}.")
        print(f"Body: {response.text[:500]}")
        return 4

    try:
        data = response.json()
        model = data.get("model", "unknown")
        first_reply = (
            data.get("choices", [{}])[0]
            .get("message", {})
            .get("content", "")
            .strip()
        )
    except Exception as exc:  # noqa: BLE001
        print(f"ERROR: Unable to parse JSON response: {exc}")
        print(f"Raw body: {response.text[:500]}")
        return 5

    print(f"Model: {model}")
    print(f"First reply: {first_reply or '<empty>'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
