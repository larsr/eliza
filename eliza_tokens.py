"""
eliza_tokens.py — the token-based ELIZA engine.

Reads the original DOCTOR script via eliza_parse, then runs the conversation
by walking the parsed decomposition atoms directly: literal/wildcard/N-word/
alternation/tag-group are matched against the input token list with
backtracking. Reassemblies are built by interleaving literal words and
substituted match groups.

This is the "structural" implementation — atoms are atoms, not regex.

Usage:
    python eliza_tokens.py doctor.script
"""
import re
import sys

from eliza_parse import parse_file


# ---------------------------------------------------------------------------
# Tokenization
# ---------------------------------------------------------------------------

def tokenize(s):
    """Split on whitespace; isolate commas, periods, and the word BUT as
    delimiter tokens (per the original MAD source, line 000660)."""
    s = s.upper().replace(",", " , ").replace(".", " . ").replace("?", " ")
    # Tag BUT as a delimiter by rewriting it to a marker token. Apostrophe
    # is kept inside words so "I'M" stays one token.
    out = []
    for tok in s.split():
        if tok == "BUT":
            out.append("BUT")        # treated specially in scan()
        else:
            out.append(tok)
    return out


# ---------------------------------------------------------------------------
# Scan: pick a clause, build keystack, apply substitutions
# ---------------------------------------------------------------------------

DELIMS = {",", ".", "BUT"}


def scan(tokens, script):
    """Return (substituted_tokens, keystack).

    Scans the ORIGINAL tokens to identify keywords (so 'MY' is found even
    though its substitute is 'YOUR'). Produces the substituted token list
    that decomposition will operate on. Highest-rank keyword first; ties
    break by scan order (stable).
    """
    is_key = lambda t: t in script.rules or t in script.equiv
    kept, keys, found = [], [], False
    for t in tokens:
        if found and t in DELIMS:
            break
        if t in DELIMS:
            kept.clear()
            keys.clear()
            continue
        if is_key(t):
            found = True
            keys.append(t)
        kept.append(script.subst.get(t, t))
    keys.sort(key=lambda k: -script.rank[k])
    return kept, keys


# ---------------------------------------------------------------------------
# Decomposition match
# ---------------------------------------------------------------------------

def _atom_kind(atom, tags):
    """Return (kind, value) for one decomposition atom."""
    if isinstance(atom, list):
        if atom[0] == "*":
            return "ANY", set(atom[1:])
        if atom[0] == "/":
            words = set()
            for tag in atom[1:]:
                words |= tags.get(tag, frozenset())
            return "ANY", words
        raise ValueError(f"bad atom: {atom!r}")
    if atom == "0":
        return "WILD", None
    if isinstance(atom, str) and atom.isdigit():
        return "N", int(atom)
    return "LIT", atom


def match_decomp(pattern, tokens, tags):
    """Try to match pattern against the entire token list.
    Return a list of groups (one per atom) on success, else None.
    Wildcards are shortest-first for non-trailing positions; the trailing
    wildcard absorbs the remainder."""
    atoms = [_atom_kind(a, tags) for a in pattern]

    def go(ai, ti, acc):
        if ai == len(atoms):
            return acc if ti == len(tokens) else None
        kind, val = atoms[ai]
        rest = atoms[ai + 1:]

        if kind == "LIT":
            if ti < len(tokens) and tokens[ti] == val:
                return go(ai + 1, ti + 1, acc + [[val]])
            return None
        if kind == "ANY":
            if ti < len(tokens) and tokens[ti] in val:
                return go(ai + 1, ti + 1, acc + [[tokens[ti]]])
            return None
        if kind == "N":
            if ti + val <= len(tokens):
                return go(ai + 1, ti + val, acc + [tokens[ti:ti + val]])
            return None
        # WILD
        if not rest:
            return go(ai + 1, len(tokens), acc + [tokens[ti:]])
        for k in range(len(tokens) - ti + 1):
            r = go(ai + 1, ti + k, acc + [tokens[ti:ti + k]])
            if r is not None:
                return r
        return None

    return go(0, 0, [])


