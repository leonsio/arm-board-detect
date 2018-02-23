#!/bin/bash
# Code based on armen181/Armbian/scripts/armhwinfo

BOARD_TYPE=""
BOARD_VERSION=""
collect_informations()
{
    TMPFILE=$(mktemp /tmp/${0##*/}.XXXXXX)
    trap "rm \"${TMPFILE}\" ; exit 0" 0 1 2 3 15
    dmesg >"${TMPFILE}"
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
    if [ -f /usr/bin/lsusb ]
    then
    	TERMINUS=$(lsusb | grep -i "1a40:0101") || TERMINUS=""
    fi
    GL830=$(lsusb | grep -i "05e3:0718") || GL830=""
    SWITCH=$(grep "BCM53125" "${TMPFILE}") || SWITCH=""
   # INTERUPT=$(grep "eth0" /proc/interrupts)
    WIFI8189ES=$(lsmod | grep 8189es | grep -v "0 $" | grep -v "0$") || WIFI8189ES="" # ignore when not loaded
    WIFIAP6211=$(lsmod | grep ap6211) || WIFIAP6211=""
    WIFIAP6212=$(lsmod | grep ap6212) || WIFIAP6212=""
    read VERSION </proc/version
} # collect_informations

detect_by_device_tree()
{
  MACHINE=$(cat /proc/device-tree/model | tr '\0' '\n' )

  case $MACHINE in
    *LIME2)
      SOC_VERSION="A20"
      SOC_VENDOR="ALLWINNER"
      BOARD_TYPE="Olimex"
      BOARD_VERSION="Lime 2"
      ;;
    *LIME)
      SOC_VERSION="A20"
      SOC_VENDOR="ALLWINNER"
      BOARD_TYPE="Olimex"
      BOARD_VERSION="Lime"
      ;;
    *RockPro64)
      SOC_VENDOR="ROCKCHIP"
      SOC_VERSION="RK3399"
      BOARD_TYPE="Rock"
      BOARD_VERSION="Pro64"
      ;;
    *Rock64)
      SOC_VENDOR="ROCKCHIP"
      SOC_VERSION="RK3328"
      # not the best way
      #SPI_SIZE=$(dmesg | grep m25p80 | cut -d"(" -f2 | awk '{print $1}')
      #if [ "$SPI_SIZE" = "16384" ]
      #then
          BOARD_TYPE="Rock"
          BOARD_VERSION="64"
      #fi
      #todo BOARD_VERSION -> 1/2/4GB RAM?
      # ROCK64 has 128mbit spi, renegade ??
      ;;
    *Micro)
      SOC_VERSION="A20"
      SOC_VENDOR="ALLWINNER"
      BOARD_TYPE="Olimex"
      BOARD_VERSION="Micro"
      ;;
    *Banana*)
      BOARD_TYPE="Banana Pi"
      #BOARD_VERSION=$(echo ${MACHTYPE} | cut -d" " -f3 )
      if [[ $MACHINE == *Pro* ]]; then
          BOARD_VERSION="Pro"
      fi
      if [[ $MACHINE == *M2* ]]; then
          BOARD_VERSION="M2"
      fi
      ;;
    *Udoo*)
      SOC_VENDOR="NXP"
      SOC_VERSION="i.MX6"
      BOARD_TYPE="Udoo"
      ;;
    *Neo*)
      SOC_VENDOR="NXP"
      SOC_VERSION="i.MX6"
      BOARD_TYPE="Udoo"
      BOARD_VERSION="NEO"
      ;;
    *Lamobo*)
      BOARD_TYPE="Lamobo"
      BOARD_VERSION="R1"
      ;;
    *Cubietech*)
      BOARD_TYPE="Cubietech"
      BOARD_VERSION=$(echo ${MACHTYPE} | cut -d" " -f2 )
      ;;
    *AMLOGIC*)
      BOARD_TYPE="Odroid"
      BOARD_VERSION="C1"
      ;;
    *HummingBoard2*)
      BOARD_TYPE="HummingBoard"
      BOARD_VERSION="2"
    esac
}

