# app_jfsw

[JFSW](https://github.com/jonof/jfsw) - Jonathon Fowler's port of Shadow Warrior - packaged as an
[AutoBleem](https://github.com/autobleem2/autobleem) App for the PlayStation Classic, the Raspberry Pi, the
AutoBleem PC stick and Windows, with the v1.2 shareware episode. Install it from the AutoBleem Store.

The upstream source is a pinned submodule; this repository holds only the build (`ci/build.sh`, run in the
[autobleem-build](https://github.com/autobleem2/autobleem-build) image), three small patches (the PlayStation
Classic pad layout, and no setup window when started with `-nosetup`) and the App's files.

```
git clone --recurse-submodules https://github.com/autobleem2/app_jfsw
ci/build.sh all    # inside ghcr.io/autobleem2/autobleem-build
```

Controls (PlayStation Classic pad): D-pad move and turn, Square fire, Cross crouch, Circle open, Triangle jump,
L1 next item, R1 next weapon, L2/R2 strafe, Select use item, Start menu. Press Reset on the console or hold
Start + Select to leave.

Licence: the build, patches and tools GPL-3.0-or-later, JFSW GPL-2.0 with the Build engine under Ken
Silverman's licence; the shareware episode is freely distributable (see `LICENSE`).
