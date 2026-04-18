with open('cmd_headless/dist/RoboSync_Portable.bat', 'r') as f:
    content = f.read()

new_code = "    call :fn_build_flags \"!_rc_type!\"\n\n    if exist \"config.ini\" (\n        for /f \"usebackq tokens=*\" %%A in (\"config.ini\") do (\n            set \"_line=%%A\"\n            if not \"!_line:~0,1!\"==\";\" (\n                if not \"!_line:~0,1!\"==\"#\" (\n                    set \"_BUILD_FLAGS=!_BUILD_FLAGS! /XD \"\"!_line!\"\"\"\n                )\n            )\n        )\n    )\n\n    echo."

content = content.replace('    call :fn_build_flags "!_rc_type!"\n\n    echo.', new_code)

with open('cmd_headless/dist/RoboSync_Portable.bat', 'w') as f:
    f.write(content)
