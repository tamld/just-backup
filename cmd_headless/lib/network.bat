@echo off
:: ================================================================
:: MODULE : network.bat
:: PURPOSE: Quan ly ket noi mang (Static IP + DHCP), net use, ping
::
:: VARIABLE SCOPING:
::   GLOBAL (set by caller, read here):
::     LIBS, LOG_DIR
::   PIPELINE (set here, consumed by caller):
::     DEST_IP, DEST_SHARE, NET_USER, NET_PASS, NETWORK_PATH
::     INPUT_OK, NET_PING_OK, NET_MAP_OK
::     NET_TYPE       = DIRECT / DHCP
::     NET_IFACE      = Interface name (cho static IP)
::     NET_LOCAL_IP    = IP local da set (cho static IP)
::   LOCAL (chi ton tai trong ham):
::     _ip, _user, _pass, _iface, _lip, _sub, _rip
:: ================================================================
call :%*
exit /b

:: ================================================================
:: FUNCTION: fn_select_network_type
:: DESC: Cho user chon loai ket noi mang
:: SETS  : NET_TYPE = DIRECT / DHCP
:: ================================================================
:fn_select_network_type
    echo.
    echo  [>>] CHON LOAI KET NOI MANG
    echo  ------------------------------------------------------------
    echo   [1] Cap truc tiep (Direct Cable - Static IP)
    echo       Dung khi noi 2 may bang cap mang, khong qua router.
    echo       Script se tu set IP tinh cho ban.
    echo.
    echo   [2] Mang co san (DHCP - Router / Modem)
    echo       Dung khi 2 may chung mang LAN, da co IP tu DHCP.
    echo  ------------------------------------------------------------
    choice /n /c 12 /m "  Chon [1-2]: "
    if !errorlevel! equ 2 (
        set "NET_TYPE=DHCP"
    ) else (
        set "NET_TYPE=DIRECT"
    )
    goto :eof

:: ================================================================
:: FUNCTION: fn_setup_direct_cable
:: DESC: Cau hinh static IP cho ket noi cap truc tiep
::       - Quet va hien thi cac network interface
::       - Set IP tinh cho may local
::       - Luu ten interface de phuc hoi DHCP sau
:: SETS  : NET_IFACE, NET_LOCAL_IP, DEST_IP, DIRECT_SETUP_OK
:: ================================================================
:fn_setup_direct_cable
    set "DIRECT_SETUP_OK=0"
    echo.
    echo  [>>] CAU HINH CAP TRUC TIEP (Static IP)
    echo  ------------------------------------------------------------
    echo.

    :: --- Buoc 1: Hien thi danh sach interface ---
    echo  [--] Cac Network Interface hien co:
    echo.
    for /f "skip=3 tokens=3,4*" %%a in ('netsh interface show interface') do (
        echo       %%c  [%%a - %%b]
    )
    echo.
    set /p "NET_IFACE=  Ten interface (VD: Ethernet): "
    if "!NET_IFACE!"=="" (
        echo  [!!] Ten interface trong. Huy.
        goto :eof
    )

    :: --- Buoc 2: Nhap IP ---
    echo.
    echo  [--] Goi y IP cho cap truc tiep:
    echo       May nay : 192.168.0.1
    echo       May kia : 192.168.0.2
    echo       Subnet  : 255.255.255.0
    echo.
    set /p "NET_LOCAL_IP=  IP cho may NAY (VD: 192.168.0.1): "
    if "!NET_LOCAL_IP!"=="" (
        echo  [!!] IP trong. Huy.
        goto :eof
    )

    set "_sub=255.255.255.0"
    set /p "_sub=  Subnet Mask [255.255.255.0]: "

    set /p "DEST_IP=  IP may DICH (VD: 192.168.0.2): "
    if "!DEST_IP!"=="" (
        echo  [!!] IP dich trong. Huy.
        goto :eof
    )

    :: --- Buoc 3: Ap dung Static IP ---
    echo.
    echo  [..] Dang set IP tinh: !NET_LOCAL_IP! / !_sub! tren "!NET_IFACE!" ...
    netsh interface ip set address "!NET_IFACE!" static !NET_LOCAL_IP! !_sub! >nul 2>&1
    if !errorlevel! neq 0 (
        echo  [!!] Khong the set IP. Kiem tra ten interface.
        echo  [--] Goi y: Chay "ncpa.cpl" de xem ten chinh xac.
        goto :eof
    )

    :: Doi mang on dinh
    echo  [..] Doi mang on dinh (3 giay)...
    timeout /t 3 /nobreak >nul

    echo  [OK] Da set IP !NET_LOCAL_IP! tren "!NET_IFACE!".
    echo  [--] Sau khi backup xong, script se tu phuc hoi DHCP.
    set "DIRECT_SETUP_OK=1"
    goto :eof

