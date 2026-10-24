# Task: gh shim reentry

* Task ID: gh-shim-reentry
* Complexity: Level 1
* Type: bugfix

`exec_real` leaves `GIT_ALIASES_GH_SHIM` set, so a later `gh` on `PATH` exits with `Error: gh shim invoked itself`.
