# labwc-spin.sh (/etc/profile.d): the desktop of the labwc spin at a login on a text console. On tty1
# the desktop starts (for a user; for root only in the live system, on its main console); "Log out"
# ends the login, and the automatic login starts the desktop again. Elsewhere a hint. Not on tty1 for
# a user: ~/.config/labwc-spin/no-autostart. labwc-spin --help: the rest.
case $- in
*i*)
	case $(tty 2>/dev/null) in
	/dev/tty[0-9]*)
		if [ -z "${WAYLAND_DISPLAY:-}" ] && command -v labwc-spin >/dev/null 2>&1; then
			labwc-spin login
			[ $? -ne 100 ] || exit 0
		fi
		;;
	esac
	;;
esac
