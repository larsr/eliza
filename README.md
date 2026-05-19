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