:: ================================================================
:: FUNCTION: fn_restore_dhcp
:: DESC: Phuc hoi DHCP tren interface da set static
:: PARAMS: (doc tu NET_IFACE global)
:: ================================================================
:fn_restore_dhcp
    if not defined NET_IFACE goto :eof
    if "!NET_IFACE!"=="" goto :eof

    echo  [..] Phuc hoi DHCP tren "!NET_IFACE!" ...
    netsh interface ip set address "!NET_IFACE!" dhcp >nul 2>&1
    netsh interface ip set dns "!NET_IFACE!" dhcp >nul 2>&1
    echo  [OK] Da phuc hoi DHCP. Mang se tu lay IP moi.

    :: Clear state
    set "NET_IFACE="
    set "NET_LOCAL_IP="
    goto :eof

:: ================================================================
:: FUNCTION: fn_test_connection
:: DESC: Ping may dich (2 lan, chiu loi mang chap chon)
:: PARAMS: %1 = IP/Hostname
:: SETS  : NET_PING_OK = 1 / 0
:: ================================================================
:fn_test_connection
    set "NET_PING_OK=0"

    :: Fail-fast
    if "%~1"=="" (
        echo  [!!] IP trong. Bo qua ping.
        goto :eof
    )

    echo  [--] Ping %~1 (2 lan)...
    ping -n 2 -w 1500 "%~1" >nul 2>&1
    if !errorlevel! equ 0 (
        set "NET_PING_OK=1"
        echo  [OK] %~1 dang hoat dong.
    ) else (
        echo  [!!] Khong ping duoc %~1.
        if "!NET_TYPE!"=="DIRECT" (
            echo  [--] Kiem tra: Cap da cam chua? May dich da set IP chua?
        ) else (
            echo  [--] Kiem tra: 2 may chung mang? Firewall mo port 445?
        )
    )
    goto :eof

:: ================================================================
:: FUNCTION: fn_map_credentials
:: DESC: Map credentials bang net use (IPC$)
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
        echo  [!!] IP trong. Huy.
        goto :eof
    )
    if "!_user!"=="" (
        echo  [!!] Username trong. Huy.
        goto :eof
    )

    :: Xoa session cu
    net use "\\!_ip!\IPC$" /delete /y >nul 2>&1

    :: Map
    echo  [--] Xac thuc \\!_ip! ...
    net use "\\!_ip!\IPC$" "!_pass!" /user:"!_user!" >nul 2>&1
    if !errorlevel! equ 0 (
        set "NET_MAP_OK=1"
        echo  [OK] Xac thuc thanh cong.
    ) else (
        echo  [!!] Xac thuc that bai.
        echo  [--] Kiem tra: User/Pass dung? File Sharing bat tren may dich?
    )

    :: ZERO-LEAK: Xoa pass ngay
    set "_pass="
    goto :eof

:: ================================================================
:: FUNCTION: fn_unmap_credentials
:: PARAMS: %1 = IP
:: ================================================================
:fn_unmap_credentials
    if not "%~1"=="" (
        net use "\\%~1\IPC$" /delete /y >nul 2>&1
        echo  [--] Ngat ket noi \\%~1.
    )
    goto :eof

:: ================================================================
:: FUNCTION: fn_cleanup_all
:: DESC: Ngat toan bo net use + phuc hoi DHCP neu can
:: ================================================================
:fn_cleanup_all
    net use * /delete /y >nul 2>&1
    echo  [--] Da don dep ket noi mang.
    :: Phuc hoi DHCP neu dang o che do Direct Cable
    if defined NET_IFACE call :fn_restore_dhcp
    goto :eof

:: ================================================================
:: FUNCTION: fn_input_credentials
:: DESC: Nhap Share, User, Pass (IP da co tu truoc)
:: SETS  : DEST_SHARE, NET_USER, NET_PASS, NETWORK_PATH, INPUT_OK
:: ================================================================
:fn_input_credentials
    set "INPUT_OK=0"

    :: IP phai da duoc set truoc (tu DHCP prompt hoac Direct setup)
    if "!DEST_IP!"=="" (
        echo.
        set /p "DEST_IP=  IP may dich (VD: 192.168.1.100): "
        if "!DEST_IP!"=="" (
            echo  [!!] IP trong. Huy.
            goto :eof
        )
    )

    echo.
    set /p "DEST_SHARE=  Ten Share (VD: Backup hoac C$): "
    if "!DEST_SHARE!"=="" (
        echo  [!!] Share trong. Huy.
        goto :eof
    )

    set /p "NET_USER=  Username (VD: admin hoac DOMAIN\admin): "
    if "!NET_USER!"=="" (
        echo  [!!] Username trong. Huy.
        goto :eof
    )

    :: An password
    echo.
    echo   Nhap Password:
    set "NET_PASS="
    for /f "delims=" %%p in ('powershell -Command "[Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR((Read-Host -AsSecureString)))" 2^>nul') do set "NET_PASS=%%p"
    if "!NET_PASS!"=="" (
        set /p "NET_PASS=  Password [hien thi]: "
    )

    set "NETWORK_PATH=\\!DEST_IP!\!DEST_SHARE!"
    set "INPUT_OK=1"
    goto :eof
