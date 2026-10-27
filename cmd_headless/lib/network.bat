@echo off
:: ================================================================
:: MODULE : network.bat
:: PURPOSE: Network management (Static IP + DHCP), net use, ping
::
:: VARIABLE SCOPING:
::   GLOBAL (set by caller, read here):
::     LIBS, LOG_DIR
::   PIPELINE (set here, consumed by caller):
::     DEST_IP, DEST_SHARE, NET_USER, NET_PASS, NETWORK_PATH
::     INPUT_OK, NET_PING_OK, NET_MAP_OK
::     NET_TYPE       = DIRECT / DHCP
::     NET_IFACE      = Interface name (for static IP)
::     NET_LOCAL_IP   = Local static IP assigned
::   LOCAL (_prefix, function-scoped by convention):
::     _ip, _user, _pass, _iface, _lip, _sub, _rip
:: ================================================================
call :%*
exit /b

:: ================================================================
:: FUNCTION: fn_select_network_type
:: DESC: Let user choose network connection type
:: SETS  : NET_TYPE = DIRECT / DHCP
:: ================================================================
:fn_select_network_type
    echo.
    echo  [^>^>] SELECT NETWORK MODE
    echo  ------------------------------------------------------------
    echo   [1] Direct Cable (Static IP)
    echo       Use when 2 PCs are connected via Ethernet cable,
    echo       without a router. Script will set static IP for you.
    echo.
    echo   [2] Existing Network (DHCP - Router / Modem)
    echo       Use when both PCs are on the same LAN with DHCP.
    echo.
    echo   [0] Go back
    echo  ------------------------------------------------------------
    choice /n /c 120 /m "  Choose [1/2/0]: "
    if !errorlevel! equ 3 (
        set "NET_TYPE=CANCEL"
        goto :eof
    )
    if !errorlevel! equ 2 (
        set "NET_TYPE=DHCP"
    ) else (
        set "NET_TYPE=DIRECT"
    )
    goto :eof

:: ================================================================
:: FUNCTION: fn_setup_direct_cable
:: DESC: Configure static IP for direct cable connection
::       - Scan and display network interfaces
::       - Offer default "Ethernet" with Y/N confirmation
::       - Set static IP on local machine
::       - Save interface name for DHCP restoration later
:: SETS  : NET_IFACE, NET_LOCAL_IP, DEST_IP, DIRECT_SETUP_OK
:: ================================================================
:fn_setup_direct_cable
    set "DIRECT_SETUP_OK=0"
    echo.
    echo  [^>^>] DIRECT CABLE SETUP (Static IP)
    echo  ------------------------------------------------------------
    echo.

    :: --- Step 1: List available interfaces ---
    echo  [--] Available network interfaces:
    echo.
    for /f "skip=3 tokens=3,4*" %%a in ('netsh interface show interface') do (
        echo       %%c  [%%a - %%b]
    )
    echo.

    :: --- Step 1b: Default "Ethernet" with Y/N confirmation ---
    echo  [--] Default interface: Ethernet
    choice /n /c YN /m "  Use 'Ethernet'? [Y/N]: "
    if !errorlevel! equ 1 (
        set "NET_IFACE=Ethernet"
    ) else (
        set "NET_IFACE="
        set /p "NET_IFACE=  Enter interface name: "
        if "!NET_IFACE!"=="" (
            echo  [!!] Interface name empty. Cancelled.
            goto :eof
        )
    )

    :: --- Step 2: Enter IPs ---
    echo.
    echo  [--] Suggested IP for direct cable:
    echo       This PC : 192.168.0.1  ^|  Remote PC: 192.168.0.2
    echo       Or      : 10.0.0.1     ^|  Remote PC: 10.0.0.2
    echo.
    set "NET_LOCAL_IP="
    set /p "NET_LOCAL_IP=  IP for THIS PC (e.g. 192.168.0.1): "
    if "!NET_LOCAL_IP!"=="" (
        echo  [!!] IP empty. Cancelled.
        goto :eof
    )

    set "_sub=255.255.255.0"
    set /p "_sub=  Subnet Mask [255.255.255.0]: "

    set "DEST_IP="
    set /p "DEST_IP=  Remote PC IP (e.g. 192.168.0.2): "
    if "!DEST_IP!"=="" (
        echo  [!!] Remote IP empty. Cancelled.
        goto :eof
    )

    :: --- Step 3: Apply Static IP ---
    echo.
    echo  [..] Setting static IP: !NET_LOCAL_IP! / !_sub! on "!NET_IFACE!" ...
    netsh interface ip set address "!NET_IFACE!" static !NET_LOCAL_IP! !_sub! >nul 2>&1
    if !errorlevel! neq 0 (
        echo  [!!] Failed to set IP. Check interface name.
        echo  [--] Hint: Run "ncpa.cpl" to see exact interface names.
        goto :eof
    )

    :: Wait for network to stabilize
    echo  [..] Waiting for network to stabilize (3s)...
    timeout /t 3 /nobreak >nul

    echo  [OK] Set !NET_LOCAL_IP! on "!NET_IFACE!".
    echo  [--] DHCP will be restored automatically after backup.
    set "DIRECT_SETUP_OK=1"
    goto :eof

