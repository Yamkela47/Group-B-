#!/usr/bin/env python3
"""Safely copy database-referenced legacy images into catalog-images.

Dry-run by default. --apply copies, verifies, then updates saved image URLs.
Does NOT delete anything from legacy buckets. Uses stdlib; Python 3.10+.
Use server-side service-role credentials ONLY. Never bundle them in Flutter.
"""
import argparse
import hashlib
import json
import mimetypes
import os
import re
import sys
from urllib.error import HTTPError
from urllib.parse import quote, unquote, urlsplit
from urllib.request import Request, urlopen

BUCKET = "catalog-images"
LEGACY = {"profile-photos", "salon-profile-images", "gallery"}
TABLES = (
    ("profiles", "id", "photo_url"),
    ("services", "service_id", "image_url"),
    ("promotions", "promotion_id", "image_url"),
    ("gallery_images", "image_id", "image_url"),
    ("site_settings", "setting_key", "setting_value"),
)
MARKER = re.compile(r"^/storage/v1/object/(?:public|authenticated)/([^/]+)/(.+)$")


def api(base, key, method, path, data=None, content_type=None):
    headers = {"apikey": key, "Authorization": "Bearer " + key}
    if content_type:
        headers["Content-Type"] = content_type
    req = Request(base + path, data=data, method=method, headers=headers)
    try:
        with urlopen(req, timeout=45) as resp:
            return resp.read()
    except HTTPError as e:
        details = e.read().decode("utf-8", errors="replace")[:500]
        raise RuntimeError(f"HTTP {e.code} for {method} {path}: {details}") from e


def get_rows(base, key, table, pk, column):
    query = f"/rest/v1/{table}?select={pk},{column}&{column}=not.is.null"
    try:
        return json.loads(api(base, key, "GET", query))
    except RuntimeError as exc:
        if table == "site_settings":
            print(f"Skipping optional site_settings: {exc}")
            return []
        raise


def auth_ids(base, key, table, column):
    try:
        rows = json.loads(api(base, key, "GET", f"/rest/v1/{table}?select={column}"))
        return {str(x[column]).lower() for x in rows if x.get(column)}
    except RuntimeError as exc:
        print(f"Warning: cannot identify {table} IDs ({exc}); using managers/ as fallback.")
        return set()


def source_url(value):
    try:
        u = urlsplit(value)
        m = MARKER.match(u.path)
        if m and m.group(1) in LEGACY:
            return m.group(1), unquote(m.group(2))
    except (ValueError, TypeError):
        pass
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="Copy and update instead of dry-run")
    args = parser.parse_args()
    base = os.environ.get("SUPABASE_URL", "").rstrip("/")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
    if not base.startswith("https://") or not key:
        sys.exit("Set SUPABASE_URL (https://...) and SUPABASE_SERVICE_ROLE_KEY as environment variables.")

    stylists = auth_ids(base, key, "stylists", "profile_id")
    customers = auth_ids(base, key, "customers", "customer_id")
    found = migrated = 0
    for table, pk, column in TABLES:
        rows = get_rows(base, key, table, pk, column)
        for row in rows:
            old_url = row.get(column)
            source = source_url(old_url)
            if not source:
                continue
            bucket, original_name = source
            if table == "profiles":
                uid = str(row[pk]).lower()
                folder = "stylists" if uid in stylists else ("customers" if uid in customers else "managers")
            elif table == "services":
                folder = "services"
            elif table == "promotions":
                folder = "promotions"
            else:
                folder = "salon"

            ext = os.path.splitext(original_name)[1].lower()
            if ext not in (".jpg", ".jpeg", ".png", ".gif", ".webp"):
                print(f"SKIP unsupported image type: {bucket}/{original_name}")
                continue
            fingerprint = hashlib.sha256(f"{bucket}/{original_name}".encode()).hexdigest()[:24]
            dest = f"{folder}/legacy/{fingerprint}{ext}"
            new_url = f"{base}/storage/v1/object/public/{BUCKET}/{dest}"
            found += 1
            print(f"{table}.{column} [{pk}={row[pk]}]: {bucket}/{original_name} -> {BUCKET}/{dest}")
            if not args.apply:
                continue
            try:
                old_path = f"/storage/v1/object/public/{bucket}/{quote(original_name, safe='/')}"
                data = api(base, key, "GET", old_path)
                if len(data) > 5242880:
                    print("  SKIP image larger than 5MB; increase bucket limit and retry if appropriate")
                    continue
                new_path = f"/storage/v1/object/{BUCKET}/{quote(dest, safe='/')}"
                ctype = mimetypes.guess_type(dest)[0] or "application/octet-stream"
                try:
                    api(base, key, "POST", new_path, data, ctype)
                except RuntimeError as e:
                    if "HTTP 409" not in str(e):
                        raise
                check_path = f"/storage/v1/object/public/{BUCKET}/{quote(dest, safe='/')}"
                copied = api(base, key, "GET", check_path)
                if hashlib.sha256(copied).digest() != hashlib.sha256(data).digest():
                    raise RuntimeError("Copied image checksum mismatch; database URL left unchanged")
                patch_path = f"/rest/v1/{table}?{pk}=eq.{quote(str(row[pk]), safe='')}"
                payload = json.dumps({column: new_url}).encode("utf-8")
                api(base, key, "PATCH", patch_path, payload, "application/json")
                migrated += 1
                print("  OK: copied and database URL updated")
            except Exception as exc:
                print(f"  ERROR: {exc}")
    print(f"Found {found} image references; {'updated '+str(migrated) if args.apply else 'dry-run only, nothing changed'}.")
    print("Original images and legacy buckets were NOT deleted.")


if __name__ == "__main__":
    main()