detect_board()
{
  # Broadcom
  case $HARDWARE in
    BCM2708)
      SOC_VENDOR="BROADCOM"
      SOC_VERSION="BCM2835"
      BOARD_TYPE="Raspberry Pi"
      BOARD_VERSION="1"
      ;;
    BCM2709|BCM2835|BCM2836|BCM2837)
      REVISION=$(cat /proc/cpuinfo | grep 'Revision' | awk '{print $3}' | sed 's/^1000//')
      SOC_VENDOR="BROADCOM"
      BOARD_TYPE="Raspberry Pi"
      case $REVISION in
        0012|0015|900021)
          BOARD_VERSION="A+"
          SOC_VERSION="BCM2835"
          ;;
        0010|0013|900032)
          BOARD_VERSION="B+"
          SOC_VERSION="BCM2835"
          ;;
        a01040|a01041|a21041)
          BOARD_VERSION="2"
          SOC_VERSION="BCM2836"
          ;;
        a22042)
          BOARD_VERSION="2"
          SOC_VERSION="BCM2837"
          ;;
        a02082|a22082|a32082)
          BOARD_VERSION="3"
          SOC_VERSION="BCM2837"
          ;;
        900092|900093)
          BOARD_VERSION="Zero"
          SOC_VERSION="BCM2835"
          ;;
        9000C1)
          BOARD_VERSION="Zero W"
          SOC_VERSION="BCM2835"
          ;;
        esac
      ;;
      # Allwinner http://linux-sunxi.org/Allwinner_SoC_Family
      sun*)
        SOC_VENDOR="ALLWINNER"
        case $HARDWARE in
          #sun4i* cortex-a8
          sun4iw1|sun4i)
            SOC_VERSION="A10"
            BOARD_TYPE="Cubietech"
            BOARD_VERSION="Cubieboard"
            ;;
          #sun8i* cortex-a7 smp
          sun8iw1*|sun6i)
            SOC_VERSION="A31"
            if [ $MEMTOTAL -gt 1500 ] # 2GB
            then
              BOARD_TYPE="Hummingbird"
              BOARD_VERSION="A31"
            else
              BOARD_TYPE="Banana Pi"
              BOARD_VERSION="M2"
            fi
            ;;
          sun8iw2|sun7i)
            SOC_VERSION="A20"
            if [ $MEMTOTAL -gt 1500 ]
            then
              BOARD_TYPE="Cubietech"
              BOARD_VERSION="Cubietruck"
            elif [ -n "$GMAC" ]; then
              if [ "$TERMINUS" != "" ]
              then
                BOARD_TYPE="Orange Pi"
              elif [ "$SWITCH" != "" ]
              then
                BOARD_TYPE="Lamobo"
                BOARD_VERSION="R1"
              elif [ "$LEDS" != "" ]
              then
                BOARD_TYPE="Olimex"
                BOARD_VERSION="Lime 2"
              elif [ "$WIFIAP6211" != "" ]
              then
                BOARD_TYPE="Banana"
                BOARD_VERSION="Pro"
              else
                BOARD_TYPE="Banana"
                BOARD_VERSION="Pi"
              fi
            elif [ "$LEDS" != "" ]
            then
              BOARD_TYPE="Olimex"
              BOARD_VERSION="Lime"
            elif [ $MEMTOTAL -lt 1500 ]
            then
              BOARD_TYPE="Olimex"
              BOARD_VERSION="Micro"
            else
              BOARD_TYPE="Cubietech"
              BOARD_VERSION="Cubieboard2"
            fi
            ;;
          sun8iw6|sun8i)
            SOC_VERSION="A83T"
            if [ "$WIFIAP6212" != "" ]
            then
              BOARD_TYPE="Banana Pi"
              BOARD_VERSION="M3"
            else
              BOARD_TYPE="Cubietech"
              BOARD_VERSION="Cubietruck Plus"
            fi
            ;;
          sun8iw7)
            SOC_VERSION="H3"
            if [ $MEMTOTAL -gt 1500 ] # 2GB
            then
              BOARD_TYPE="Orange Pi"
              if [ "$GL830" != "" ]
              then
                  BOARD_VERSION="Plus 2"
              else
                  BOARD_VERSION="Plus 2E"
              fi
            elif [ $MEMTOTAL -gt 600 ] && [ $MEMTOTAL -lt 1400 ] #1GB
            then
              if [ "$TERMINUS" != "" ]
              then
                case ${SUN8IPHY} in
                  00441400*)
                      if [ "$WIFI8189ES" != "" ]
                      then
                        BOARD_TYPE="Orange Pi"
                        BOARD_VERSION="2"
                      else
                        BOARD_TYPE="Orange Pi"
                        BOARD_VERSION="Mini 2"
                      fi
                      ;;
                esac
              elif [ "$GL830" != "" ]
              then
                BOARD_TYPE="Orange Pi"
                BOARD_VERSION="Plus"
              else
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
              fi
            elif [ $MEMTOTAL -gt 400 ] && [ $MEMTOTAL -lt 550 ] #512 MB
            then
              if [ "$WIFI8189ES" != "" ]
              then
                BOARD_TYPE="Orange Pi"
                BOARD_VERSION="Lite"
              elif [ "$WIFIAP6212" != "" ]
              then
                BOARD_TYPE="Orange Pi"
                BOARD_VERSION="Zero Plus 2"
              else # or NanoPi M1
                BOARD_TYPE="Orange Pi"
                BOARD_TYPE="One"
              fi
            elif [ $MEMTOTAL -gt 200 ] && [ $MEMTOTAL -lt 400 ] #256 MB
            then
              if [ "$WIFIAP6212" != "" ]
              then
                BOARD_TYPE="NanoPi"
                BOARD_VERSION="AIR"
              else
                BOARD_TYPE="NanoPi"
                BOARD_VERSION="NEO"
              fi
            fi
            ;;
          #sun9i (cortex-a15.cortex-a7 big.LITTLE)
          sun9i*)
            SOC_VERSION="A80"
            BOARD_TYPE="Cubietech"
            BOARD_VERSION="Cubieboard4"
            ;;
          #sun50i cortex-a53 smp
          sun50iw1*)
            SOC_VERSION="A64"
            if [ $MEMTOTAL -gt 1500 ] # 2GB
            then
              BOARD_TYPE="Pine"
              BOARD_VERSION="A64+"
            elif [ $MEMTOTAL -gt 600 ] && [ $MEMTOTAL -lt 1400 ] #1GB
            then
              if [ "$WIFI8189ES" != "" ]
              then
                BOARD_TYPE="NanoPi"
                BOARD_VERSION="A64"
              elif [ "$WIFIAP6212" != "" ]
              then
                BOARD_TYPE="Banana Pi"
                BOARD_VERSION="M64"
              else
                BOARD_TYPE="Pine"
                BOARD_VERSION="A64+"
              fi
            else
              BOARD_TYPE="Pine"
              BOARD_VERSION="A64"
            fi
            ;;
          sun50iw2*)
            SOC_VERSION="H5"
            if [ $MEMTOTAL -gt 1500 ] # 2GB
            then
              BOARD_TYPE="Orange Pi"
              BOARD_VERSION="Prime"
            elif [ $MEMTOTAL -gt 600 ] && [ $MEMTOTAL -lt 1400 ] #1GB
            then
              if [ "$WIFIAP6212" != "" ]
              then
                BOARD_TYPE="NanoPi"
                BOARD_VERSION="NEO Plus2"
              else
                BOARD_TYPE="OrangePi"
                BOARD_VERSION="PC 2"
              fi
            else # 512 MB
              if [ "$WIFI8189ES" != "" ]
              then
                BOARD_TYPE="Orange Pi"
                BOARD_VERSION="Zero Plus"
              elif [ "$WIFIAP6212" != "" ]
              then
                BOARD_TYPE="Orange Pi"
                BOARD_VERSION="Zero Plus 2"
              else
                BOARD_TYPE="NanoPi"
                BOARD_VERSION="NEO2"
              fi
            fi
            ;;
          sun50iw6*)
            SOC_VERSION="H6"
            #todo add Detection: pineh64 (128MB SPI)
            if [ $MEMTOTAL -gt 1500 ]
            then
              BOARD_TYPE="Pine"
              BOARD_VERSION="H64"
            else
              BOARD_TYPE="Orange Pi"
          		BOARD_VERSION="One Plus"
            fi
            ;;
        esac
        ;;
    # Odroid
    ODROID*)
      BOARD_TYPE="Odroid"
      #BOARD_VERSION=$(echo ${HARDWARE} | sed 's/ODROID-\?//')
      case "$HARDWARE" in
        "ODROIDX")
          BOARD_VERSION="X"
          SOC_VENDOR="SAMSUNG"
          SOC_VERSION="Exynos 4412"
          ;;
        "ODROIDX2")
          BOARD_VERSION="X2"
          SOC_VENDOR="SAMSUNG"
          SOC_VERSION="Exynos 4412"
          ;;
        "ODROIDU2")
          BOARD_VERSION="U2"
          SOC_VENDOR="SAMSUNG"
          SOC_VERSION="Exynos 4412"
          ;;
        "ODROID-U2/U3")
          BOARD_VERSION="U3"
          SOC_VENDOR="SAMSUNG"
          SOC_VERSION="Exynos 4412 Prime"
          ;;
        "ODROIDXU")
          BOARD_VERSION="XU"
          SOC_VENDOR="SAMSUNG"
          SOC_VERSION="Exynos 5410"
          ;;
        "ODROID-XU3")
          BOARD_VERSION="XU3"
          SOC_VENDOR="SAMSUNG"
          SOC_VERSION="Exynos 5422"
          ;;
        "ODROID-XU4")
          BOARD_VERSION="XU4"
          SOC_VENDOR="SAMSUNG"
          SOC_VERSION="Exynos 5422"
          ;;
        "ODROIDC")
          BOARD_VERSION="C1"
          SOC_VENDOR="AMLOGIC"
          SOC_VERSION="S805"
          ;;
        "ODROID-C2")
          BOARD_VERSION="C2"
          SOC_VENDOR="AMLOGIC"
          SOC_VERSION="S905"
          ;;
      esac
      ;;
    Rockchip*)
      SOC_VENDOR="ROCKCHIP"
      SOC_VERSION="RK3288"
      # @todo and many other with rk3288 and 2 gb ram..
      BOARD_TYPE="ASUS"
      BOARD_VERSION="Tinker Board"
      ;;
    Marvell)
      SOC_VENDOR="MARVELL"
      SOC_VERSION="A388"
      BOARD_TYPE="Marvell"
      BOARD_VERSION="Clearfog"
      ;;
    Freescale)
      SOC_VENDOR="NXP"
      SOC_VERSION="i.MX6"
        if [ $MEMTOTAL -gt 1500 ]
        then
          BOARD_TYPE="Cubox"
          BASH_VERSION="i4"
        elif [ "$HB_PCI" != "" ]
        then
          BOARD_TYPE="HummingBoard"
          BOARD_VERSION="i2eX"
        elif [ "$RTC" = "rtc0" ]
        then
          BOARD_TYPE="Cubox"
          BASH_VERSION="i2eX"
        elif [ "$CORES" = 1 ]
        then
          BOARD_TYPE="HummingBoard"
          BOARD_VERSION="i1"
        else
          BOARD_TYPE="HummingBoard"
          BOARD_VERSION="i2"
        fi
        if [ -f /proc/asound/imxvt1613audio/id ]
        then
          BOARD_TYPE="Udoo"
          if [ "$CORES" = 2 ]
          then
            BOARD_VERSION="DUAL"
          elif [ "$CORES" = 4 ]
          then
            BOARD_VERSION="QUAD"
          else
            BOARD_VERSION="NEO"
          fi
      fi
      ;;
    # Actions ATM
    gs705a)
      SOC_VENDOR="ACTIONS"
      SOC_VERSION="S500"
      if [ $MEMTOTAL == 2004 ]; then
          BOARD_TYPE="Roseapple Pi"
      else
          BOARD_TYPE="Lemaker"
          BOARD_VERSION="Guitar"
      fi
      ;;
    #Amlogic)
    esac
}

collect_informations
detect_board

if [ "$BOARD_TYPE" = "" ] && [ -f /proc/device-tree/model ]
then
  detect_by_device_tree
fi
