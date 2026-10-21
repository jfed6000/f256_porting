# starter: instructions for Claude

The smallest complete F256 game skeleton (NitrOS-9 Level 2, 6809), kept as a template: grow a game from a copy of it.

- **The platform:** the F256 porting guide, `../README.md` (https://github.com/jfed6000/f256_porting). Check every
  hardware assumption against it; section 13 is the working method, section 15 how we work together.
- **Build and test:** `. ../env.sh` first (the machine's paths), then `make`, `make install DSK=<absolute path>`,
  `make mame`. MAME proves it starts, draws and exits; held keys and the SAM2695 are for the
  hardware, which the user runs.
- **Keep it small and correct.** It's a teaching skeleton: every addition must be something every game needs, cite
  the guide's section, and leave `make mame` passing. Game-specific code belongs in a copy, not here.
- **Prove before saying fixed**, and say which machine a claim was checked on. **Ask before** pushing or anything
  outward-facing.
