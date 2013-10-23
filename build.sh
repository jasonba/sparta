#!/bin/bash

printf "Building ... "
SPARTA_TARBALL=/var/tmp/sparta.tar
tar cvf $SPARTA_TARBALL README installer.sh payload
gzip $SPARTA_TARBALL
cp ${SPARTA_TARBALL}.gz /volumes/alices/scripts

printf "done\n"
echo "tarball is here: ${SPARTA_TARBALL}.gz"

exit 0

