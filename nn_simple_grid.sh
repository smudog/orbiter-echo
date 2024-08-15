#!/bin/bash

tmp=`mktemp -d $WAIS/tmp/grd.XXXXX`
TARG=`pwd | sed s@code@targ@g`
mkdir -p $TARG

trap 'rm -frv $tmp' EXIT

rm -f $TARG/tmp.grd  $TARG/mask.grd $TARG/*.xyz.*

makecpt -Cmagma -T-120/0/20 -Z > eco.cpt

for data in `ls $TARG/*.xyz`
  do
    echo Processing $data

    gmtselect $data -R-3000e3/3000e3/-3000e3/3000e3 > $tmp/data.fil
    region=`gmtinfo -I20000 $tmp/data.fil` 
    params="$region -I5000" 
    blockparams="$region -I5000"

    grdmath $params 0 = $TARG/template.grd
    grd2xyz $TARG/template.grd | awk '{print $1, $2}' > $TARG/template.xy

    awk '{print $1, $2, 10^($3/10)}' < $data \
            | blockmean $blockparams -V \
            | gmtmath STDIN -C2 LOG10 10 MUL = \
            > ${data}.fil

    cat ${data}.fil \
        | surface $params -T0.35  -V -G${data}.raw.grd

    grdfilter ${data}.raw.grd -D0 -Fg7e3 -G${data}.grd -V
    #make a mask for figures
    grdmask  ${data}.fil $params -S8e3 -NNaN/NaN/1 -V -G$TARG/mask.grd
    grdmath $TARG/mask.grd ${data}.grd MUL  = ${data}_val.grd
    grdgradient ${data}_val.grd -E315/30 -G${data}_val.gradient.grd

    grdimage ${data}_val.grd -JX15/0 -Ceco.cpt -K > ${data}.ps
    psscale -DJMR -Ceco.cpt -JX -R${data}_val.grd -O >> ${data}.ps
    psconvert ${data}.ps -A -Tf -P 
    rm -frv ${data}.ps
done


