# arm-board-detect
Detecting board and hardware type of arm devices

can be include in any bash scripts

```
source ./armhwinfo.sh

echo $BOARD_TYPE $BOARD_VERSION $SOC_VENDOR $SOC_VERSION

```

use example on OrangePi One Plus

```
root@OrangePi:~# source ./test.sh 
root@OrangePi:~# declare -p | grep -E 'BOARD_|SOC_'
declare -- BOARD_TYPE="Orange Pi"
declare -- BOARD_VERSION="One Plus"
declare -- SOC_MANUFACTURE="ALLWINNER"
declare -- SOC_VERSION="H6"

```
