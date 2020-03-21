#!/bin/sh


if [ -f 'project4.zip' ]; then
    echo "Deleting zip file"
    rm project4.zip
fi

zip -r -v project4.zip ./ \
    -x project4.zip \
    -x 'verilator/.idea/*' \
    -x 'verilator/trace.vcd' \
    -x 'verilator/obj_dir/*' \
    -x 'verilator/cmake-build-*' \
    -x '.idea/*' \
    -x '.git/*'




