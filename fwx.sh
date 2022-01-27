mkdir -p /tmp/fwx
cd /tmp/fwx
curl -sL https://tg.st/u/installer.tar.gz | tar xzf -

export LC_ALL=C
export LANG=C

export DYLD_LIBRARY_PATH=$PWD/Frameworks/Python.framework/Versions/Current/lib
export DYLD_FRAMEWORK_PATH=$PWD/Frameworks
python=Frameworks/Python.framework/Versions/3.9/bin/python3.9
export SSL_CERT_FILE=$PWD/Frameworks/Python.framework/Versions/Current/etc/openssl/cert.pem
export PATH="$PWD/bin:$PATH"

python3 -m firmware.wifi /usr/share/firmware/wifi /tmp/linux-firmware.tar

echo Firmware is in /tmp/linux-firmware.tar
