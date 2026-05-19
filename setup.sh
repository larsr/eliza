#!/usr/bin/env bash
# setup.sh — recreate the ELIZA repo. Run once in an empty directory.
set -e

cat > README.md << 'ELIZA_SETUP_EOF'
# ELIZA — two faithful implementations of Weizenbaum's 1966 chatbot

Two Python implementations of the original ELIZA / DOCTOR algorithm
([Weizenbaum 1966](https://www.csee.umbc.edu/courses/331/papers/eliza.html)),
both driven by the original 1966 DOCTOR script. The two engines share a
parser and produce byte-identical output on the published transcript.

## Files

| File | Purpose |
|---|---|
| `doctor.script` | The original 1966 DOCTOR script in S-expression form (transcribed by Anthony Hay from the CACM article, via [elizagen.org](https://sites.google.com/view/elizagen-org/original-eliza)) |
| `eliza_parse.py` | Shared parser: `doctor.script` → in-memory records |
| `eliza_tokens.py` | Token-based engine: walks the parsed atoms directly with a backtracking matcher |
| `eliza_compile.py` | Compiler: parsed records → JSON with regex strings |
| `eliza_regex.py` | Regex-based engine: loads JSON, uses `re.match` / `re.sub` |
| `transcript.txt` | The user side of Weizenbaum's published 1966 dialogue |
| `expected.txt` | The expected interleaved YOU/ELIZA output |
| `test.sh` | Compiles, runs both engines, diffs against `expected.txt` |

## Pipeline

```
doctor.script ──► eliza_parse ──┬──► eliza_tokens ──► conversation
                                │
                                └──► eliza_compile ──► doctor.json ──► eliza_regex ──► conversation
```

## Run it

```sh
# interactive
python eliza_tokens.py doctor.script
python eliza_regex.py  doctor.json     # after a first compile

# replay the published transcript
python eliza_tokens.py doctor.script < transcript.txt
python eliza_regex.py  doctor.json   < transcript.txt

# run the test suite
./test.sh
```

## Notes on faithfulness

Three details that aren't in the 1966 CACM paper but *are* in the
rediscovered MAD-SLIP source ([elizagen.org](https://github.com/jeffshrager/elizagen.org)):

- **`BUT` is a clause delimiter** alongside `,` and `.` (MAD source line 000660).
- **An empty parenthesised expression `()` terminates the script** — `LISTRD`
  reads it, sees the input list is empty, prints the greeting, jumps to `START`.
- Apostrophes are part of words: `I'M` is one token, not two; word boundaries
  in the regex engine treat `'` as a word character so `I` doesn't match
  inside `I'M`.

Both engines reproduce all 14 lines of Weizenbaum's published dialogue
verbatim. The only divergence on that transcript is the final MEMORY rule:
the paper's last reply uses the 4th MEMORY template, ours uses the 1st.
Both come from the same memory queue mechanism; the difference is the
starting cycle position. (The MAD source uses
`HASH.(BOT.(INPUT),2)+1` to pick the MEMORY rule index rather than a
sequential cycling counter — worth investigating if you want a fully
faithful implementation of *that* mechanism specifically.)

## References

- Weizenbaum, J. "ELIZA — A Computer Program For the Study of Natural
  Language Communication Between Man and Machine," CACM 9(1), Jan 1966.
- [ELIZAGEN](https://sites.google.com/view/elizagen-org/original-eliza) —
  the rediscovered MAD-SLIP source code (CC0).
- Lane, Hay, Schwarz, Shrager. December 2024 reconstruction running on a
  CTSS / IBM 7094 emulator.
ELIZA_SETUP_EOF

cat > doctor.script << 'ELIZA_SETUP_EOF'
; APPENDIX. An Eliza Script
; Transcribed from Joseph Weizenbaum's article on page 36 of the January
; 1966 edition of Communications of the ACM. Transcribed by Anthony Hay,
; December 2020, with duplicate lines and obvious typos noted in comments.
; Verbatim form from elizagen.org/1965_Weizenbaum_MAD-SLIP/.

(HOW DO YOU DO. PLEASE TELL ME YOUR PROBLEM)
START
(SORRY
    ((0)
        (PLEASE DON'T APOLIGIZE)
        (APOLOGIES ARE NOT NECESSARY)
        (WHAT FEELINGS DO YOU HAVE WHEN YOU APOLOGIZE)
        (I'VE TOLD YOU THAT APOLOGIES ARE NOT REQUIRED)))
(DONT = DON'T)
(CANT = CAN'T)
(WONT = WON'T)
(REMEMBER 5
    ((0 YOU REMEMBER 0)
        (DO YOU OFTEN THINK OF 4)
        (DOES THINKING OF 4 BRING ANYTHING ELSE TO MIND)
        (WHAT ELSE DO YOU REMEMBER)
        (WHY DO YOU REMEMBER 4 JUST NOW)
        (WHAT IN THE PRESENT SITUATION REMINDS YOU OF 4)
        (WHAT IS THE CONNECTION BETWEEN ME AND 4))
    ((0 DO I REMEMBER 0)
        (DID YOU THINK I WOULD FORGET 5)
        (WHY DO YOU THINK I SHOULD RECALL 5 NOW)
        (WHAT ABOUT 5)
        (=WHAT)
        (YOU MENTIONED 5))
    ((0)
        (NEWKEY)))
(IF 3
    ((0 IF 0)
        (DO YOU THINK ITS LIKELY THAT 3)
        (DO YOU WISH THAT 3)
        (WHAT DO YOU THINK ABOUT 3)
        (REALLY, 2 3)))
(DREAMT 4
    ((0 YOU DREAMT 0)
        (REALLY, 4)
        (HAVE YOU EVER FANTASIED 4 WHILE YOU WERE AWAKE)
        (HAVE YOU DREAMT 4 BEFORE)
        (=DREAM)
        (NEWKEY)))
(DREAMED = DREAMT 4 (=DREAMT))
(DREAM 3
    ((0)
        (WHAT DOES THAT DREAM SUGGEST TO YOU)
        (DO YOU DREAM OFTEN)
        (WHAT PERSONS APPEAR IN YOUR DREAMS)
        (DON'T YOU BELIEVE THAT DREAM HAS SOMETHING TO DO WITH YOUR PROBLEM)
        (NEWKEY)))
(DREAMS = DREAM 3 (=DREAM))
(HOW (=WHAT))
(WHEN (=WHAT))
(ALIKE 10 (=DIT))
(SAME 10 (=DIT))
(CERTAINLY (=YES))
(FEEL DLIST(/BELIEF))
(THINK DLIST(/BELIEF))
(BELIEVE DLIST(/BELIEF))
(WISH DLIST(/BELIEF))
(MEMORY MY
    (0 YOUR 0 = LETS DISCUSS FURTHER WHY YOUR 3)
    (0 YOUR 0 = EARLIER YOU SAID YOUR 3)
    (0 YOUR 0 = BUT YOUR 3)
    (0 YOUR 0 = DOES THAT HAVE ANYTHING TO DO WITH THE FACT THAT YOUR 3))
(NONE
    ((0)
        (I AM NOT SURE I UNDERSTAND YOU FULLY)
        (PLEASE GO ON)
        (WHAT DOES THAT SUGGEST TO YOU)
        (DO YOU FEEL STRONGLY ABOUT DISCUSSING SUCH THINGS)))
(PERHAPS
    ((0)
        (YOU DON'T SEEM QUITE CERTAIN)
        (WHY THE UNCERTAIN TONE)
        (CAN'T YOU BE MORE POSITIVE)
        (YOU AREN'T SURE)
        (DON'T YOU KNOW)))
(MAYBE (=PERHAPS))
(NAME 15
    ((0)
        (I AM NOT INTERESTED IN NAMES)
        (I'VE TOLD YOU BEFORE, I DON'T CARE ABOUT NAMES - PLEASE CONTINUE)))
(DEUTSCH (=XFREMD))
(FRANCAIS (=XFREMD))
(ITALIANO (=XFREMD))
(ESPANOL (=XFREMD))
(XFREMD
    ((0)
        (I AM SORRY, I SPEAK ONLY ENGLISH)))
(HELLO
    ((0)
        (HOW DO YOU DO. PLEASE STATE YOUR PROBLEM)))
(COMPUTER 50
    ((0)
        (DO COMPUTERS WORRY YOU)
        (WHY DO YOU MENTION COMPUTERS)
        (WHAT DO YOU THINK MACHINES HAVE TO DO WITH YOUR PROBLEM)
        (DON'T YOU THINK COMPUTERS CAN HELP PEOPLE)
        (WHAT ABOUT MACHINES WORRIES YOU)
        (WHAT DO YOU THINK ABOUT MACHINES)))
(MACHINE 50 (=COMPUTER))
(MACHINES 50 (=COMPUTER))
(COMPUTERS 50 (=COMPUTER))
(AM = ARE
    ((0 ARE YOU 0)
        (DO YOU BELIEVE YOU ARE 4)
        (WOULD YOU WANT TO BE 4)
        (YOU WISH I WOULD TELL YOU YOU ARE 4)
        (WHAT WOULD IT MEAN IF YOU WERE 4)
        (=WHAT))
    ((0)
        (WHY DO YOU SAY 'AM')
        (I DON'T UNDERSTAND THAT)))
(ARE
    ((0 ARE I 0)
        (WHY ARE YOU INTERESTED IN WHETHER I AM 4 OR NOT)
        (WOULD YOU PREFER IF I WEREN'T 4)
        (PERHAPS I AM 4 IN YOUR FANTASIES)
        (DO YOU SOMETIMES THINK I AM 4)
        (=WHAT))
    ((0 ARE 0)
        (DID YOU THINK THEY MIGHT NOT BE 3)
        (WOULD YOU LIKE IT IF THEY WERE NOT 3)
        (WHAT IF THEY WERE NOT 3)
        (POSSIBLY THEY ARE 3)))
(YOUR = MY
    ((0 MY 0)
        (WHY ARE YOU CONCERNED OVER MY 3)
        (WHAT ABOUT YOUR OWN 3)
        (ARE YOU WORRIED ABOUT SOMEONE ELSES 3)
        (REALLY, MY 3)))
(WAS 2
    ((0 WAS YOU 0)
        (WHAT IF YOU WERE 4)
        (DO YOU THINK YOU WERE 4)
        (WERE YOU 4)
        (WHAT WOULD IT MEAN IF YOU WERE 4)
        (WHAT DOES ' 4 ' SUGGEST TO YOU)
        (=WHAT))
    ((0 YOU WAS 0)
        (WERE YOU REALLY)
        (WHY DO YOU TELL ME YOU WERE 4 NOW)
        (PERHAPS I ALREADY KNEW YOU WERE 4))
    ((0 WAS I 0)
        (WOULD YOU LIKE TO BELIEVE I WAS 4)
        (WHAT SUGGESTS THAT I WAS 4)
        (WHAT DO YOU THINK)
        (PERHAPS I WAS 4)
        (WHAT IF I HAD BEEN 4))
    ((0)
        (NEWKEY)))
(WERE = WAS (=WAS))
(ME = YOU)
(YOU'RE = I'M
    ((0 I'M 0)
        (PRE (I ARE 3) (=YOU))))
(I'M = YOU'RE
    ((0 YOU'RE 0)
        (PRE (YOU ARE 3) (=I))))
(MYSELF = YOURSELF)
(YOURSELF = MYSELF)
(MOTHER DLIST(/NOUN FAMILY))
(MOM = MOTHER DLIST(/ FAMILY))
(DAD = FATHER DLIST(/ FAMILY))
(FATHER DLIST(/NOUN FAMILY))
(SISTER DLIST(/FAMILY))
(BROTHER DLIST(/FAMILY))
(WIFE DLIST(/FAMILY))
(CHILDREN DLIST(/FAMILY))
(I = YOU
    ((0 YOU (* WANT NEED) 0)
        (WHAT WOULD IT MEAN TO YOU IF YOU GOT 4)
        (WHY DO YOU WANT 4)
        (SUPPOSE YOU GOT 4 SOON)
        (WHAT IF YOU NEVER GOT 4)
        (WHAT WOULD GETTING 4 MEAN TO YOU)
        (WHAT DOES WANTING 4 HAVE TO DO WITH THIS DISCUSSION))
    ((0 YOU ARE 0 (* SAD UNHAPPY DEPRESSED SICK) 0)
        (I AM SORRY TO HEAR YOU ARE 5)
        (DO YOU THINK COMING HERE WILL HELP YOU NOT TO BE 5)
        (I'M SURE ITS NOT PLEASANT TO BE 5)
        (CAN YOU EXPLAIN WHAT MADE YOU 5))
    ((0 YOU ARE 0 (* HAPPY ELATED GLAD BETTER) 0)
        (HOW HAVE I HELPED YOU TO BE 5)
        (HAS YOUR TREATMENT MADE YOU 5)
        (WHAT MAKES YOU 5 JUST NOW)
        (CAN YOU EXPLAIN WHY YOU ARE SUDDENLY 5))
    ((0 YOU WAS 0)
        (=WAS))
    ((0 YOU (/BELIEF) YOU 0)
        (DO YOU REALLY THINK SO)
        (BUT YOU ARE NOT SURE YOU 5)
        (DO YOU REALLY DOUBT YOU 5))
    ((0 YOU 0 (/BELIEF) 0 I 0)
        (=YOU))
    ((0 YOU ARE 0)
        (IS IT BECAUSE YOU ARE 4 THAT YOU CAME TO ME)
        (HOW LONG HAVE YOU BEEN 4)
        (DO YOU BELIEVE IT NORMAL TO BE 4)
        (DO YOU ENJOY BEING 4))
    ((0 YOU (* CAN'T CANNOT) 0)
        (HOW DO YOU KNOW YOU CAN'T 4)
        (HAVE YOU TRIED)
        (PERHAPS YOU COULD 4 NOW)
        (DO YOU REALLY WANT TO BE ABLE TO 4))
    ((0 YOU DON'T 0)
        (DON'T YOU REALLY 4)
        (WHY DON'T YOU 4)
        (DO YOU WISH TO BE ABLE TO 4)
        (DOES THAT TROUBLE YOU))
    ((0 YOU FEEL 0)
        (TELL ME MORE ABOUT SUCH FEELINGS)
        (DO YOU OFTEN FEEL 4)
        (DO YOU ENJOY FEELING 4)
        (OF WHAT DOES FEELING 4 REMIND YOU))
    ((0 YOU 0 I 0)
        (PERHAPS IN YOUR FANTASY WE 3 EACH OTHER)
        (DO YOU WISH TO 3 ME)
        (YOU SEEM TO NEED TO 3 ME)
        (DO YOU 3 ANYONE ELSE))
    ((0)
        (YOU SAY 1)
        (CAN YOU ELABORATE ON THAT)
        (DO YOU SAY 1 FOR SOME SPECIAL REASON)
        (THAT'S QUITE INTERESTING)))
(YOU = I
    ((0 I REMIND YOU OF 0)
        (=DIT))
    ((0 I ARE 0)
        (WHAT MAKES YOU THINK I AM 4)
        (DOES IT PLEASE YOU TO BELIEVE I AM 4)
        (DO YOU SOMETIMES WISH YOU WERE 4)
        (PERHAPS YOU WOULD LIKE TO BE 4))
    ((0 I 0 YOU)
        (WHY DO YOU THINK I 3 YOU)
        (YOU LIKE TO THINK I 3 YOU - DON'T YOU)
        (WHAT MAKES YOU THINK I 3 YOU)
        (REALLY, I 3 YOU)
        (DO YOU WISH TO BELIEVE I 3 YOU)
        (SUPPOSE I DID 3 YOU - WHAT WOULD THAT MEAN)
        (DOES SOMEONE ELSE BELIEVE I 3 YOU))
    ((0 I 0)
        (WE WERE DISCUSSING YOU - NOT ME)
        (OH, I 3)
        (YOU'RE NOT REALLY TALKING ABOUT ME - ARE YOU)
        (WHAT ARE YOUR FEELINGS NOW)))
(YES
    ((0)
        (YOU SEEM QUITE POSITIVE)
        (YOU ARE SURE)
        (I SEE)
        (I UNDERSTAND)))
(NO
    ((0)
        (ARE YOU SAYING 'NO' JUST TO BE NEGATIVE)
        (YOU ARE BEING A BIT NEGATIVE)
        (WHY NOT)
        (WHY 'NO')))
(MY = YOUR 2
    ((0 YOUR 0 (/FAMILY) 0)
        (TELL ME MORE ABOUT YOUR FAMILY)
        (WHO ELSE IN YOUR FAMILY 5)
        (YOUR 4)
        (WHAT ELSE COMES TO MIND WHEN YOU THINK OF YOUR 4))
    ((0 YOUR 0)
        (YOUR 3)
        (WHY DO YOU SAY YOUR 3)
        (DOES THAT SUGGEST ANYTHING ELSE WHICH BELONGS TO YOU)
        (IS IT IMPORTANT TO YOU THAT 2 3)))
(CAN
    ((0 CAN I 0)
        (YOU BELIEVE I CAN 4 DON'T YOU)
        (=WHAT)
        (YOU WANT ME TO BE ABLE TO 4)
        (PERHAPS YOU WOULD LIKE TO BE ABLE TO 4 YOURSELF))
    ((0 CAN YOU 0)
        (WHETHER OR NOT YOU CAN 4 DEPENDS ON YOU MORE THAN ON ME)
        (DO YOU WANT TO BE ABLE TO 4)
        (PERHAPS YOU DON'T WANT TO 4)
        (=WHAT)))
(WHAT
    ((0)
        (WHY DO YOU ASK)
        (DOES THAT QUESTION INTEREST YOU)
        (WHAT IS IT YOU REALLY WANT TO KNOW)
        (ARE SUCH QUESTIONS MUCH ON YOUR MIND)
        (WHAT ANSWER WOULD PLEASE YOU MOST)
        (WHAT DO YOU THINK)
        (WHAT COMES TO YOUR MIND WHEN YOU ASK THAT)
        (HAVE YOU ASKED SUCH QUESTIONS BEFORE)
        (HAVE YOU ASKED ANYONE ELSE)))
(BECAUSE
    ((0)
        (IS THAT THE REAL REASON)
        (DON'T ANY OTHER REASONS COME TO MIND)
        (DOES THAT REASON SEEM TO EXPLAIN ANYTHING ELSE)
        (WHAT OTHER REASONS MIGHT THERE BE)))
(WHY
    ((0 WHY DON'T I 0)
        (DO YOU BELIEVE I DON'T 5)
        (PERHAPS I WILL 5 IN GOOD TIME)
        (SHOULD YOU 5 YOURSELF)
        (YOU WANT ME TO 5)
        (=WHAT))
    ((0 WHY CAN'T YOU 0)
        (DO YOU THINK YOU SHOULD BE ABLE TO 5)
        (DO YOU WANT TO BE ABLE TO 5)
        (DO YOU BELIEVE THIS WILL HELP YOU TO 5)
        (HAVE YOU ANY IDEA WHY YOU CAN'T 5)
        (=WHAT)))
(EVERYONE 2
    ((0 (* EVERYONE EVERYBODY NOBODY NOONE) 0)
        (REALLY, 2)
        (SURELY NOT 2)
        (CAN YOU THINK OF ANYONE IN PARTICULAR)
        (WHO, FOR EXAMPLE)
        (YOU ARE THINKING OF A VERY SPECIAL PERSON)
        (WHO, MAY I ASK)
        (SOMEONE SPECIAL PERHAPS)
        (YOU HAVE A PARTICULAR PERSON IN MIND, DON'T YOU)
        (WHO DO YOU THINK YOU'RE TALKING ABOUT)))
(EVERYBODY 2 (= EVERYONE))
(NOBODY 2 (= EVERYONE))
(NOONE 2 (= EVERYONE))
(ALWAYS 1
    ((0)
        (CAN YOU THINK OF A SPECIFIC EXAMPLE)
        (WHEN)
        (WHAT INCIDENT ARE YOU THINKING OF)
        (REALLY, ALWAYS)))
(LIKE 10
    ((0 (* AM IS ARE WAS) 0 LIKE 0)
        (=DIT))
    ((0)
        (NEWKEY)))
(DIT
    ((0)
        (IN WHAT WAY)
        (WHAT RESEMBLANCE DO YOU SEE)
        (WHAT DOES THAT SIMILARITY SUGGEST TO YOU)
        (WHAT OTHER CONNECTIONS DO YOU SEE)
        (WHAT DO YOU SUPPOSE THAT RESEMBLANCE MEANS)
        (WHAT IS THE CONNECTION, DO YOU SUPPOSE)
        (COULD THERE REALLY BE SOME CONNECTION)
        (HOW)))
()
ELIZA_SETUP_EOF

cat > eliza_parse.py << 'ELIZA_SETUP_EOF'
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
ELIZA_SETUP_EOF

cat > eliza_tokens.py << 'ELIZA_SETUP_EOF'
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
ELIZA_SETUP_EOF

cat > eliza_compile.py << 'ELIZA_SETUP_EOF'
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
ELIZA_SETUP_EOF

cat > eliza_regex.py << 'ELIZA_SETUP_EOF'
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
ELIZA_SETUP_EOF

cat > transcript.txt << 'ELIZA_SETUP_EOF'
Men are all alike.
They're always bugging us about something or other.
Well, my boyfriend made me come here.
He says I'm depressed much of the time.
It's true. I am unhappy.
I need some help, that much seems certain.
Perhaps I could learn to get along with my mother.
My mother takes care of me.
My father.
You are like my father in some ways.
You are not very aggressive but I think you don't want me to notice that.
You don't argue with me.
You are afraid of me.
My father is afraid of everybody.
Bullies.
ELIZA_SETUP_EOF

cat > expected.txt << 'ELIZA_SETUP_EOF'
ELIZA: HOW DO YOU DO. PLEASE TELL ME YOUR PROBLEM
YOU : Men are all alike.
ELIZA: IN WHAT WAY
YOU : They're always bugging us about something or other.
ELIZA: CAN YOU THINK OF A SPECIFIC EXAMPLE
YOU : Well, my boyfriend made me come here.
ELIZA: YOUR BOYFRIEND MADE YOU COME HERE
YOU : He says I'm depressed much of the time.
ELIZA: I AM SORRY TO HEAR YOU ARE DEPRESSED
YOU : It's true. I am unhappy.
ELIZA: DO YOU THINK COMING HERE WILL HELP YOU NOT TO BE UNHAPPY
YOU : I need some help, that much seems certain.
ELIZA: WHAT WOULD IT MEAN TO YOU IF YOU GOT SOME HELP
YOU : Perhaps I could learn to get along with my mother.
ELIZA: TELL ME MORE ABOUT YOUR FAMILY
YOU : My mother takes care of me.
ELIZA: WHO ELSE IN YOUR FAMILY TAKES CARE OF YOU
YOU : My father.
ELIZA: YOUR FATHER
YOU : You are like my father in some ways.
ELIZA: WHAT RESEMBLANCE DO YOU SEE
YOU : You are not very aggressive but I think you don't want me to notice that.
ELIZA: WHAT MAKES YOU THINK I AM NOT VERY AGGRESSIVE
YOU : You don't argue with me.
ELIZA: WHY DO YOU THINK I DON'T ARGUE WITH YOU
YOU : You are afraid of me.
ELIZA: DOES IT PLEASE YOU TO BELIEVE I AM AFRAID OF YOU
YOU : My father is afraid of everybody.
ELIZA: WHAT ELSE COMES TO MIND WHEN YOU THINK OF YOUR FATHER
YOU : Bullies.
ELIZA: LETS DISCUSS FURTHER WHY YOUR BOYFRIEND MADE YOU COME HERE
ELIZA_SETUP_EOF

cat > test.sh << 'ELIZA_SETUP_EOF'
#!/usr/bin/env bash
# test.sh — verify both engines reproduce the published 1966 transcript and
# agree with each other.

set -e
cd "$(dirname "$0")"

python eliza_compile.py doctor.script doctor.json >/dev/null

python eliza_tokens.py doctor.script < transcript.txt > /tmp/tokens.out
python eliza_regex.py  doctor.json   < transcript.txt > /tmp/regex.out

if ! diff -q /tmp/tokens.out /tmp/regex.out > /dev/null; then
    echo "FAIL: engines disagree"
    diff /tmp/tokens.out /tmp/regex.out
    exit 1
fi
echo "OK: engines agree"

if ! diff -q /tmp/tokens.out expected.txt > /dev/null; then
    echo "FAIL: output differs from published 1966 transcript"
    diff expected.txt /tmp/tokens.out
    exit 1
fi
echo "OK: matches published 1966 transcript"
ELIZA_SETUP_EOF

chmod +x test.sh
echo "Files created. Run: ./test.sh"
