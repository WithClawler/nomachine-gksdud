# Third-party components

The project source is MIT licensed. The source-only handoff archive does not
contain the AutoHotkey runtime.

The installer and portable builds include an unmodified AutoHotkey 2.0.28
runtime from the official AutoHotkey release. AutoHotkey is separately licensed
under GPL v2 and includes additional notices in its `license.txt`.

Build.ps1 copies the runtime's complete license text and the matching, verified
upstream source archive into `third-party/AutoHotkey/` in both distributions.
Keep these files when redistributing the binaries. The exact upstream URLs and
SHA-256 values are recorded in `build-dependencies.json`.

https://github.com/AutoHotkey/AutoHotkey/tree/v2.0.28

Inno Setup is used as a build tool and is not installed by this application.
https://jrsoftware.org/isinfo.php
