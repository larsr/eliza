"""
eliza_parse.py — parse the original Weizenbaum 1966 DOCTOR script
(S-expression form, as transcribed by Anthony Hay at elizagen.org).

Output is a small in-memory record form that both engines can consume.
This module does NOT compile anything to regex; that's eliza_compile's job.

Tag resolution (DLIST) happens here so both engines see a fully resolved
{tag: {word, ...}} dict and don't have to recompute it.

End-of-script: the original MAD source treats an empty parenthesised
expression () as terminator; LISTRD reads it, sees LISTMT.(INPUT) .E. 0,
prints the greeting, and jumps to START.  We follow the same convention.

Public API:
    parse_file(path)            -> ParsedScript
    parse_text(text)            -> ParsedScript

ParsedScript fields:
    greeting:    str
    subst:       {word: word}
    rank:        {keyword: int}                # every keyword present, 0 default
    equiv:       {keyword: keyword}
    tags:        {tag: frozenset(word, ...)}
    rules:       {keyword: [(decomp, reassemblies), ...]}
                  where decomp is a list of atoms and each reassembly is
                  also a list of atoms (or one of the special forms below)
    memory_key:  keyword
    memory:      [(decomp, reassembly), ...]
    none:        [reassembly, ...]

Atoms (in decompositions and reassemblies):
    "0"                       -- wildcard, 0+ words
    "1","2",...               -- integer atoms; in decomp = N-word group,
                                 in reassembly = backref to group N
    "WORD"                    -- literal word
    ("*","A","B",...)         -- any one of these words
    ("/","TAG1","TAG2",...)   -- any word tagged TAG1 or TAG2 ...

Special reassemblies (for non-MEMORY rules):
    ("NEWKEY",)               -- abandon this keyword
    ("=KEY",)                 -- dispatch to keyword KEY's rules
    ("PRE", (template), ("=KEY",))   -- pre-transform, then dispatch
"""
from dataclasses import dataclass, field


# ---------------------------------------------------------------------------
# S-expression tokenizer / parser
# ---------------------------------------------------------------------------

def _sexp_tokens(text):
    """Strip ';' comments; yield tokens: '(', ')', or atom-string."""
    out = []
    for line in text.splitlines():
        line = line.split(";", 1)[0]
        line = line.replace("(", " ( ").replace(")", " ) ")
        out.extend(line.split())
    return out


def _parse_sexp(tokens, i=0):
    tok = tokens[i]
    if tok == "(":
        items = []
        i += 1
        while tokens[i] != ")":
            item, i = _parse_sexp(tokens, i)
            items.append(item)
        return items, i + 1
    return tok, i + 1


def _parse_all(text):
    toks = _sexp_tokens(text)
    exprs, i = [], 0
    while i < len(toks):
        e, i = _parse_sexp(toks, i)
        exprs.append(e)
    return exprs


# ---------------------------------------------------------------------------
# Atom normalisation: handle glued prefixes like /BELIEF and =WHAT
# ---------------------------------------------------------------------------

def _normalise_atom(atom):
    """Recursively normalise. Returns the atom in canonical form:
       a tagged-word group becomes a tuple ('/', tag, ...);
       an alternation becomes ('*', word, ...);
       a glued '=KEY' becomes the string '=KEY' (unchanged).
       Numbers and words are returned as-is.
    """
    if isinstance(atom, list):
        if not atom:
            return atom
        first = atom[0]
        # ('*', words...)  -- alternation
        if first == "*":
            return ["*"] + atom[1:]
        if isinstance(first, str) and first.startswith("*") and len(first) > 1:
            # Glued: (*SAD UNHAPPY ...) parsed as ['*SAD','UNHAPPY',...]
            return ["*", first[1:]] + atom[1:]
        # ('/', tags...)  -- tagged-word group
        if first == "/":
            return ["/"] + atom[1:]
        if isinstance(first, str) and first.startswith("/") and len(first) > 1:
            return ["/", first[1:]] + atom[1:]
        # General list: normalise recursively
        return [_normalise_atom(a) for a in atom]
    return atom


# ---------------------------------------------------------------------------
# Recognise the six rule forms (R1–R6) plus MEMORY, NONE, greeting, ()-end
# ---------------------------------------------------------------------------

def _is_int(s):
    return isinstance(s, str) and s.isdigit()


def _parse_record(expr):
    """Take one top-level S-expression and return a normalised dict."""
    # Bare atom (e.g. START)
    if isinstance(expr, str):
        return {"kind": "BARE", "value": expr}

    # Empty list () = end-of-script terminator
    if expr == []:
        return {"kind": "END"}

    # MEMORY rule
    if expr[0] == "MEMORY":
        key = expr[1]
        rules = []
        for spec in expr[2:]:
            eq = spec.index("=")
            decomp = [_normalise_atom(a) for a in spec[:eq]]
            reasm  = [_normalise_atom(a) for a in spec[eq + 1:]]
            rules.append((decomp, reasm))
        return {"kind": "MEMORY", "key": key, "rules": rules}

    # NONE rule
    if expr[0] == "NONE":
        body = expr[1]
        decomp = [_normalise_atom(a) for a in body[0]]
        reasms = [[_normalise_atom(a) for a in r] for r in body[1:]]
        return {"kind": "NONE", "decomp": decomp, "reassemblies": reasms}

    # Greeting: a parenthesised sentence with no internal lists and no '='
    if all(isinstance(x, str) for x in expr) and "=" not in expr:
        return {"kind": "GREETING", "text": " ".join(expr)}

    # General keyword form: header atoms followed by body groups
    header_end = next((i for i, e in enumerate(expr) if isinstance(e, list)),
                      len(expr))
    header = expr[:header_end]
    body = expr[header_end:]
    return _parse_keyword(header, body)