:: ================================================================
:: FUNCTION: fn_restore_dhcp
:: DESC: Restore DHCP on interface that was set to static
:: PARAMS: (reads NET_IFACE global)
:: ================================================================
:fn_restore_dhcp
    if not defined NET_IFACE goto :eof
    if "!NET_IFACE!"=="" goto :eof

    echo  [..] Restoring DHCP on "!NET_IFACE!" ...
    netsh interface ip set address "!NET_IFACE!" dhcp >nul 2>&1
    set "RC=!errorlevel!"
    netsh interface ip set dns "!NET_IFACE!" dhcp >nul 2>&1
    if !RC! neq 0 (
        echo  [!!] Failed to restore DHCP on "!NET_IFACE!". Check manually via ncpa.cpl.
    ) else (
        echo  [OK] DHCP restored. Network will obtain new IP.
    )

    :: Clear state
    set "NET_IFACE="
    set "NET_LOCAL_IP="
    goto :eof

:: ================================================================
:: FUNCTION: fn_test_connection
:: DESC: Ping target host (parse output for TTL= instead of
::       relying on ERRORLEVEL which is unreliable on Windows)
:: PARAMS: %1 = IP/Hostname
:: SETS  : NET_PING_OK = 1 / 0
:: ================================================================
:fn_test_connection
    set "NET_PING_OK=0"

    :: Fail-fast
    if "%~1"=="" (
        echo  [!!] IP is empty. Skipping ping.
        goto :eof
    )

    echo  [--] Pinging %~1 ...
    set "_ping_result="
    for /f "tokens=*" %%L in ('ping -n 2 -w 1500 "%~1" 2^>nul') do (
        echo "%%L" | find "TTL=" >nul 2>&1 && set "_ping_result=OK"
    )

    if "!_ping_result!"=="OK" (
        set "NET_PING_OK=1"
        echo  [OK] %~1 is reachable.
    ) else (
        echo  [!!] Cannot reach %~1.
        if "!NET_TYPE!"=="DIRECT" (
            echo  [--] Check: Cable connected? Remote PC has static IP set?
        ) else (
            echo  [--] Check: Both PCs on same network? Firewall allows port 445?
        )
    )
    goto :eof

:: ================================================================
:: FUNCTION: fn_map_credentials
:: DESC: Map credentials via net use (IPC$)
:: PARAMS: %1 = IP, %2 = Username, %3 = Password
:: SETS  : NET_MAP_OK = 1 / 0
:: ================================================================
:fn_map_credentials
    set "NET_MAP_OK=0"
    set "_ip=%~1"
    set "_user=%~2"
    set "_pass=%~3"

    :: Fail-fast
    if "!_ip!"=="" (
        echo  [!!] IP is empty. Cancelled.
        goto :eof
    )
    if "!_user!"=="" (
        echo  [!!] Username is empty. Cancelled.
        goto :eof
    )

    :: Clear old sessions
    net use "\\!_ip!\IPC$" /delete /y >nul 2>&1

    :: Map
    echo  [--] Authenticating \\!_ip! ...
    net use "\\!_ip!\IPC$" "!_pass!" /user:"!_user!" >nul 2>&1
    if !errorlevel! equ 0 (
        set "NET_MAP_OK=1"
        set "NET_STATUS=CONNECTED"
        echo  [OK] Authentication successful.
    ) else (
        echo  [!!] Authentication failed.
        echo  [--] Check: Correct User/Pass? File Sharing enabled on remote PC?
    )

    :: ZERO-LEAK: Clear password immediately
    set "_pass="
    goto :eof

