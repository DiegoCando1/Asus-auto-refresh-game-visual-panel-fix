# asus-panel-fix

Fixes Armoury Crate when you **replaced the screen of your ASUS laptop** with one that is not the original: GameVisual "may not be supported" and Panel Power Saver (auto 60 Hz on battery) doing nothing. Tested on a TUF Dash F15 (FX517ZM).

## Symptoms

- GameVisual says **"GameVisual may not be supported"**.
- **Armoury Crate > Devices > System Settings > Panel Power Saver** (the "AUTO HZ" tile, which switches to 60 Hz on battery) can be selected but does nothing: the refresh rate never changes.
- Display options in Armoury Crate cannot be turned on.

## Cause

ASUS identifies the panel by the factory data it reports (EDID: manufacturer + product code). If your panel is not in ASUS's lists, their software ignores it:

1. **ASUS Smart Display Control** only switches refresh rates for panels listed in
   `C:\ProgramData\ASUS\ASUS Smart Display Control\FRQ_Config.txt`
   (format `manufacturer,product,maxHz,minHz`).
2. **GameVisual** looks for a colour profile named `<MODEL>_<GPU>_<manufacturer><product>.icm`
   (for example `FX517ZM_8086_CF260621.icm`). If it does not exist, it shows the warning and does not open.
   The Armoury Crate log records it: `ICM Exist: 0 ... ICM File need re-download`.

## What the script does

`Fix-AsusPanel.ps1` reads the EDID of your internal display and:

- adds your panel to `FRQ_Config.txt` (a backup copy is saved first in the `backup\` folder),
- creates the `.icm` profile GameVisual expects, **copying one that already exists on your laptop**.

It does not include or download any ASUS files.

## Usage

1. Open PowerShell **as administrator**.
2. First, preview what it would do without changing anything:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\Fix-AsusPanel.ps1 -DryRun
   ```

3. If the panel data (manufacturer, product, Hz) looks right, apply it:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\Fix-AsusPanel.ps1
   ```

4. Restart the laptop.

To undo:

```powershell
powershell -ExecutionPolicy Bypass -File .\Fix-AsusPanel.ps1 -Undo
```

Options: `-MaxHz 144` (if detection fails) and `-SourceIcm "path\profile.icm"` (profile to copy).

## Use it with Claude Code

This repo includes a Claude Code skill (`.claude/skills/asus-panel-fix`). Open the cloned repo with Claude Code
and ask, for example, "fix my ASUS replaced screen, GameVisual says it is not supported". Claude previews the
change, asks for your confirmation, and applies it (you still approve the Windows administrator prompt).

## Warnings

- **The colour profile is not calibrated for your panel.** It comes from another panel, so GameVisual works but the colours of its modes will not be exact.
- Tested on **one laptop only**: ASUS TUF Dash F15 (FX517ZM) with an InfoVision `IVO0621` panel. Other models may behave differently.
- An Armoury Crate update may rewrite `FRQ_Config.txt`; if that happens, run the script again.
- Not an official ASUS project. Use at your own risk.
- The script does **not** fix Windows Night Light.

## License

MIT. See [LICENSE](LICENSE).
