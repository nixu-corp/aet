# Android Emulation Toolkit (AET) #

## Table of contents ##
---
* [Description](#description)
* [Prerequisites](#prerequisites)
* [Getting Started](#getting-started)
* [Documentation](#documentation)
* [Reporting issues](#reporting-issues)
* [Contact information](#contact-information)


## Description ##
---
The purpose of this software is to make the testing of Android applications in
a virtual environment easier, by providing a script that hides the signs of
the emulator. It also includes a tool setup part that should be used when first
using the software. It installs all the necessary tools and setups a basic
unmodified environment.


## Prerequisites ##
---
* A [Bash][1] shell
* Install Java; [Oracle's Java][2] or [OpenJDK][3]
* Install [XMLStarlet][4]

Are you not on Linux? Or are you having problems with the scripts? Check out the
guide for [manual setup][5]

## Getting Started ##
---
#### Clone the project: ####
```
git clone git@github.com:nixu-corp/aet.git
cd aet/
```

#### Set executable bit for all scripts: ####
```
sudo chmod -R +x *.sh
```
If you do not have sudo permission, just add `bash` before each command running a shell script.

#### Run setup script (See [Setting up environment][6]): ####
```
bin/setup-env.sh -e
```

#### After that you can fire up the emulator (See [Running emulator][8]): ####
```
bin/run-env.sh ~/android-sdk/ android-17-default
```


## Documentation ##
---
The [Wiki][10] contains all the information needed.

You can also check out the [Getting Started](#getting-started) section.


## Reporting issues ##
---
Use the [issue tracker][11]. Please check that the issue has not already
been submitted!


## Special thanks ##
---
Kimmo Linnavuo, for assisting in researching emulation detection

Timo Järventausta, for his useful comments about user-friendliness

Aaro Lehikoinen, for helping with testing and code review


## Contact information ##
---
Original developer

Name:   Daniel Riissanen

Email:  daniel.riissanen[ät]nixu.com

--

Current developer:

Name:   Daniel Riissanen

Email:  daniel.riissanen[ät]nixu.com

<!--- Links -->
[1]: https://en.wikipedia.org/wiki/Bash_%28Unix_shell%29
[2]: http://java.com/en/download/
[3]: http://openjdk.java.net/install/
[4]: http://xmlstar.sourceforge.net/download.php
[5]: https://github.com/nixu-corp/aet/wiki/Manual-setup
[6]: https://github.com/nixu-corp/aet/wiki/Setting-up-environment
[8]: https://github.com/nixu-corp/aet/wiki/Running-the-emulator
[9]: https://github.com/nixu-corp/aet/wiki/Examples
[10]: https://github.com/nixu-corp/aet/wiki
[11]: https://github.com/nixu-corp/aet/issues
