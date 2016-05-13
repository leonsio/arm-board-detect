#!/bin/bash

collect_informations() 
{
    TMPFILE=$(mktemp /tmp/${0##*/}.XXXXXX)
    trap "rm \"${TMPFILE}\" ; exit 0" 0 1 2 3 15
    dmesg >"${TMPFILE}"
    SERVER_IP=$(hostname -I)
    CORES=$(grep -c ^processor /proc/cpuinfo)
    MEMTOTAL=$(( $(awk -F" " '/^MemTotal/ {print $2}' </proc/meminfo) / 1024 ))
    ARCH=$(lscpu | awk '/Architecture/ {print $2}')
    RTC=$(awk '/rtc0/ {print $(NF)}' <"${TMPFILE}")
    HB_PCI=$(grep '16c3:abcd' "${TMPFILE}") || HB_PCI=""
    HARDWARE=$(awk '/Hardware/ {print $3}' </proc/cpuinfo)
    [ "X${HARDWARE}" = "XAllwinner" ] && HARDWARE=$(awk '/Hardware/ {print $4}' </proc/cpuinfo)
    GMAC=$(grep "sun6i_gmac" "${TMPFILE}")$(grep "gmac0-" "${TMPFILE}") || GMAC=""
    SUN8IPHY="$(awk -F"PHY ID " '/PHY ID / {print $2}' <"${TMPFILE}")"
    LEDS=$(grep "green:ph02:led1" "${TMPFILE}") || LEDS=""
    TERMINUS=$(lsusb | grep -i "1a40:0101") || TERMINUS=""
    #GL830=$(lsusb | grep -i "05e3:0718")
    SWITCH=$(grep "BCM53125" "${TMPFILE}") || SWITCH=""
   # INTERUPT=$(grep "eth0" /proc/interrupts)
    WIFI8189ES=$(lsmod | grep 8189es | grep -v "0 $" | grep -v "0$") || WIFI8189ES="" # ignore when not loaded
    WIFIAP6211=$(lsmod | grep ap6211) || WIFIAP6211=""
    read VERSION </proc/version
} # collect_informations


detect_board() 
{
    BOARD_VERSION=""
    if [ "$ARCH" = "armv7l" ]; then
        case $HARDWARE in
            # Raspberry Pi (@todo detect revisions)
            BCM2708)
                BOARD_TYPE="Raspberry Pi"
                BOARD_VERSION="1"
                ;;
            # Raspberry Pi
            BCM2709)
                REVISION=$(cat /proc/cpuinfo | grep 'Revision' | awk '{print $3}' | sed 's/^1000//')
                BOARD_TYPE="Rapsberry Pi"
                case $REVISION in
                    a02082|a22082)
                        BOARD_VERSION="3"
                        ;;
                    a01041|a21041)
                        BOARD_VERSION="2"
                        ;;
                    900092)
                        BOARD_VERSION="Zero"
                        ;;
                esac
                ;;
            # Allwinner
            sun*)
                BOARD_TYPE="ALLWINNER"
                if [ $HARDWARE = "sun4i" ] || [ $HARDWARE = "Allwinner" ]; then
                    BOARD_TYPE="Cubieboard"
                fi
    
                if [ $HARDWARE = "sun7i" ]
                then
                    if [ $MEMTOTAL -gt 1500 ]; then
                        BOARD_TYPE="Cubietruck"
                    elif [ -n "$GMAC" ]; then
                        if [ "$TERMINUS" != "" ]; then
                            BOARD_TYPE="Orange Pi"
                        elif [ "$SWITCH" != "" ]; then
                            BOARD_TYPE="Lamobo"
                            BOARD_VERSION="R1"
                        elif [ "$LEDS" != "" ]; then
                            BOARD_TYPE="Olimex"
                            BOARD_VERSION="Lime 2"
                        elif [ "$WIFIAP6211" != "" ]; then
                            BOARD_TYPE="Banana Pi"            
                            BOARD_VERSION="Pro"
                        else
                            BOARD_TYPE="Banana Pi"
                        fi
                    elif [ "$LEDS" != "" ]; then
                        BOARD_TYPE="Olimex"
                        BOARD_VERSION="Lime"
                    elif [ $MEMTOTAL -lt 1500 ]; then
                        BOARD_TYPE="Olimex"
                        BOARD_VERSION="Micro"
                    else
                        BOARD_TYPE="Cubieboard"
                    fi
                fi

                if [ $HARDWARE = "sun8i" ]; then
                    BOARD_TYPE="Orange H3"
    
                    if [ "$TERMINUS" != "" ]; then
                        BOARD_TYPE="Orange Pi+"

                        if [ $MEMTOTAL -gt 1500 ]; then
                            if [ ${CORES} -eq 4 ]; then
                                BOARD_TYPE="Orange Pi+"
                                BOARD_VERSION="2"
                            elif [ ${CORES} -eq 8 ]; then
                                BOARD_TYPE="Banana Pi"
                                BOARD_VERSION="M3"
                            else
                                BOARD_TYPE="Unknown Hardware"
                            fi
                        fi
    
                        case ${SUN8IPHY} in
                            00441400*)
                                if [ "$WIFI8189ES" != "" ]; then
                                    BOARD_TYPE="Orange Pi"
                                    BOARD_VERSION="2"
                                else
                                    BOARD_TYPE="Orange Pi"
                                    BOARD_VERSION="2 mini"
                                fi
                                ;;
                        esac
                    elif [ "$WIFI8189ES" != "" ]; then
                        BOARD_TYPE="Orange Pi"
                        BOARD_VERSION="Lite"
                    elif [ $MEMTOTAL -gt 600 ]; then
                        case ${SUN8IPHY} in
                            00441400*)
                                BOARD_TYPE="Orange Pi"
                                BOARD_VERSION="PC"
                                ;;
                            *)
                                BOARD_TYPE="Banana Pi"
                                BOARD_TYPE="M2+"
                                ;;
                        esac
                    else
                        BOARD_TYPE="Orange Pi"
                        BOARD_TYPE="One"
                    fi
                fi

                ;;
            # Odroid
            ODROID*)
                BOARD_TYPE="Odroid"
                BOARD_VERSION=$(echo ${HARDWARE} | sed 's/ODROID-\?//')
                ;;
            Marvell)
                BOARD_TYPE="Marvell"
                BOARD_VERSION="Clearfog"
                ;;
            Freescale)
                if [ $MEMTOTAL -gt 1500 ]; then
                    BOARD_TYPE="Cubox i4"
                elif [ "$HB_PCI" != "" ]; then
                    BOARD_TYPE="HB i2eX"
                elif [ "$RTC" = "rtc0" ]; then
                    BOARD_TYPE="Cubox i2eX"
                elif [ "$CORES" = 1 ]; then
                    BOARD_TYPE="HB i1"
                else
                    BOARD_TYPE="HB i2"
                fi
                if [ -f /proc/asound/imxvt1613audio/id ]; then
                    BOARD_TYPE="Udoo"
                fi
                ;;
            # Actions ATM
            gs705a)
                if [ $MEMTOTAL == 2004 ]; then
                    BOARD_TYPE="Roseapple Pi"
                else
                    BOARD_TYPE="Guitar" #LeMaker
                fi
            
        esac
    elif [ "$ARCH" = "aarch64" ]; then
        if [ $HARDWARE = "ODROID-C2" ]; then
            BOARD_TYPE="Odroid"
            BOARD_VERSION=$(echo ${HARDWARE} | sed 's/ODROID-\?//')
        fi
        if [ $HARDWARE = "sun50iw1p1" ]; then
            if [ $MEMTOTAL -gt 600 ]; then
                BOARD_TYPE="Pine64+"                
            else 
                BOARD_TYPE="Pine64"
            fi
        fi
    fi

    if [ -f /proc/device-tree/model ]; then
        MACHINE=$(cat /proc/device-tree/model)
    fi
    
    if [[ $MACHINE == *LIME2 ]]; then 
        BOARD_TYPE="Olimex" 
        BOARD_VERSION="Lime 2" 
    fi
    if [[ $MACHINE == *LIME ]]; then 
        BOARD_TYPE="Olimex" 
        BOARD_VERSION="Lime" 
    fi
    if [[ $MACHINE == *Micro ]]; then 
        BOARD_TYPE="Olimex" 
        BOARD_VERSION="Micro" 
    fi
    if [[ $MACHINE == *Banana* ]]; then BOARD_TYPE="Banana Pi"; fi
    if [[ $MACHINE == *Udoo* ]]; then BOARD_TYPE="Udoo"; fi
    if [[ $MACHINE == *Lamobo* ]]; then 
        BOARD_TYPE="Lamobo" 
        BOARD_VERSION="R1" 
    fi
    if [[ $MACHINE == *Neo* ]]; then 
        BOARD_TYPE="Udoo" 
        BOARD_VERSION="Neo"
    fi
    if [[ $MACHINE == *Cubietruck* ]]; then BOARD_TYPE="Cubietruck"; fi
    if [[ $MACHINE == *Cubieboard* ]]; then BOARD_TYPE="Cubieboard"; fi
    if [[ $MACHINE == *Pro* ]]; then 
        BOARD_TYPE="Banana Pi" 
        BOARD_VERSION="Pro" 
    fi
    if [[ $MACHINE == *M2* ]]; then 
        BOARD_TYPE="Banana Pi" 
        BOARD_VERSION="M2" 
    fi
    if [[ $MACHINE == *AMLOGIC* ]]; then 
        BOARD_TYPE="Odroid" 
        BOARD_VERSION="C1" 
    fi
    if [[ $MACHINE == *HummingBoard2* ]]; then 
        BOARD_TYPE="HummingBoard" 
        BOARD_VERSION="2" 
    fi

}

collect_informations
detect_board

