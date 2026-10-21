# <Game>: instructions for Claude

<!-- A template for CLAUDE.md in a new F256 game project (the porting guide's section 15). Copy it to the project's
     root as CLAUDE.md, fill in the <...>, and delete what doesn't apply. Keep it short: it's read every session. -->

<One line: what the game is, and the target - e.g. "A port of <arcade game> to the Wildbits F256 (NitrOS-9 Level 2,
6809)", or "An original game for the F256, designed first as a browser prototype in game/".>

- **Start here:** `docs/status.md` (the handoff: where things stand, what's open, what was last run on which
  machine). Then `docs/port-plan.md` (the design) and `docs/port-<game>.md` (the survey).
- **The platform:** the F256 porting guide, https://github.com/jfed6000/f256_porting (`README.md`; a local clone at
  `<path>`). Check every hardware assumption against it; its section 13 is the working method.
- **This machine's paths:** `<path>/env.sh` (from the guide's `env.sh.example`): source it before building or
  running MAME.
- **The machines:** <K2 / Jr2>, core <Longview_rcNN>. I run the builds on the hardware; Claude can't. MAME
  (`<path to mame>`, machine `wbjr2`) is for "does it start, draw and exit"; its timing is no evidence, it starts RAM
  at zero, and it doesn't voice the SAM2695.
- **Build and test:** `make` (the module, with the budget and data-area checks), `make install DSK=<absolute path>`,
  `make mame`. <The host model: `python3 tools/hostrun.py --args <...>`.> <Test levers: `<game> b` autopilot, `g`
  invulnerable, `k` boss, ...>
- **Prove before saying fixed.** A fix is "fixed" only after the host model or MAME shows it, and "works on the
  hardware" only after I've run it. Say which machine every claim was checked on. One change per hardware run.
- **Ask before** anything outward-facing or hard to undo: pushing, opening a PR, publishing, deleting, rewriting
  history. When a request is ambiguous ("I like that"), ask rather than act.
- **Commits:** when a piece of work is done, commit on <branch> and push to `<remote>` (<or: don't push; I will>).
- **Tracking:** <the project tracker, if any: where tasks for me go (things only I can do, like a hardware run), and
  the end-of-session note>.
- **Decisions I've made** are recorded in `<docs/design.md or story.md>`; don't relitigate them, and add new ones
  there with the date.
