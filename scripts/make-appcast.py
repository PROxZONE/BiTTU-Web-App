#!/usr/bin/env python3
"""Generate/merge a Sparkle appcast entry (Phase 4: Distribution).

Usage:
  make-appcast.py appcast.xml --url <dmg download url> --version <ver> \
      --sparkle-version <sparkle:version build no> --signature <edDSA sig> \
      --length <bytes> [--pubkey <SUPublicEDKey>]

Existing entries for other versions are preserved; the newest stays first.
"""
import argparse
import xml.etree.ElementTree as ET

ET.register_namespace("sparkle", "http://www.andymatuschak.org/xml-namespaces/sparkle")
SPARKLE_NS = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("appcast", help="path to appcast.xml (created if absent)")
    parser.add_argument("--url", required=True)
    parser.add_argument("--version", required=True, help="human version, e.g. 1.0.1")
    parser.add_argument("--sparkle-version", required=True, help="build number for sparkle:version")
    parser.add_argument("--signature", required=True, help="EdDSA signature from sign_update")
    parser.add_argument("--length", type=int, required=True)
    parser.add_argument("--pubkey", default="", help="SUPublicEDKey for the enclosing channel")
    args = parser.parse_args()

    try:
        tree = ET.parse(args.appcast)
        root = tree.getroot()
    except FileNotFoundError:
        root = ET.Element("rss", {"version": "2.0"})
        channel = ET.SubElement(root, "channel")
        ET.SubElement(channel, "title").text = "BiTTU Web App"
        ET.SubElement(channel, "link").text = "https://github.com/PROxZONE/BiTTU-Web-App"
        ET.SubElement(channel, "description").text = "BiTTU browser updates"

    channel = root.find("channel")
    if channel is None:
        channel = root

    # Drop any stale entry for this build, keep others.
    for item in list(channel.findall("item")):
        build = item.find(f"{SPARKLE_NS}version")
        if build is not None and build.text == args.sparkle_version:
            channel.remove(item)

    item = ET.Element("item")
    ET.SubElement(item, "title").text = f"BiTTU {args.version}"
    pub = ET.SubElement(item, "pubDate")
    import email.utils

    pub.text = email.utils.formatdate(usegmt=True)
    build = ET.SubElement(item, f"{SPARKLE_NS}version")
    build.text = args.sparkle_version
    short = ET.SubElement(item, f"{SPARKLE_NS}shortVersionString")
    short.text = args.version
    enclosure = ET.SubElement(item, "enclosure")
    enclosure.set("url", args.url)
    enclosure.set("length", str(args.length))
    enclosure.set("type", "application/x-bzip2")
    enclosure.set(f"{SPARKLE_NS}edSignature", args.signature)

    channel.insert(0, item)
    tree = ET.ElementTree(root)
    tree.write(args.appcast, encoding="utf-8", xml_declaration=True)
    print(f"appcast: added {args.version} (build {args.sparkle_version})")


if __name__ == "__main__":
    main()