#!/usr/bin/python3
print("# Python Script to Back-up audionotes from a Sony USB dictaphone.")
print("# by Jeremy Barbay")

import sys
import pathlib #  In Python 3.4, pathlib is now part of the standard library.
import pymtp

mtp = pymtp.MTP()
mtp.connect()
print(mtp.get_devicename())
mtp.disconnect()




### Setup builtin values of the parameters:

possible_mount_points = [
        # "/media/",
        # "/media/jbarbay/",
        "/run/user/*/gvfs/mtp:**/Storage Media/",
        "**/Storage Media/",
        "/run/user/1003/gvfs/mtp:host=%5Busb%3A002%2C007%5D/Storage Media",
        "Unison/Boxes/MyBoxes/AudioNotesToProcess/"
]

possible_device_names = [
        "",
        "WALKMAN",
        # "WALKMANSONY",
        # "FUJITEL"
]
        
location_of_audionotes_on_dictaphone="Record/Voice"
location_of_audionotes_on_computer  = "/home/jbarbay/Unison/Boxes/MyBoxes/AudioNotesToProcess/"
movingFiles=1  # 0 for False, 1 for True.
debugLevel=0  # 0=silent, 1=print and run all system calls, 2=only print system calls.
logFile="log" 

### Find location of dictaphone
audionotes = []
for path in possible_mount_points:
        for device in possible_device_names:
                p = pathlib.Path(path+device)
                print("Searching for audionotes in "+str(p))
                audionotes += list(p.glob('**/*.wav'))

print("Audionotes found: "+str(audionotes))