:: ================================================================
:: FUNCTION: fn_unmap_credentials
:: PARAMS: %1 = IP
:: ================================================================
:fn_unmap_credentials
    if not "%~1"=="" (
        net use "\\%~1\IPC$" /delete /y >nul 2>&1
        echo  [--] Disconnected from \\%~1.
    )
    goto :eof

:: ================================================================
:: FUNCTION: fn_cleanup_all
:: DESC: Disconnect all net use + restore DHCP if needed
:: ================================================================
:fn_cleanup_all
    net use * /delete /y >nul 2>&1
    set "NET_STATUS=NOT_CONNECTED"
    set "NET_MAP_OK="
    echo  [--] All network connections cleared.
    :: Restore DHCP if in Direct Cable mode
    if defined NET_IFACE call :fn_restore_dhcp
    goto :eof

:: ================================================================
:: FUNCTION: fn_input_credentials
:: DESC: Input Share, User, Pass (IP should already be set)
:: SETS  : DEST_SHARE, NET_USER, NET_PASS, NETWORK_PATH, INPUT_OK
:: ================================================================
:fn_input_credentials
    set "INPUT_OK=0"

    :: IP must be set before this (from DHCP prompt or Direct setup)
    if "!DEST_IP!"=="" (
        echo.
        set "DEST_IP="
        set /p "DEST_IP=  Remote IP (e.g. 192.168.1.100): "
        if "!DEST_IP!"=="" (
            echo  [!!] IP is empty. Cancelled.
            goto :eof
        )
    )

    echo.
    set "DEST_SHARE="
    set /p "DEST_SHARE=  Share name (e.g. Backup or C$): "
    if "!DEST_SHARE!"=="" (
        echo  [!!] Share name empty. Cancelled.
        goto :eof
    )

    set "NET_USER="
    set /p "NET_USER=  Username (e.g. admin or DOMAIN\admin): "
    if "!NET_USER!"=="" (
        echo  [!!] Username empty. Cancelled.
        goto :eof
    )

    :: Password input (try masked, fallback to plain)
    echo.
    echo   Enter Password:
    set "NET_PASS="
    for /f "delims=" %%p in ('powershell -Command "[Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR((Read-Host -AsSecureString)))" 2^>nul') do set "NET_PASS=%%p"
    if "!NET_PASS!"=="" (
        set /p "NET_PASS=  Password (plaintext fallback): "
    )

    set "NETWORK_PATH=\\!DEST_IP!\!DEST_SHARE!"
    set "INPUT_OK=1"
    goto :eof

:: ================================================================
:: FUNCTION: fn_get_connection_status
:: DESC: Check current network connection status
:: SETS  : NET_STATUS = CONNECTED / NOT_CONNECTED
:: ================================================================
:fn_get_connection_status
    set "NET_STATUS=NOT_CONNECTED"
    if not defined NETWORK_PATH goto :eof
    if "!NETWORK_PATH!"=="" goto :eof
    if not defined NET_MAP_OK goto :eof
    if "!NET_MAP_OK!"=="1" (
        set "NET_STATUS=CONNECTED"
    )
    goto :eof

:: ================================================================
:: FUNCTION: fn_show_status
:: DESC: Display current network connection info
:: ================================================================
:fn_show_status
    call :fn_get_connection_status
    echo.
    echo  [>>] NETWORK STATUS
    echo  ------------------------------------------------------------
    if "!NET_STATUS!"=="CONNECTED" (
        echo  [OK] Status   : CONNECTED
        echo  [--] Target   : !NETWORK_PATH!
        echo  [--] User     : !NET_USER!
        echo  [--] Mode     : !NET_TYPE!
        if defined NET_IFACE (
            echo  [--] Interface: !NET_IFACE! ^(Static IP: !NET_LOCAL_IP!^)
        )
    ) else (
        echo  [--] Status   : NOT CONNECTED
        echo  [--] Use Network Setup to configure connection.
    )
    echo  ------------------------------------------------------------
    echo.
    goto :eof
