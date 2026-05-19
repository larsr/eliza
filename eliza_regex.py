"""
eliza.py — the regex-based ELIZA runtime.

Loads a compiled script (as produced by eliza_compile.py), then drives the
conversation. The whole engine is a small loop over keystack + rule list.

Usage:
    python eliza.py doctor.json
"""
import json
import re
import sys


# ---------------------------------------------------------------------------
# Scan: pick one clause, find keywords, apply substitutions
# ---------------------------------------------------------------------------

def scan(text, script, subst_re, key_re):
    """Return (anchored_text, keystack).

    - anchored_text: ' WORD WORD WORD ' with leading + trailing space, after
      word-level substitutions have been applied.
    - keystack: list of original (pre-substitution) keywords ordered by rank,
      highest first; ties keep scan order.
    """
    text = text.upper()
    text = re.sub(r"[^A-Z',. ]+", " ", text)

    # Pick the right clause: first clause containing a keyword, else last.
    # Delimiters per the 1965 MAD source (line 000660): comma, period, BUT.
    clauses = re.split(r"[.,]|\bBUT\b", text)
    keys_per_clause = [key_re.findall(c) for c in clauses]
    chosen = next((i for i, k in enumerate(keys_per_clause) if k),
                  len(clauses) - 1)
    clause = clauses[chosen]
    keys = sorted(keys_per_clause[chosen],
                  key=lambda k: -script["rank"][k])

    # Apply substitutions to the chosen clause
    subst = subst_re.sub(lambda m: script["subst"][m.group(1)], clause)
    anchored = " " + " ".join(subst.split()) + " "
    return anchored, keys


# ---------------------------------------------------------------------------
# Try one keyword: walk its compiled rules, handle the four reassembly kinds
# ---------------------------------------------------------------------------

def try_key(key, text, script, cur, seen):
    if key in seen:
        return None
    seen = seen | {key}

    # Pure equivalence link (no rules of its own): dispatch and stop
    if key in script["equiv"] and key not in script["rules"]:
        return try_key(script["equiv"][key], text, script, cur, seen)

    for di, rule in enumerate(script["rules"].get(key, [])):
        if not rule["regex_compiled"].match(text):
            continue
        reasms = rule["reassemblies"]
        i = cur.get((key, di), 0)
        cur = {**cur, (key, di): i + 1}
        r = reasms[i % len(reasms)]

        if r["kind"] == "NEWKEY":
            return None
        if r["kind"] == "LINK":
            res = try_key(r["target"], text, script, cur, seen)
            if res is not None:
                return res
            continue
        if r["kind"] == "PRE":
            pre_text = " " + rule["regex_compiled"].sub(r["template"], text).strip() + " "
            pre_text = re.sub(r"\s+", " ", pre_text)
            res = try_key(r["target"], pre_text, script, cur, seen)
            if res is not None:
                return res
            continue
        # REASM
        out = rule["regex_compiled"].sub(r["template"], text).strip()
        return re.sub(r"\s+", " ", out), cur
    return None


# ---------------------------------------------------------------------------
# Memory + top-level respond
# ---------------------------------------------------------------------------

def store_memory(text, script, cur, mem):
    idx = cur.get("@MI", 0) % len(script["memory"])
    rule = script["memory"][idx]
    if not rule["regex_compiled"].match(text):
        return cur, mem
    line = re.sub(r"\s+", " ",
                  rule["regex_compiled"].sub(rule["template"], text).strip())
    return {**cur, "@MI": cur.get("@MI", 0) + 1}, mem + (line,)


def respond(state, text, script, subst_re, key_re):
    cur = dict(state.get("cur", {}))
    mem = state.get("mem", ())

    anchored, keys = scan(text, script, subst_re, key_re)

    if script["memory_key"] and script["memory_key"] in keys:
        cur, mem = store_memory(anchored, script, cur, mem)

    for k in keys:
        res = try_key(k, anchored, script, cur, frozenset())
        if res is not None:
            reply, cur = res
            return {"cur": cur, "mem": mem}, reply

    if mem:
        return {"cur": cur, "mem": mem[1:]}, mem[0]

    i = cur.get("@N", 0)
    cur = {**cur, "@N": i + 1}
    return {"cur": cur, "mem": mem}, script["none"][i % len(script["none"])]


# ---------------------------------------------------------------------------
# Loading: precompile all regexes once
# ---------------------------------------------------------------------------

def load_script(path):
    with open(path) as f:
        script = json.load(f)

    for rule_list in script["rules"].values():
        for rule in rule_list:
            rule["regex_compiled"] = re.compile(rule["regex"])
    for rule in script["memory"]:
        rule["regex_compiled"] = re.compile(rule["regex"])

    subst_words = sorted(script["subst"], key=len, reverse=True)
    # Use lookarounds that treat apostrophe as part of the surrounding word,
    # so 'I' doesn't match inside "I'M" and 'CAN' doesn't match inside "CAN'T".
    subst_re = re.compile(
        r"(?<![A-Z'])(" + "|".join(re.escape(w) for w in subst_words)
        + r")(?![A-Z'])"
    )

    all_keys = set(script["rules"]) | set(script["equiv"])
    key_re = re.compile(
        r"(?<![A-Z'])(" + "|".join(re.escape(k) for k in all_keys)
        + r")(?![A-Z'])"
    )

    return script, subst_re, key_re


# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------

def main(argv):
    path = argv[1] if len(argv) > 1 else "doctor.json"
    script, subst_re, key_re = load_script(path)
    state = {}

    print("ELIZA:", script["greeting"])

    if not sys.stdin.isatty():
        for line in sys.stdin:
            line = line.rstrip("\n")
            if not line:
                continue
            print(f"YOU : {line}")
            state, reply = respond(state, line, script, subst_re, key_re)
            print(f"ELIZA: {reply}")
        return

    try:
        while True:
            line = input("YOU : ")
            if not line:
                continue
            state, reply = respond(state, line, script, subst_re, key_re)
            print(f"ELIZA: {reply}")
    except (EOFError, KeyboardInterrupt):
        print()


if __name__ == "__main__":
    main(sys.argv)
