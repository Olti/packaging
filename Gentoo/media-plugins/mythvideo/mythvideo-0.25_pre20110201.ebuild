# Copyright 1999-2008 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/media-plugins/mythvideo/mythvideo-0.21_p17595.ebuild,v 1.1 2008/08/01 16:35:22 cardoe Exp $

EAPI="2"

MYTHTV_VERSION="v0.25pre-1082-g3716894"
MYTHTV_BRANCH="master"
MYTHTV_REV="3716894d56190f401c4956863c3140427b603e87"
MYTHTV_SREV="3716894"

inherit mythtv-plugins eutils

DESCRIPTION="Video player module for MythTV."
IUSE=""
KEYWORDS="~amd64 ~x86 ~ppc"

RDEPEND="media-tv/mythtv[python]
        sys-apps/eject"
DEPEND=""

src_prepare() {
	if use experimental
	then
		true;
	fi
}

src_install() {
	for file in `find ${S} -type f -name *.py`
	do
		chmod +x $file
    done

	mythtv-plugins_src_install
}

pkg_postinst() {
	elog "MythVideo can use any media player to playback files, since"
	elog "it's a setting in the setup menu."
	elog
	elog "MythTV also has an 'Internal' player you can use, which will"
	elog "be the default for new installs.  If you want to use it,"
	elog "set the player to 'Internal' (note spelling & caps)."
	elog
	elog "Otherwise, you can install mplayer, xine or any other video"
	elog "player and use that instead by configuring the player to use."
}
