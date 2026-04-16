@echo off
:: ================================================================
:: BUILD.BAT — Development Guide (NOT an automated bundler)
:: ================================================================
::
:: This project has TWO distribution modes:
::
:: 1. DEV MODE (modular):
::    Entry: RoboSync.bat + lib\*.bat (4 modules)
::    Use:   Debugging, testing, development
::    Run:   Double-click RoboSync.bat
::
:: 2. RUN MODE (single-file):
::    Entry: dist\RoboSync_Portable.bat
::    Use:   Production deployment, USB portability
::    Run:   Copy this ONE file anywhere, double-click
::
:: ================================================================
:: WHY NOT AUTO-BUNDLE?
:: ================================================================
::
:: Concatenating .bat files is NOT like bundling JS/CSS.
:: CMD batch modules use dispatchers (call :%%*, exit /b)
:: that BREAK when inlined. Auto-concat will:
::   - Leave dead "exit /b" in the middle, halting execution
::   - Keep "call %%LIBS%%\..." references to non-existent files
::   - Create label collisions across modules
::
:: The Portable file is HAND-CRAFTED with proper transformation:
::   - All "call %%LIBS%%\xxx.bat fn_yyy" -> "call :fn_yyy"
::   - Module dispatchers stripped
::   - Functions grouped at bottom of file
::
:: ================================================================
:: HOW TO UPDATE THE PORTABLE VERSION
:: ================================================================
::
:: 1. Make changes in the modular source (RoboSync.bat + lib\*.bat)
:: 2. Test thoroughly in DEV mode
:: 3. Manually sync changes to dist\RoboSync_Portable.bat
::    - Find the corresponding :fn_ label
::    - Apply the same edit
::    - Remember: call "%LIBS%\module.bat" fn_name -> call :fn_name
:: 4. Test the Portable version independently
::
:: ================================================================

echo.
echo  This is a guidance file, not an automated script.
echo  Read the comments inside build.bat for instructions.
echo.
echo  DEV mode:  Run RoboSync.bat (modular, with lib\)
echo  RUN mode:  Copy dist\RoboSync_Portable.bat anywhere
echo.
pause
