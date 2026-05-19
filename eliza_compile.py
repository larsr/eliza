"""
eliza_compile.py — compile a parsed ELIZA script to regex form, dump to JSON.

Reads the DOCTOR script via eliza_parse, then converts every decomposition
into a regex string and every reassembly into a substitution template with
\\N backreferences.  Result is dumped as JSON for the regex runtime to load.

Schema (consumed by eliza_regex.py):

  {
    "greeting":   str,
    "subst":      { word: word, ... },
    "rank":       { keyword: int, ... },         # every keyword has a rank
    "equiv":      { keyword: keyword, ... },
    "rules":      { keyword: [
                      { "regex": str,
                        "reassemblies": [ {kind, ...}, ... ] },
                      ...
                    ] },
    "memory_key": keyword,
    "memory":     [ { "regex": str, "template": str }, ... ],
    "none":       [ str, ... ]
  }

A reassembly is one of:
  {"kind": "REASM",  "template": "..."}        plain substitution template
  {"kind": "LINK",   "target":   "..."}        dispatch to another keyword
  {"kind": "PRE",    "template": "...",        pre-transform, then dispatch
                     "target":   "..."}
  {"kind": "NEWKEY"}                            give up, try next keyword

Anchored-string convention: the regex always matches a string of the form
'<space>WORD<space>WORD<space>...<space>'.  Every captured group includes
its own leading space, so reassembly templates concatenate cleanly: writing
'I AM\\4' produces 'I AM<space>WORD<space>...' on substitution.

Usage:
    python eliza_compile.py doctor.script doctor.json
"""
import json
import re
import sys

from eliza_parse import parse_file


# Regex piece that matches a single word with its leading whitespace.
WORD = r"\s\S+"


# ---------------------------------------------------------------------------
# Decomposition atom -> regex fragment.  Every fragment captures.
# ---------------------------------------------------------------------------

def atom_to_regex(atom, tags):
    if isinstance(atom, list):
        if atom[0] == "*":
            return "(" + "|".join(r"\s" + re.escape(w) for w in atom[1:]) + ")"
        if atom[0] == "/":
            words = sorted({w for tag in atom[1:] for w in tags.get(tag, ())})
            if not words:
                return r"(?!)"          # impossible-to-match alternation
            return "(" + "|".join(r"\s" + re.escape(w) for w in words) + ")"
        raise ValueError(f"bad sub-atom: {atom!r}")
    if atom == "0":
        return f"((?:{WORD})*)"
    if isinstance(atom, str) and atom.isdigit():
        return f"((?:{WORD}){{{int(atom)}}})"
    return r"(\s" + re.escape(atom) + ")"


def compile_decomp(pattern, tags):
    body = "".join(atom_to_regex(a, tags) for a in pattern)
    return r"^" + body + r"\s*$"


# ---------------------------------------------------------------------------
# Reassembly template -> substitution string with \N backrefs.
# ---------------------------------------------------------------------------

def compile_reassembly(template):
    out = ""
    for atom in template:
        if isinstance(atom, str) and atom.isdigit():
            out += rf"\{atom}"
        else:
            if out and not out.endswith(" ") and not atom.startswith(" "):
                out += " "
            out += atom
    return out.strip()


def compile_reasm_entry(reasm):
    """One reassembly -> tagged dict.  Recognises NEWKEY, =KEY, PRE forms."""
    if reasm == ["NEWKEY"]:
        return {"kind": "NEWKEY"}
    if (len(reasm) == 1 and isinstance(reasm[0], str)
            and reasm[0].startswith("=")):
        return {"kind": "LINK", "target": reasm[0][1:]}
    if (len(reasm) == 3 and reasm[0] == "PRE"
            and isinstance(reasm[1], list) and isinstance(reasm[2], list)
            and reasm[2][0].startswith("=")):
        return {"kind": "PRE",
                "template": compile_reassembly(reasm[1]),
                "target":   reasm[2][0][1:]}
    return {"kind": "REASM", "template": compile_reassembly(reasm)}


# ---------------------------------------------------------------------------
# Top-level: ParsedScript -> JSON dict
# ---------------------------------------------------------------------------

def compile_script(script):
    tags = script.tags

    rules = {}
    for key, rule_list in script.rules.items():
        rules[key] = [
            {"regex": compile_decomp(decomp, tags),
             "reassemblies": [compile_reasm_entry(r) for r in reasms]}
            for decomp, reasms in rule_list
        ]

    memory = [
        {"regex": compile_decomp(d, tags), "template": compile_reassembly(r)}
        for d, r in script.memory
    ]

    none = [compile_reassembly(r) for r in script.none]

    return {
        "greeting":   script.greeting,
        "subst":      script.subst,
        "rank":       script.rank,
        "equiv":      script.equiv,
        "rules":      rules,
        "memory_key": script.memory_key,
        "memory":     memory,
        "none":       none,
    }


# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------

def main(argv):
    if len(argv) != 3:
        print("usage: eliza_compile.py SCRIPT.script OUT.json", file=sys.stderr)
        sys.exit(1)
    script = parse_file(argv[1])
    compiled = compile_script(script)
    with open(argv[2], "w") as f:
        json.dump(compiled, f, indent=2)
    print(f"wrote {argv[2]}: "
          f"{len(compiled['rules'])} keyword rule-sets, "
          f"{len(compiled['memory'])} memory rules, "
          f"{len(compiled['subst'])} substitutions",
          file=sys.stderr)


if __name__ == "__main__":
    main(sys.argv)
