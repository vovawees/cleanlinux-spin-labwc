# labwc-spin.sh in /etc/profile.d: how to start the desktop of the labwc spin, printed at login on a text console
case $(tty 2>/dev/null) in
/dev/tty[0-9]*)
	if [ -z "${WAYLAND_DISPLAY:-}" ] && [ -t 1 ]; then
		if id -nG 2>/dev/null | tr ' ' '\n' | grep -qx seat; then
			echo "labwc: type 'labwc' to start the desktop (Super+Return: terminal, right click: menu)"
		else
			echo "labwc: $(id -un) is not in the group 'seat'; as root: usermod -aG seat $(id -un), then log in again"
		fi
	fi
	;;
esac
