pkgname="vpnslice"
pkgver=1.0
pkgrel=1
pkgdesc="Bash scripts and other files to set up per-app split routing"
arch=("any")
license=('MIT')

# Only builds from local repo are currently supported
source=("git+file://${PWD}")
sha256sums=("SKIP")
depends=(
    "dex"
    "jq"
    "libnotify"
    "nftables"
    "plocate"
    "sudo"
)

_prefix="/usr"
_sysconfdir="/etc"

build() {
    cd "${srcdir}/vpnslice"
    make all prefix="${_prefix}" sysconfdir="${_sysconfdir}"
}

package() {
    cd "${srcdir}/vpnslice"
    make install DESTDIR="${pkgdir}" prefix="${_prefix}" sysconfdir="${_sysconfdir}"
}
