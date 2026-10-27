# asus-panel-fix

Arregla Armoury Crate cuando **cambiaste la pantalla de tu portátil ASUS** por una que no es la original.

## Síntomas

- GameVisual dice **"GameVisual puede que no se admita"**.
- No aparece **"Ahorro de energía del panel"** (el cambio automático a 60 Hz con batería).
- Las opciones de pantalla de Armoury Crate no se pueden activar.

## Causa

ASUS identifica el panel por los datos de fábrica que trae (EDID: fabricante + modelo). Si tu panel no está en sus listas, el software lo ignora:

1. **ASUS Smart Display Control** solo cambia los Hz con paneles que estén en
   `C:\ProgramData\ASUS\ASUS Smart Display Control\FRQ_Config.txt`
   (formato `fabricante,modelo,HzMax,HzMin`).
2. **GameVisual** busca un perfil de color llamado `<MODELO>_<GPU>_<fabricante><producto>.icm`
   (por ejemplo `FX517ZM_8086_CF260621.icm`). Si no existe, muestra el aviso y no abre.
   Los registros de Armoury Crate lo dejan escrito: `ICM Exist: 0 ... ICM File need re-download`.

## Qué hace el script

`Fix-AsusPanel.ps1` lee el EDID de tu pantalla interna y:

- agrega tu panel a `FRQ_Config.txt` (guarda antes una copia en la carpeta `respaldo\`),
- crea el perfil `.icm` que GameVisual espera, **copiando uno que ya existe en tu equipo**.

No incluye ni descarga archivos de ASUS.

## Uso

1. Abre PowerShell **como administrador**.
2. Primero mira qué haría, sin cambiar nada:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\Fix-AsusPanel.ps1 -DryRun
   ```

3. Si los datos del panel (fabricante, producto, Hz) son correctos, aplícalo:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\Fix-AsusPanel.ps1
   ```

4. Reinicia el equipo.

Para deshacerlo:

```powershell
powershell -ExecutionPolicy Bypass -File .\Fix-AsusPanel.ps1 -Undo
```

Opciones: `-MaxHz 144` (si no se detecta bien) y `-SourceIcm "ruta\perfil.icm"` (perfil a copiar).

## Avisos

- **El perfil de color no está calibrado para tu panel.** Es de otro panel, así que GameVisual funciona pero los colores de sus modos no serán exactos.
- Probado en **un solo equipo**: ASUS TUF Dash F15 (FX517ZM) con panel InfoVision `IVO0621`. Otros modelos pueden comportarse distinto.
- Una actualización de Armoury Crate puede reescribir `FRQ_Config.txt`; si pasa, vuelve a ejecutar el script.
- No es un proyecto oficial de ASUS. Úsalo bajo tu propio riesgo.
- El script **no** arregla Night Light de Windows.

## Licencia

MIT. Ver [LICENSE](LICENSE).
