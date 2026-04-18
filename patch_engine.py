with open('cmd_headless/lib/engine.bat', 'r') as f:
    content = f.read()

new_code = "    :: --- Build flags ---\n    call :fn_build_flags \"!_rc_type!\"\n\n    :: --- Doc exclusions tu config.ini ---\n    if exist \"config.ini\" (\n        for /f \"usebackq tokens=*\" %%A in (\"config.ini\") do (\n            set \"_line=%%A\"\n            if not \"!_line:~0,1!\"==\";\" (\n                if not \"!_line:~0,1!\"==\"#\" (\n                    set \"_BUILD_FLAGS=!_BUILD_FLAGS! /XD \"\"!_line!\"\"\"\n                )\n            )\n        )\n    )\n\n    :: --- Hien thi ---"

content = content.replace('    :: --- Build flags ---\n    call :fn_build_flags "!_rc_type!"\n\n    :: --- Hien thi ---', new_code)

with open('cmd_headless/lib/engine.bat', 'w') as f:
    f.write(content)
