#!/bin/bash

printf "Building ... \n"
VER=`grep '^SPARTA_VER' payload/sparta.config | awk '{print $1}' | awk -F\" '{print $2}'`
SPARTA_TARBALL=/var/tmp/sparta-${VER}.tar

printf "Creating staging area\n"
STAGING=/tmp/staging
if [ ! -d $STAGING ]; then
    mkdir -p $STAGING/sparta
fi

printf "Copying files to staging area : "
find README installer.sh auto-installer.sh payload | cpio -pdum $STAGING/sparta/

printf "Creating tarball\n"
(cd $STAGING ; tar cvf $SPARTA_TARBALL sparta)
gzip -f $SPARTA_TARBALL
cp ${SPARTA_TARBALL}.gz /volumes/alices/scripts
cp ${SPARTA_TARBALL}.gz .

digest -a md5 ${SPARTA_TARBALL}.gz > sparta.hash

printf "Cleaing up staging area\n"
if [ -d $STAGING ]; then
    echo rm -fr $STAGING
fi
printf "done\n"
echo "tarball is here: ${SPARTA_TARBALL}.gz"

exit 0

