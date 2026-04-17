@echo off
:: ================================================================
:: MODULE : discover.bat
:: PURPOSE: Tu dong phat hien nguon backup (Profiles, Partitions, USB)
:: NOTE  : Phan biet Fixed vs USB bang fsutil (native tu XP+)
::         Khong dung wmic.
:: ================================================================
call :%*
exit /b

:: ================================================================
:: FUNCTION: fn_detect_profiles
:: DESC: Quet C:\Users, loai bo profile he thong
:: SETS  : PROFILE_COUNT, PROFILE_n_PATH, PROFILE_n_NAME
:: ================================================================
:fn_detect_profiles
    set /a PROFILE_COUNT=0

    if not exist "C:\Users" (
        echo  [!!] C:\Users not found. Skipping.
        goto :eof
    )

    for /d %%U in (C:\Users\*) do (
        set "_uname=%%~nxU"
        if /i not "!_uname!"=="Public" (
        if /i not "!_uname!"=="Default" (
        if /i not "!_uname!"=="Default User" (
        if /i not "!_uname!"=="All Users" (
            set /a PROFILE_COUNT+=1
            set "PROFILE_!PROFILE_COUNT!_PATH=%%U"
            set "PROFILE_!PROFILE_COUNT!_NAME=!_uname!"
        ))))
    )
    goto :eof

:: ================================================================
:: FUNCTION: fn_detect_partitions
:: DESC: Quet o dia D-Z, phan biet Fixed vs USB/Removable
::       Dung fsutil fsinfo drivetype (native tu XP+, can admin)
:: SETS  : PART_COUNT, PART_n_PATH, PART_n_NAME, PART_n_TYPE
::         PART_n_TYPE = Fixed / USB
:: ================================================================
:fn_detect_partitions
    set /a PART_COUNT=0
    for %%D in (D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
        if exist "%%D:\" (
            set "_dtype=Fixed"
            set "_dlabel=Fixed Disk"

            REM Kiem tra drive type bang fsutil (an toan trong block)
            for /f "tokens=*" %%T in ('fsutil fsinfo drivetype %%D: 2^>nul') do (
                set "_line=%%T"
                echo "!_line!" | find "Removable" >nul 2>&1 && (
                    set "_dtype=USB"
                    set "_dlabel=USB/Removable"
                )
                echo "!_line!" | find "CD-ROM" >nul 2>&1 && set "_dtype=CDROM"
            )

            REM Bo qua CD-ROM
            if /i not "!_dtype!"=="CDROM" (
                set /a PART_COUNT+=1
                set "PART_!PART_COUNT!_PATH=%%D:\"
                set "PART_!PART_COUNT!_NAME=%%D: ^(!_dlabel!^)"
                set "PART_!PART_COUNT!_TYPE=!_dtype!"
            )
        )
    )
    goto :eof

:: ================================================================
:: FUNCTION: fn_detect_remote
:: DESC: Quet thu muc con tren network share
:: PARAMS: %1 = Network path (VD: \\192.168.1.100\Backup)
:: SETS  : REMOTE_COUNT, REMOTE_n_PATH, REMOTE_n_NAME
:: ================================================================
:fn_detect_remote
    set /a REMOTE_COUNT=0

    if "%~1"=="" (
        echo  [!!] Network path is empty. Skipping.
        goto :eof
    )

    for /d %%D in ("%~1\*") do (
        set /a REMOTE_COUNT+=1
        set "REMOTE_!REMOTE_COUNT!_PATH=%%D"
        set "REMOTE_!REMOTE_COUNT!_NAME=%%~nxD"
    )

    if !REMOTE_COUNT! equ 0 (
        echo  [--] No folders found in %~1
    )
    goto :eof

:: ================================================================
:: FUNCTION: fn_detect_profile_subdirs
:: DESC: Quet cac thu muc con cua 1 backup profile (cho Restore UC4)
::       Tra ve danh sach cac subdir co the restore
:: PARAMS: %1 = Profile backup path
:: SETS  : SUBDIR_COUNT, SUBDIR_n_NAME
:: ================================================================
:fn_detect_profile_subdirs
    set /a SUBDIR_COUNT=0

    if "%~1"=="" goto :eof
    if not exist "%~1" goto :eof

    REM Danh sach cac thu muc can restore (theo SRS 3.3)
    for %%F in (Desktop Documents Downloads Pictures Videos Music Favorites Links Contacts) do (
        if exist "%~1\%%F" (
            set /a SUBDIR_COUNT+=1
            set "SUBDIR_!SUBDIR_COUNT!_NAME=%%F"
        )
    )

    REM AppData\Roaming (dac biet - co backslash)
    if exist "%~1\AppData\Roaming" (
        set /a SUBDIR_COUNT+=1
        set "SUBDIR_!SUBDIR_COUNT!_NAME=AppData\Roaming"
    )
    goto :eof