def _parse_keyword(header, body_groups):
    key = header[0]
    rec = {"kind": "KEYWORD", "key": key}
    i = 1
    if i + 1 < len(header) and header[i] == "=":
        rec["sub"] = header[i + 1]
        i += 2
    if i < len(header) and _is_int(header[i]):
        rec["rank"] = int(header[i])
        i += 1
    # 'DLIST' marker is followed by a (/TAG...) group as the next body item
    if i < len(header) and header[i] == "DLIST":
        i += 1

    rules = []
    for group in body_groups:
        # (= OTHER) equivalence link, either spaced or glued
        if group and isinstance(group[0], str):
            if group[0] == "=" and len(group) == 2:
                rec["equiv"] = group[1]
                continue
            if group[0].startswith("=") and len(group) == 1:
                rec["equiv"] = group[0][1:]
                continue
        # DLIST contents (/TAG ...) or (/ TAG ...)
        if group and isinstance(group[0], str) and group[0].startswith("/"):
            first = group[0][1:]
            rest = group[1:]
            rec["dlist"] = ([first] if first else []) + list(rest)
            continue
        # Standard R1 form: ((decomp...) (reasm) (reasm) ...)
        if group and isinstance(group[0], list):
            decomp = [_normalise_atom(a) for a in group[0]]
            reasms = [[_normalise_atom(a) for a in r] for r in group[1:]]
            rules.append((decomp, reasms))
            continue
        # Anything else: keep for inspection but don't choke
        rec.setdefault("other", []).append(group)

    if rules:
        rec["rules"] = rules
    return rec


# ---------------------------------------------------------------------------
# Build the final ParsedScript
# ---------------------------------------------------------------------------

@dataclass
class ParsedScript:
    greeting:   str
    subst:      dict
    rank:       dict
    equiv:      dict
    tags:       dict                 # tag -> frozenset of words
    rules:      dict                 # keyword -> [(decomp, [reasm, ...]), ...]
    memory_key: str
    memory:     list                 # [(decomp, reasm), ...]
    none:       list                 # [reasm, ...]


def _build(records):
    greeting   = "HOW DO YOU DO. PLEASE TELL ME YOUR PROBLEM"
    subst      = {}
    rank       = {}
    equiv      = {}
    tags       = {}                  # mutable for build, frozen at end
    rules      = {}
    memory_key = None
    memory     = []
    none       = []

    # Single pass: collect everything. () terminates.
    greeting_seen = False
    for rec in records:
        kind = rec.get("kind")
        if kind == "END":
            break
        if kind == "BARE":
            continue                  # ignore stray atoms like START
        if kind == "GREETING":
            if not greeting_seen:
                greeting = rec["text"]
                greeting_seen = True
            continue
        if kind == "MEMORY":
            memory_key = rec["key"]
            memory.extend(rec["rules"])
            continue
        if kind == "NONE":
            none = rec["reassemblies"]
            continue
        # KEYWORD
        key = rec["key"]
        if "sub" in rec:
            subst[key] = rec["sub"]
        if "rank" in rec:
            rank[key] = rec["rank"]
        if "equiv" in rec:
            equiv[key] = rec["equiv"]
        if "dlist" in rec:
            for tag in rec["dlist"]:
                tags.setdefault(tag, set()).add(rec.get("sub", key))
        if "rules" in rec:
            rules[key] = rec["rules"]

    # Default rank 0 for every keyword that has rules or an equiv link
    for k in set(rules) | set(equiv):
        rank.setdefault(k, 0)

    return ParsedScript(
        greeting   = greeting,
        subst      = subst,
        rank       = rank,
        equiv      = equiv,
        tags       = {t: frozenset(ws) for t, ws in tags.items()},
        rules      = rules,
        memory_key = memory_key,
        memory     = memory,
        none       = none,
    )


# ---------------------------------------------------------------------------
# Public entry points
# ---------------------------------------------------------------------------

def parse_text(text):
    exprs = _parse_all(text)
    records = [_parse_record(e) for e in exprs]
    return _build(records)


def parse_file(path):
    with open(path) as f:
        return parse_text(f.read())


# ---------------------------------------------------------------------------
# Self-test
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import sys
    s = parse_file(sys.argv[1] if len(sys.argv) > 1 else "doctor.script")
    print(f"greeting:   {s.greeting!r}")
    print(f"rules:      {len(s.rules)} keywords")
    print(f"subst:      {len(s.subst)} entries")
    print(f"equiv:      {len(s.equiv)} entries")
    print(f"tags:       {dict((t, sorted(ws)) for t, ws in s.tags.items())}")
    print(f"memory_key: {s.memory_key}")
    print(f"memory:     {len(s.memory)} rules")
    print(f"none:       {len(s.none)} reassemblies")
