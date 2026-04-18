@echo off
:: ================================================================
:: MODULE : engine.bat
:: PURPOSE: Loi Robocopy - Build flags, thuc thi, phan tich ket qua
:: NOTE  : Ho tro 5 type: PROFILE, PARTITION, USB, RESTORE_MERGE, RESTORE_MIRROR
::         Auto-mkdir dest truoc khi chay robocopy
::         Khong dung wmic. Timestamp tu %date% %time%.
:: ================================================================
call :%*
exit /b

:: ================================================================
:: FUNCTION: fn_get_timestamp
:: SETS  : TIMESTAMP
:: ================================================================
:fn_get_timestamp
    set "_t=%time: =0%"
    set "TIMESTAMP=%date:~6,4%%date:~3,2%%date:~0,2%_%_t:~0,2%%_t:~3,2%%_t:~6,2%"
    set "TIMESTAMP=!TIMESTAMP:/=!"
    set "TIMESTAMP=!TIMESTAMP:-=!"
    set "TIMESTAMP=!TIMESTAMP: =0!"
    goto :eof

:: ================================================================
:: FUNCTION: fn_run_robocopy
:: DESC: Chay Robocopy voi flags toi uu theo loai backup
:: PARAMS: %1 = Source, %2 = Destination, %3 = Type
::         Type: PROFILE / PARTITION / USB / RESTORE_MERGE / RESTORE_MIRROR / CUSTOM
:: SETS  : LAST_RC_STATUS = SUCCESS / WARNING / FAILED
::         LAST_RC_CODE
:: ================================================================
:fn_run_robocopy
    set "_rc_src=%~1"
    set "_rc_dst=%~2"
    set "_rc_type=%~3"

    :: --- FAIL-FAST: Pre-check (SRS §9.3 - pre-clear not needed, params come from function args) ---
    if "!_rc_src!"=="" (
        echo  [!!] Source path trong. Huy thao tac.
        set "LAST_RC_STATUS=FAILED"
        set "LAST_RC_CODE=99"
        goto :eof
    )
    if "!_rc_dst!"=="" (
        echo  [!!] Destination path trong. Huy thao tac.
        set "LAST_RC_STATUS=FAILED"
        set "LAST_RC_CODE=99"
        goto :eof
    )
    if not exist "!_rc_src!" (
        echo  [!!] Source khong ton tai: !_rc_src!
        set "LAST_RC_STATUS=FAILED"
        set "LAST_RC_CODE=99"
        goto :eof
    )

    :: --- Auto-mkdir destination (SRS §5.1) ---
    if not exist "!_rc_dst!" (
        mkdir "!_rc_dst!" 2>nul
        if not exist "!_rc_dst!" (
            echo  [!!] Khong the tao thu muc dich: !_rc_dst!
            set "LAST_RC_STATUS=FAILED"
            set "LAST_RC_CODE=99"
            goto :eof
        )
    )

    :: --- Tao log file ---
    call :fn_get_timestamp
    if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" 2>nul
    set "_log_file=%LOG_DIR%\RS_!TIMESTAMP!.log"

    :: --- Build flags ---
    call :fn_build_flags "!_rc_type!"

    :: --- Load Exclusions from config.ini ---
    if exist "config.ini" (
        for /f "usebackq tokens=*" %%A in ("config.ini") do (
            set "_line=%%A"
            if not "!_line:~0,1!"==";" (
                if not "!_line:~0,1!"=="#" (
                    set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD ""!_line!"""
                )
            )
        )
    )

    :: --- Hien thi ---
    echo.
    echo  [^>^>] ROBOCOPY ENGINE
    echo  [--] Source : !_rc_src!
    echo  [--] Dest   : !_rc_dst!
    echo  [--] Type   : !_rc_type!
    echo  [--] Log    : !_log_file!
    echo.

    :: --- Thuc thi ---
    robocopy "!_rc_src!" "!_rc_dst!" !_BUILD_FLAGS! /LOG+:"!_log_file!" /TEE /V

    set "LAST_RC_CODE=!errorlevel!"

    :: --- Phan tich exit code (SRS §2) ---
    echo.
    if !LAST_RC_CODE! LEQ 3 (
        set "LAST_RC_STATUS=SUCCESS"
        echo  [OK] Hoan tat. Code=!LAST_RC_CODE!
    ) else if !LAST_RC_CODE! LEQ 7 (
        set "LAST_RC_STATUS=WARNING"
        echo  [!!] Hoan tat voi canh bao. Code=!LAST_RC_CODE!
    ) else (
        set "LAST_RC_STATUS=FAILED"
        echo  [!!] LOI NGHIEM TRONG. Code=!LAST_RC_CODE!
    )
    echo  [--] Log: !_log_file!

    :: --- PAUSE Strategy (SRS §11): PAUSE on abnormal results ---
    if /i "!LAST_RC_STATUS!"=="WARNING" pause
    if /i "!LAST_RC_STATUS!"=="FAILED" pause
    goto :eof

:: ================================================================
:: FUNCTION: fn_build_flags
:: DESC: Xay chuoi flags Robocopy theo loai
:: PARAMS: %1 = Type
:: SETS  : _BUILD_FLAGS
:: ================================================================
:fn_build_flags
    set "_btype=%~1"
    set "_BUILD_FLAGS="

    :: === RESTORE MERGE (UC4) - Dung /E, KHONG /MIR ===
    :: /E = Copy subdirs including empty. Giu nguyen file cu o dich.
    if /i "!_btype!"=="RESTORE_MERGE" (
        set "_BUILD_FLAGS=/E /Z /MT:16 /R:2 /W:1 /NP /ETA"
        goto :eof
    )

    :: === RESTORE MIRROR (UC5) - Dung /MIR ===
    if /i "!_btype!"=="RESTORE_MIRROR" (
        set "_BUILD_FLAGS=/MIR /Z /MT:16 /R:2 /W:1 /NP /ETA"
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "$Recycle.Bin""
        goto :eof
    )

    :: === BACKUP: Base flags ===
    :: /Z = Restartable mode (self-recovery on network drop, SRS §12)
    set "_BUILD_FLAGS=/MIR /Z /MT:16 /R:2 /W:1 /NP /ETA"

    :: === PROFILE ===
    if /i "!_btype!"=="PROFILE" (
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /ZB /XJ"
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "$Recycle.Bin""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "System Volume Information""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "AppData\Local\Temp""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "AppData\Local\Microsoft\Windows\INetCache""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "AppData\Local\Microsoft\Windows\Explorer""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "AppData\Local\Microsoft\WindowsApps""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "AppData\Local\Packages""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "AppData\Local\Programs""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "AppData\Local\CrashDumps""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "AppData\Local\Microsoft\Windows\WER""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "AppData\Local\Microsoft\Windows\Notifications""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "AppData\Local\D3DSCache""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "AppData\Local\Google\Chrome\User Data\Default\Cache""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "AppData\Local\Google\Chrome\User Data\Default\Code Cache""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "AppData\Local\Microsoft\Edge\User Data\Default\Cache""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "AppData\Local\Mozilla\Firefox""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XF "ntuser.dat.LOG*" "*.tmp" "Thumbs.db" "desktop.ini""
        goto :eof
    )

    :: === PARTITION (Fixed Disk) ===
    if /i "!_btype!"=="PARTITION" (
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "$Recycle.Bin" "System Volume Information""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XF "pagefile.sys" "hiberfil.sys" "swapfile.sys""
        goto :eof
    )

    :: === USB / REMOVABLE (nhe hon, it thread hon) ===
    if /i "!_btype!"=="USB" (
        set "_BUILD_FLAGS=/MIR /MT:8 /R:1 /W:0 /NP /ETA"
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "$Recycle.Bin""
        goto :eof
    )

    :: === CUSTOM (fallback) ===
    set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "$Recycle.Bin""
    goto :eof
