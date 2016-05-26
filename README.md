# Documentation for emulation detection resistant emulation environment setup

## Table of contents
* [Purpose](#purpose)
* [Prerequisites](#prerequisites)
* [How to use](#how-to-use)
    - Basic
    - Advanced
* [Script walkthrough](#script-walkthrough)

---

## Purpose
The purpose of this software is to make the testing of Android applications in a virtual environment easier, by providing a script that hides the signs of the emulator.

## Prerequisites
* Download [Android Studio][1]
* Run Android Studio and set up the SDK location
* Download a SDK for an API using the [Android SDK Manager][2]

## How to use
#### Basic
The script is very easy to use. All you need to do is to find the directory where your system image is stored.

Your system image folder:
  
```
<SDK Root>/system-images/<API>/<Manufacturer>/<Architecture>/
```
  
_SDK Root_:      The directory where you installed the Android SDK when launching Android Studio for the first time  
_API_:           Varies from 1 to 23 depending on what Android version you are developing for  
_Manufacturer_:  'default' or 'google\_apis'  
_Architecture_:  armeabi-v7a or x86 or x86\_64  

After this you need to run the script:
  
```
./setup-env.sh <system image folder>
```
  
#### Advanced
Coming soon!

## Script walkthrough
**Note**: ramdisk.img is actually a compressed gzip file and not a disc image!
1. Makes a temporary directory for ramdisk.img
2. Runs: 'gzip -dc &lt;ramdisk.img&gt; | cpio -i' and decompresses it into the temporary directory
3. Makes changes into the files in the temporary ramdisk directory
4. Runs: './mkbootfs &lt;temporary directory&gt; | gzip &gt; &lt;ramdisk.img&gt; to compress the temporary folder back to a compressed file
5. Mounts system.img
6. Makes changes to the files in the mounted system.img
7. Unmounts system.img

<!--- Links -->
[1]: https://developer.android.com/studio/index.html#downloads
[2]: https://developer.android.com/studio/intro/update.html#sdk-manager