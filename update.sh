#!/bin/sh

set -e

# Variables
mirror="https://www.mirrorservice.org/sites/libreboot.org/release/testing/"
machine="x200"
log_file="latest_directory.log"

# Create and enter working directory
mkdir -p ~/libreboot
cd ~/libreboot

# Ensure log file exists
touch $log_file

# Get latest directory from the mirror
html=$(curl -s $mirror)
latest_directory=$(echo "$html" | grep -oP '(?<=href=")[0-9]+(?=/")' | sort -r | head -n 1)

# Get the last logged directory
last_logged_directory=$(tail -n 1 $log_file || echo "")

# Check if the latest directory is newer than the last logged one
if [[ -z "$last_logged_directory" || $latest_directory -gt $last_logged_directory ]]; then
    echo "New directory found: $latest_directory"
else
    echo "No new directory found. Exiting script."
    exit 1
fi

# Get chip size
chip_size_kb=$(sudo flashrom -p internal | grep "Found Winbond flash chip" | awk '{print $6}')
chip_size_mb=$(($chip_size_kb / 1024))

# Backup current ROM
sudo flashrom -p internal:laptop=force_I_want_a_brick,boardmismatch=force -r dump.bin

rom_url="${mirror}${latest_directory}/roms/libreboot-${latest_directory}_${machine}_${chip_size_mb}mb.tar.xz"
sha_url="${rom_url}.sha512"

# Download the ROM and its SHA512 checksum
curl -O $rom_url
curl -O $sha_url

# Check the SHA512 checksum of the downloaded ROM
sha512sum -c libreboot-${latest_directory}_${machine}_${chip_size_mb}mb.tar.xz.sha512 || exit 1

# Extract the downloaded ROM
tar -xvf libreboot-${latest_directory}_${machine}_${chip_size_mb}mb.tar.xz

# Move to the appropriate directory
cd bin/${machine}_${chip_size_mb}mb/

# Rename the ROM and flash it
mv grub_${machine}_${chip_size_mb}mb_libgfxinit_corebootfb_usqwerty_noblobs_nomicrocode.rom libreboot.rom
sudo flashrom -p internal:laptop=force_I_want_a_brick,boardmismatch=force -w libreboot.rom

# Move back to the parent directory
cd ~/libreboot

# Remove the unnecessary directory
rm -rf bin

# Log the latest directory
echo $latest_directory >> $log_file
echo "Done."