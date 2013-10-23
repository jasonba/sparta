#!/bin/bash

printf "Building ... "
SPARTA_TARBALL=/var/tmp/sparta.tar
tar cvf $SPARTA_TARBALL README installer.sh auto-installer.sh payload
gzip -f $SPARTA_TARBALL
cp ${SPARTA_TARBALL}.gz /volumes/alices/scripts
cp ${SPARTA_TARBALL}.gz .

digest -a md5 ${SPARTA_TARBALL}.gz > sparta.hash

printf "done\n"
echo "tarball is here: ${SPARTA_TARBALL}.gz"

exit 0

