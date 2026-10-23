#!/usr/bin/env python3
"""Build matrix generator.

Reads versions.json, asks Docker Hub for the current tags of the official
``postgres`` image, and prints a GitHub Actions matrix (JSON) with one entry per
(base image variant, dataset, size).  Every entry carries the full list of
image tags to publish: each official postgres tag that points at the chosen
base image, with the dataset suffix appended.

Tag rules (base tag ``B``, dataset ``D``, size ``S``):

    B-D-S                      always (``latest`` base tag contributes ``D-S``)
    B-S                        when D is the newest dataset
    B-D                        when S is the default size
    B                          when D is newest and S is default (``latest`` -> ``latest``)

Usage: scripts/matrix.py [--dataset V] [--size S] [--pg MAJOR] [--variant NAME]
Filters accept comma separated lists; empty means all.
"""
import argparse
import json
import re
import sys
import urllib.request

HUB = "https://hub.docker.com/v2/repositories/library/postgres/tags"
MAJORLESS = ("latest", "alpine", "bookworm", "trixie", "bullseye")


def hub_tags(major):
    """Return {tag: digest} for every current tag of the given major, plus the majorless aliases."""
    tags = {}
    url = f"{HUB}?page_size=100&name={major}"
    pat = re.compile(rf"^{major}(\.\d+)?(-[a-z0-9.]+)?$")
    while url:
        with urllib.request.urlopen(url) as r:
            page = json.load(r)
        for t in page["results"]:
            if pat.match(t["name"]) and t.get("digest"):
                tags[t["name"]] = t["digest"]
        url = page.get("next")
    for name in MAJORLESS:
        try:
            with urllib.request.urlopen(f"{HUB}/{name}") as r:
                t = json.load(r)
            if t.get("digest"):
                tags[name] = t["digest"]
        except Exception:
            pass
    return tags


def minor_of(tag):
    m = re.match(r"^\d+\.(\d+)", tag)
    return int(m.group(1)) if m else None


def variants(major):
    """Group current tags by digest; keep groups that carry the latest minor release."""
    tags = hub_tags(major)
    minors = [minor_of(t) for t in tags if minor_of(t) is not None]
    if not minors:
        sys.exit(f"matrix: no release tags found for postgres {major}")
    latest_minor = max(minors)
    groups = {}
    for tag, digest in tags.items():
        groups.setdefault(digest, []).append(tag)
    out = []
    for digest, names in groups.items():
        if not any(minor_of(n) == latest_minor for n in names):
            continue
        if not any(n.startswith(f"{major}") for n in names):
            continue
        # most specific tag, e.g. 18.6-alpine3.24, becomes the FROM reference
        canonical = max(names, key=lambda n: (n.count("."), n.count("-"), len(n)))
        suffix = canonical.split("-", 1)[1] if "-" in canonical else "debian"
        out.append({
            "variant": f"{major}-{suffix}",
            "base_tag": canonical,
            "base_image": f"postgres:{canonical}@{digest}",
            "base_tags": sorted(names),
        })
    return sorted(out, key=lambda v: v["variant"])


def image_tags(base_tags, dataset, size, newest_dataset, default_size):
    tags = []
    for b in base_tags:
        prefix = "" if b == "latest" else f"{b}-"
        tags.append(f"{prefix}{dataset}-{size}")
        if newest_dataset:
            tags.append(f"{prefix}{size}")
        if size == default_size:
            tags.append(f"{prefix}{dataset}")
            if newest_dataset:
                tags.append(b)
    return tags


def main():
    ap = argparse.ArgumentParser()
    for f in ("dataset", "size", "pg", "variant"):
        ap.add_argument(f"--{f}", default="")
    args = ap.parse_args()
    want = {f: set(x for x in getattr(args, f).split(",") if x) for f in ("dataset", "size", "pg", "variant")}

    cfg = json.load(open("versions.json"))
    newest = max(d["version"] for d in cfg["datasets"])
    include = []
    for ds in cfg["datasets"]:
        if want["dataset"] and ds["version"] not in want["dataset"]:
            continue
        for major in ds["pg"]:
            if want["pg"] and major not in want["pg"]:
                continue
            for v in variants(major):
                if want["variant"] and v["variant"] not in want["variant"]:
                    continue
                for size, info in ds["sizes"].items():
                    if want["size"] and size not in want["size"]:
                        continue
                    tags = image_tags(v["base_tags"], ds["version"], size, ds["version"] == newest, cfg["default_size"])
                    include.append({
                        "id": f"{v['variant']}-{ds['version']}-{size}",
                        "variant": v["variant"],
                        "base_image": v["base_image"],
                        "base_tag": v["base_tag"],
                        "dataset": ds["version"],
                        "size": size,
                        "sha256": info["sha256"],
                        "test": bool(info.get("test", True)),
                        "tags": "\n".join(tags),
                    })
    if not include:
        sys.exit("matrix: nothing selected")
    print(json.dumps({"include": include}, separators=(",", ":")))


if __name__ == "__main__":
    main()