# ---------------------------------------------------------------------------
# Reassembly
# ---------------------------------------------------------------------------

def reassemble(template, groups):
    out = []
    for atom in template:
        if isinstance(atom, str) and atom.isdigit():
            out.extend(groups[int(atom) - 1])
        else:
            out.append(atom)
    return " ".join(out)


# ---------------------------------------------------------------------------
# Try one keyword: walk its decomps, handle NEWKEY / =KEY / PRE / REASM
# ---------------------------------------------------------------------------

def try_key(key, tokens, script, cur, seen):
    if key in seen:
        return None
    seen = seen | {key}

    # Pure equivalence link
    if key in script.equiv and key not in script.rules:
        return try_key(script.equiv[key], tokens, script, cur, seen)

    for di, (decomp, reasms) in enumerate(script.rules.get(key, [])):
        groups = match_decomp(decomp, tokens, script.tags)
        if groups is None:
            continue
        i = cur.get((key, di), 0)
        cur = {**cur, (key, di): i + 1}
        r = reasms[i % len(reasms)]

        # NEWKEY
        if r == ["NEWKEY"]:
            return None
        # (=KEY)  -- equivalence dispatch via reassembly
        if (len(r) == 1 and isinstance(r[0], str)
                and r[0].startswith("=") and len(r[0]) > 1):
            res = try_key(r[0][1:], tokens, script, cur, seen)
            if res is not None:
                return res
            continue
        # (PRE template (=KEY))
        if r and r[0] == "PRE":
            pre_tokens = reassemble(r[1], groups).split()
            target = r[2][0][1:]
            res = try_key(target, pre_tokens, script, cur, seen)
            if res is not None:
                return res
            continue
        # Plain reassembly
        return reassemble(r, groups), cur
    return None


# ---------------------------------------------------------------------------
# Memory + top-level respond
# ---------------------------------------------------------------------------

def store_memory(tokens, script, cur, mem):
    idx = cur.get("@MI", 0) % len(script.memory)
    decomp, reasm = script.memory[idx]
    groups = match_decomp(decomp, tokens, script.tags)
    if groups is None:
        return cur, mem
    line = reassemble(reasm, groups)
    return {**cur, "@MI": cur.get("@MI", 0) + 1}, mem + (line,)


def respond(state, text, script):
    cur = dict(state.get("cur", {}))
    mem = state.get("mem", ())

    tokens, keys = scan(tokenize(text), script)

    if script.memory_key and script.memory_key in keys:
        cur, mem = store_memory(tokens, script, cur, mem)

    for k in keys:
        res = try_key(k, tokens, script, cur, frozenset())
        if res is not None:
            reply, cur = res
            return {"cur": cur, "mem": mem}, reply

    if mem:
        return {"cur": cur, "mem": mem[1:]}, mem[0]

    i = cur.get("@N", 0)
    cur = {**cur, "@N": i + 1}
    # NONE templates: pass the whole token list as the single matched group,
    # since the implicit decomp is (0) which captures everything.
    return {"cur": cur, "mem": mem}, reassemble(script.none[i % len(script.none)], [tokens])


# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------

def main(argv):
    path = argv[1] if len(argv) > 1 else "doctor.script"
    script = parse_file(path)
    state = {}

    print("ELIZA:", script.greeting)

    if not sys.stdin.isatty():
        for line in sys.stdin:
            line = line.rstrip("\n")
            if not line:
                continue
            print(f"YOU : {line}")
            state, reply = respond(state, line, script)
            print(f"ELIZA: {reply}")
        return

    try:
        while True:
            line = input("YOU : ")
            if not line:
                continue
            state, reply = respond(state, line, script)
            print(f"ELIZA: {reply}")
    except (EOFError, KeyboardInterrupt):
        print()


if __name__ == "__main__":
    main(sys.argv)
