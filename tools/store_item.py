#!/usr/bin/env python3
"""Write the AutoBleem Store's descriptor for one platform's package (autobleem-repo CLAUDE.md, "The AutoBleem
Store's catalog"), next to the package and the picture, ready for `repo_publish.sh store <platform> ...`:

    tools/store_item.py dist/shadowwarrior-psc-20260105-1.zip  -> dist/store/psc/shadowwarrior.item.json
                                                                        + shadowwarrior.png + the zip

The id is the same on every platform (app/shadowwarrior - the RetroBoot App's id, updated in place), so an installed App is updated in place.
Only the standard library is needed.
"""
import json
import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

DESCRIPTION = ("The shareware episode of Shadow Warrior (1997) - Lo Wang against Zilla's demons - through JFSW, "
               "Jonathon Fowler's port of the original source. Built for this machine; the pad out of the box.")


def main(argv):
    if len(argv) != 2:
        print(__doc__)
        return 2
    package = argv[1]
    m = re.match(r"^shadowwarrior-(?P<key>[a-z0-9]+)-(?P<version>.+)\.zip$", os.path.basename(package))
    if not m:
        print("not a shadowwarrior-<key>-<version>.zip: %s" % package)
        return 1
    key, version = m.group("key"), m.group("version")
    out = os.path.join(os.path.dirname(package), "store", key)
    os.makedirs(out, exist_ok=True)
    shutil.copy(package, out)
    shutil.copy(os.path.join(ROOT, "resources", "icon.png"), os.path.join(out, "shadowwarrior.png"))
    item = {
        "id": "app/shadowwarrior",
        "kind": "app",
        "title": "Shadow Warrior (Shareware)",
        "version": version,
        "author": "JFSW by Jonathon Fowler; Shadow Warrior by 3D Realms",
        "licence": "GPL-2.0 (the Build engine: Ken Silverman's licence; the shareware data: freely distributable)",
        "description": DESCRIPTION,
        "image": "shadowwarrior.png",
        "files": [{"name": os.path.basename(package)}],
    }
    with open(os.path.join(out, "shadowwarrior.item.json"), "w", encoding="utf-8") as f:
        json.dump(item, f, indent=2)
        f.write("\n")
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
