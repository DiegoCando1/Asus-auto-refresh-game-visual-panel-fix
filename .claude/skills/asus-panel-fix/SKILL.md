---
name: asus-panel-fix
description: Fixes Armoury Crate on ASUS laptops whose screen was replaced - "GameVisual may not be supported", missing "Panel Power Saver" (auto 60 Hz on battery). Use when the user mentions a replaced/new ASUS laptop panel with those symptoms.
---

# asus-panel-fix

Applies `Fix-AsusPanel.ps1` (repo root) to an ASUS laptop whose internal panel is not in ASUS's lists.
Windows only. Read the README first for the cause and warnings.

## Steps

1. **Confirm the symptom.** Ask which applies: GameVisual says "may not be supported", or "Panel Power Saver"
   is missing in Armoury Crate. If neither, this skill does not apply.
2. **Dry run (no admin, changes nothing):**
   `powershell -ExecutionPolicy Bypass -File <repo>\Fix-AsusPanel.ps1 -DryRun`
   Show the user the detected manufacturer, product, max Hz and model. If Hz max or model look wrong,
   stop and ask; use `-MaxHz` if needed.
3. **Tell the user before applying:**
   - The colour profile is copied from another panel, so GameVisual colours will not be exact.
   - Tested on one laptop only (TUF Dash F15 FX517ZM).
   - A backup of `FRQ_Config.txt` is saved in `respaldo\`; `-Undo` reverses everything.
   Get a clear yes.
4. **Apply with admin rights.** The user must approve the Windows UAC prompt; do not try to bypass it:
   `Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','"<repo>\Fix-AsusPanel.ps1"'`
5. **Verify the files exist** (`FRQ_Config.txt` last line, `*_<mfr><prod>.icm` in
   `C:\ProgramData\ASUS\GameVisual`). Then ask the user to restart.
6. **After restart, check, don't assume.** Ask the user whether GameVisual opens and whether
   "Panel Power Saver" appears. Optionally confirm in the Armoury Crate log
   (`%LOCALAPPDATA%\ASUS\ARMOURY CRATE Diagnosis\AppLog\ArmouryCrate.UserSessionHelper_*.log`):
   the line `ICM Exist: 1` means the profile is found.

## Do not

- Do not edit BIOS or drivers as part of this.
- Do not claim it works until the user confirms after the restart.
- Do not promise a fix for Windows Night Light; it is unrelated.
