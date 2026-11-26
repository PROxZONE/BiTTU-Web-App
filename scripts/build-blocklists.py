#!/usr/bin/env python3
"""Convert AdBlock/EasyList-format filter lists to WebKit content-blocker JSON.

Usage: build-blocklists.py <filters.txt> <out.json> [max-rules]

Handles the subset of AdBlock syntax WebKit can express:
  ||host^        -> url-filter anchored on the host
  pattern        -> plain url-filter substring
  @@...          -> ignore-previous-rules (skip if generic)
  $option,...    -> third-party, script, image, stylesheet, subdocument,
                    xmlhttprequest, font, media, domain=/~domain
  ##selector     -> css-display-none (generic)
  host##selector -> css-display-none scoped with if-domain
  |anchor        -> leading/trailing url-filter anchors
Unsupported options (popup, webrtc, match-case, genericblock, ...) drop the rule.
WebKit caps a compiled rule list at 50,000 rules, so output is capped.
"""

import json
import re
import sys

# WebKit's compiled rule-list limit.
DEFAULT_CAP = 50000

RESOURCE_TYPES = {
    "script": "script",
    "image": "image",
    "stylesheet": "stylesheet",
    "subdocument": "sub-frame",
    "xmlhttprequest": "xmlhttprequest",
    "font": "font",
    "media": "media",
    "ping": "ping",
    "websocket": "raw",
    "other": "raw",
}

# Options that must not appear in a converted rule.
UNSUPPORTED_OPTIONS = {
    "popup", "webrtc", "match-case", "genericblock", "generichide",
    "elemhide", "jsinject", "dnt", "collapse", "important",
}

SEP = r"(?:[^\w\d.\-%]|$)"


def escape_literal(text: str) -> str:
    out = []
    for ch in text:
        if ch == "*":
            out.append(".*")
        elif ch == "^":
            out.append(SEP)
        elif ch in ".+?()[]{}|^$":
            out.append("\\" + ch)
        else:
            out.append(re.escape(ch))
    return "".join(out)


def host_pattern(host: str) -> str:
    """||host^ -> filter matching host or any subdomain, with separator end."""
    host = host.rstrip("^")
    return r"^[^:]+://(?:[^/]+\.)?" + escape_literal(host) + "(?:" + SEP + "|[/?])"


def build_trigger(pattern: str, options: dict) -> dict:
    trigger = {"url-filter": pattern}
    if options.get("third_party") is True:
        trigger["load-type"] = ["third-party"]
    elif options.get("third_party") is False:
        trigger["load-type"] = ["first-party"]
    if options.get("domains"):
        trigger["if-domain"] = ["*" + d.lstrip("~") for d in options["domains"]]
    if options.get("not_domains"):
        trigger["unless-domain"] = ["*" + d.lstrip("~") for d in options["not_domains"]]
    types = sorted({RESOURCE_TYPES[o] for o in options.get("types", []) if o in RESOURCE_TYPES})
    if types:
        trigger["resource-type"] = types
    return trigger


def parse_options(option_str: str) -> dict:
    options = {"types": [], "domains": [], "not_domains": []}
    for opt in option_str.split(","):
        opt = opt.strip()
        if not opt:
            continue
        neg = opt.startswith("~")
        body = opt[1:] if neg else opt
        if body.startswith("domain="):
            for d in body[7:].split("|"):
                d = d.strip()
                if not d:
                    continue
                (options["not_domains"] if d.startswith("~") else options["domains"]).append(d)
        elif body in RESOURCE_TYPES:
            if not neg:
                options["types"].append(body)
        elif body == "third-party":
            options["third_party"] = not neg
        elif body in UNSUPPORTED_OPTIONS:
            options["unsupported"] = True
    return options


def convert_filter(line: str) -> list:
    line = line.strip()
    if not line or line.startswith(("!", "[Adblock", "# ")):
        return []

    # Element hiding.
    if "##" in line:
        domains, _, selector = line.partition("##")
        selector = selector.strip()
        if not selector or selector.startswith("#@#") or "#@#" in line:
            return []
        rule = {"action": {"type": "css-display-none", "selector": selector}}
        if domains:
            rule["trigger"] = {"url-filter": ".*",
                               "if-domain": ["*" + d for d in domains.split(",") if d]}
        else:
            rule["trigger"] = {"url-filter": ".*"}
        return [rule]

    exception = line.startswith("@@")
    if exception:
        line = line[2:]

    # Option list after the last $.
    options = {"types": [], "domains": [], "not_domains": []}
    if "$" in line:
        body, _, opt_str = line.rpartition("$")
        # A $ inside a regex-style pattern is not an option separator; heuristic:
        # option lists contain only word characters, commas, ~, =, |.
        if re.fullmatch(r"[\w~,=|.-]+", opt_str):
            line = body
            options = parse_options(opt_str)
            if options.get("unsupported"):
                return []

    leading_anchor = line.startswith("|")
    line = line[1:] if leading_anchor else line
    trailing_anchor = line.endswith("|")
    line = line[:-1] if trailing_anchor else line
    if not line or line.startswith("@@"):
        return []

    pattern = escape_literal(line)
    if leading_anchor and "://" not in line and not line.startswith("*"):
        # Host-anchored shorthand || was already handled by escape_literal's '*\';
        # treat "||host" specifically below.
        pass
    if line.startswith("|"):
        pattern = escape_literal(line[1:])
    # A filter starting with || (escape_literal turned || into ^[^:]+://...)
    if line.startswith("||"):
        pattern = host_pattern(line[2:])

    if len(pattern) < 3:
        return []

    action = "ignore-previous-rules" if exception else "block"
    # Generic exceptions would un-block everything they match across all lists;
    # only keep exceptions scoped to a domain.
    if exception and not (options.get("domains") or options.get("not_domains")):
        return []
    return [{"trigger": build_trigger(pattern, options), "action": {"type": action}}]


def convert(path: str, cap: int) -> list:
    rules = []
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            rules.extend(convert_filter(line))
            if len(rules) >= cap:
                break
    return rules[:cap]


def main() -> None:
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    cap = int(sys.argv[3]) if len(sys.argv) > 3 else DEFAULT_CAP
    rules = convert(sys.argv[1], cap)

    # GitHub's contents API rejects payloads over ~1 MB, so split the output
    # into chunk files (easylist-001.json, ...); WebKit compiles each chunk
    # as its own rule list and ContentBlocker picks up every .json in the
    # blocklists folder.
    chunk = 8000
    stem = sys.argv[2][: -len(".json")]
    if len(rules) <= chunk:
        with open(sys.argv[2], "w", encoding="utf-8") as fh:
            json.dump(rules, fh, separators=(",", ":"))
        print(f"{sys.argv[2]}: {len(rules)} rules (cap {cap})")
        return
    for i in range(0, len(rules), chunk):
        part = rules[i:i + chunk]
        name = f"{stem}-{i // chunk + 1:03d}.json"
        with open(name, "w", encoding="utf-8") as fh:
            json.dump(part, fh, separators=(",", ":"))
        print(f"{name}: {len(part)} rules")
    print(f"{sys.argv[2]}: {len(rules)} rules in {(len(rules) + chunk - 1) // chunk} chunks (cap {cap})")


if __name__ == "__main__":
    main()