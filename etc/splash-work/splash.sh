#!/bin/sh
#
# This is made in part as a way to overcome (until it is fixed upstream) multiple blanking points at the Torizon's boot flow, caused from
# Plymouth running before the IMX8 DRM is fully initialized (problem running Plymouth from ramdisk), and from Plymouth blanking the screen since it does 
# not respond to   quit --retain-splash
# Since by default DRMFB and FRAMEBUFFER_CONSOLE are enabled, it leads to an opportunity of showing a splash screen using other measures, and a simple
# Demonstration would simply write something to it. On this device it is always /dev/fb0, but if that changes on other similar devices, just change it.
#
# This is also why the Linux kernel LOGO would not display
#
# Since busybox's fbsplash can display things and works with DRMFB, and is very lightweight, we can use it as well. A nice advantage is that the contents of the FB
# Are kept after a DRM master quits and stops locking the DRI, so you could see the displayed graphics also after that.
#
# Explanation for the logic here (or: why we loop or wait)
# Theoretically, there could be a specific dev-fb0.device rule, and then we would wait for it ( After=dev-fb0.device, Requires=dev-fb0.device ) in the systemd unit file.
# In practice, there isn't such, and since at the time of writing the framebuffer takes time to allocate (which is why plymouth from ramdisk doesn't work at the first place)
# And so to display anything on the frame buffer device as soon as possible (no matter from where) we would:
# - Have to wait until the framebuffer is ready
# - And then wait until the display drivers are actually ready - that is the essence of the iMX8 bug that the Verdin imx8MP board came with in the first place in Torizon.
#
# Important: To display earlier in the process, a good place to put these files would be in /etc/ if you play with a live version, and not build the image, as you would
# otherwise need to wait for the proper directory (e.g. /home/torizon) to be mounted.


print() {
	echo -e $@ > /dev/console
}

greet() {
	print "$0: Welcome. Kernel is up since $(uptime -s)"
}

wait_for_fb() {
	while ! ls -l /dev/fb0 &> /dev/null ; do
		print "\x1b[33m$(uptime) fb not ready\x1b[0m"
		sleep 0.1
	done
	echo "$(uptime) FB is ready" > /dev/console
}

wait_for_drm_modeset() {
	# change card1-LVD-1 to your relevant device if you wish to do so
	while ! cat /sys/class/drm/card1-LVDS-1/modes &>/dev/null ; do
		print "\x1b[33m$(uptime) modeset not ready\x1b[0m"
  		sleep 0.1
	done

	print "\x1b[32m$(uptime) modeset to $(cat /sys/class/drm/card1-LVDS-1/modes)\x1b[0m"
}

splash_image() {
	WORKING_DIR=/etc/splash-work
	BB=$WORKING_DIR/busybox_arm64
	IMG=$WORKING_DIR/splash.ppm
	print "$(uptime) WILL DISPLAY SPLASH"
	$BB fbsplash -s $IMG
}


# Just splashing will not work until some things are ready. Waiting for fb can be done for illustration - the important thing is waiting for drm
#$BB fbsplash -s $IMG
# You are not expected to see the graphics until the a particular message is ready. We could search sysfs for the event, but it is easier to just look for it...
# sudo  cat /proc/kmsg | grep "imx-drm display-subsystem: \[drm\] fb0: imx-drmdrmfb frame buffer device"
#
# If the boot is quiet, you will see these errors before the system can work:
# [    6.582385] imx8mp-ldb ldb-display-controller: Failed to create device link (0x180) with phy-lvds
# [    6.843381] imx-bus-devfreq 32700000.interconnect: failed to fetch clk: -2
# [    6.904623] imx_sec_dsim_drv 32e60000.mipi_dsi: [drm] *ERROR* modalias failure on /soc@0/bus@32c00000/mipi_dsi@32e60000/port@1

greet
wait_for_fb
wait_for_drm_modeset
splash_image


exit 0
