#!/bin/bash

tmp=`mktemp -d $WAIS/tmp/hilo.XXXXX`

trap 'rm -fr $tmp' EXIT
trap 'echo; echo ERROR $? @ $LINENO; head $tmp/srfvlohi; exit' ERR 

TARG=`pwd | sed s@code@targ@g` 
mkdir -p $TARG
rm -frv $TARG/eco.r2.xyz

for PST in `cat pst_list.hicars | grep -v '#'`
do
    
    PLAT=`echo $PST | cut -d '/' -f 2 | cut -c 1-4`
    if [ ${PLAT} == "SJB2" ]
    then
        PLAT=`echo $PLAT | cut -c 1-3`c
    elif [ $PLAT == "JKB1" ]
    then
        PLAT=`echo $PLAT | cut -c 1-3`b
    else
        PLAT=`echo $PLAT | cut -c 1-3`a
    fi

    if [ ! -s $WAIS/targ/norm/$PST/SPK_${PLAT}/syn_ztim ]
    then
           continue
    fi 
    if [ `ztim2posix < $WAIS/targ/norm/$PST/SPK_${PLAT}/syn_ztim | head -1 | awk '{printf("%d", $1)}'` -lt 0 ]
    then
        echo "$PST: invalid time"
        continue
    fi
    printf "$PST: gathering..."
    paste $WAIS/targ/norm/$PST/SPK_${PLAT}/{syn_ztim,maxpos_tim} \
          $WAIS/targ/norm/$PST/SPK_${PLAT}/maxval \
          $WAIS/targ/norm/$PST/BP1_${PLAT}/maxval \
          $WAIS/targ/norm/$PST/BP2_${PLAT}/{maxval,maxpos_tim} \
          | grep -vi nan \
          | ztim2posix \
          | awk '{print $1, $3,$4,$5,2*(($2*1e6*167)^-2), 2*(($2*1e6*167)+((($6-$2)*1e6)*87))^-2}' \
          | gmtmath STDIN -C4-5 LOG10 10 MUL = \
          | awk '$2 > -20' \
          | awk '{if($3>-60) print $1, $3-$2-($6-$5); else print $1, $4-$2-($6-$5)}' \
          | posix2ztim \
          > $tmp/srfvlohi

          zvert < $tmp/srfvlohi > $tmp/srfvlohi.ztim
    
    GPS=$WAIS/targ/treg/`rad2elsa $PST`/GPS_`echo $PLAT | cut -c 1-3`0

    if [ ! -s $GPS/ztim_xyz.bin ]
    then
        echo
        echo $PST: no GPS at $GPS/ztim_xyz.bin
        continue
    fi

        echo geolocating
    echo "> $PST" >> $TARG/eco.r2.xyz
    
    zlinear -2$tmp/srfvlohi.ztim < $GPS/ztim_xyz.bin \
           | zmerge - $tmp/srfvlohi.ztim \
           | zvert \
           | grep -v nan \
           | awk '{print $4, $5, $7}' \
           >> $TARG/eco.r2.xyz
done
