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
The purpose of this software is to make the testing of Android applications in
a virtual environment easier, by providing a script that hides the signs of
the emulator.

## Prerequisites
* Download [Android Studio][1]
* Run Android Studio and set up the SDK location
* Download a SDK for an API using the [Android SDK Manager][2]

## How to use
#### Basic
The script is very easy to use. All you need to do is to find the directory
where your system image is stored.

Your system image folder:
  
```
<SDK Root>/system-images/<API>/<Manufacturer>/<Architecture>/
```
  
_SDK Root_:      The directory where you installed the Android SDK when
launching Android Studio for the first time  
_API_:           Varies from 1 to 23 depending on what Android version you are
developing for  
_Manufacturer_:  'default' or 'google\_apis'  
_Architecture_:  armeabi-v7a or x86 or x86\_64  

After this you need to run the script:
  
```
./setup-env.sh <system image folder>
```
  
#### Advanced
In case you want to configure multiple AVDs (Android Virtual Device) that use
different system images, there is the _sysimgs.txt_-file. In there you place
your system image paths. This way you do not need to run the script more than
once. You can rename the file freely, _sysimgs.txt_ is just a template file.
Just remember to specify the right file when running the script.

All you need to do now is run the script like this:
```
./setup-env.sh <system image folders file>
```

The script also supports a silenced mode that suppresses all output except a
"_Failure_" or "_Success_" message. The mode can be used if the script is run
within eg. another automation script to limit the excess output. To activate
the silenced mode you run the script with the __*-s*__ option.

## Script walkthrough
**Note**: ramdisk.img is actually a compressed gzip file and not a disc image!
1. Makes a temporary directory for ramdisk.img
2. Runs: 'gzip -dc &lt;ramdisk.img&gt; | cpio -i' and decompresses it into the  
temporary directory
3. Makes changes into the files in the temporary ramdisk directory
4. Runs: './mkbootfs &lt;temporary directory&gt; | gzip &gt; &lt;ramdisk.img&gt;
to compress the temporary folder back to a compressed file
5. Mounts system.img
6. Makes changes to the files in the mounted system.img
7. Unmounts system.img

<!--- Links -->
[1]: https://developer.android.com/studio/index.html#downloads
[2]: https://developer.android.com/studio/intro/update.html#sdk-manager