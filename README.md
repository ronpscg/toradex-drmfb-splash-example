## What and Why
This is made in part as a way to overcome (until it is fixed upstream) multiple blanking points at the Torizon's boot flow, caused from
Plymouth running before the IMX8 DRM is fully initialized (problem running Plymouth from ramdisk), and from Plymouth blanking the screen since it does 
not respond to  `plymouth quit --retain-splash`
Since by default `DRMFB` and `FRAMEBUFFER_CONSOLE` are enabled, it leads to an opportunity of showing a splash screen using other measures, and a simple
Demonstration would simply write something to it. On this device it is always /dev/fb0, but if that changes on other similar devices, just change it.

This is also why the Linux kernel LOGO would not display

Since busybox's fbsplash can display things and works with DRMFB, and is very lightweight, we can use it as well. A nice advantage is that the contents of the FB
Are kept after a DRM master quits and stops locking the DRI, so you could see the displayed graphics also after that.

## Explanation for the logic here (or: why we loop or wait)
Theoretically, there could be a specific dev-fb0.device rule, and then we would wait for it ( After=dev-fb0.device, Requires=dev-fb0.device ) in the systemd unit file.
In practice, there isn't such, and since at the time of writing the framebuffer takes time to allocate (which is why plymouth from ramdisk doesn't work at the first place)
And so to display anything on the frame buffer device as soon as possible (no matter from where) we would:
- Have to wait until the framebuffer is ready
- And then wait until the display drivers are actually ready - that is the essence of the iMX8 bug that the Verdin imx8MP board came with in the first place in Torizon.

Important: To display earlier in the process, a good place to put these files would be in /etc/ if you play with a live version, and not build the image, as you would
otherwise need to wait for the proper directory (e.g. /home/torizon) to be mounted.


### Some explanations about the wait logic and the IMX bug
Just splashing will not work until some things are ready. Waiting for fb can be done for illustration - the important thing is waiting for drm.

So if you do `fbsplash -s $IMG`  prematurely, you are not expected to see the graphics until the a particular message is ready. 
You can search for this "moment" in 
```# cat /proc/kmsg | grep "imx-drm display-subsystem: \[drm\] fb0: imx-drmdrmfb frame buffer device"```

It will appear shortly after those errors that I suppose will be fixed by Toradex or NXP at some point:
```
# If the boot is quiet, you will see these errors before the system can work:
[    6.582385] imx8mp-ldb ldb-display-controller: Failed to create device link (0x180) with phy-lvds
[    6.843381] imx-bus-devfreq 32700000.interconnect: failed to fetch clk: -2
[    6.904623] imx_sec_dsim_drv 32e60000.mipi_dsi: [drm] *ERROR* modalias failure on /soc@0/bus@32c00000/mipi_dsi@32e60000/port@1
```



## What you need to put in the /etc/splash-work directory (which was selected just for Torizon really, you could put in other places that are available or set the systemd dependencies (or of course you can avoid using systemd)

- splash.ppm - a ppm file created in the resolution you require (we just splash over all the screen the image).
- busybox_arm64 - a statically linked busybox that has fbsplash in it. I think I have it somewhere around ronpscg in public, and I definitely show how to create it in PscgBuildOS projects

You can enable the service on your target with ```systemctl enable ron-splash```

## Creating splash.ppm
You need ImageMagick. Then, adjust the following example to your needs.
Example:
- Original image is ../../assets/images/1280x800/pscg__1280x800__lighter-green.png
- Required resolution is 1280x800 

In this case there is **no** need for the -resize statement, but you may want to resize another image so the full example is presented below, and you would want
to run the (your) equivalent of:
```
RESOLUTION=1280x800
SRC=../../assets/images/1280x800/pscg__1280x800__lighter-green.png
SRC_SCALED=scaled-$(basename $SRC)
DST_PNG=$SRC_SCALED
DST_PPM=splash.ppm
convert -resize $RESOLUTION\! $SRC $SRC_SCALED
convert $DST_PNG $DST_PPM
```
