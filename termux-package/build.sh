TERMUX_PKG_HOMEPAGE=https://github.com/YOURNAME/build-ladder
TERMUX_PKG_DESCRIPTION="Autonomous AI-powered Android APK builder for Termux"
TERMUX_PKG_LICENSE="MIT"
TERMUX_PKG_MAINTAINER="yuptm"
TERMUX_PKG_VERSION=2.2.0
TERMUX_PKG_SRCURL=https://github.com/YOURNAME/build-ladder/archive/main.tar.gz
TERMUX_PKG_DEPENDS="curl,git,jq,openjdk-17,android-tools"

termux_step_make_install() {
  mkdir -p $PREFIX/bin
  mkdir -p $HOME/.build-ladder/bin

  cp -r $TERMUX_PKG_SRCDIR/core/* $HOME/.build-ladder/bin/
  cp $TERMUX_PKG_SRCDIR/bootstrap/bootstrap.sh $HOME/.build-ladder/bin/

  chmod +x $HOME/.build-ladder/bin/*.sh

  cat > $PREFIX/bin/build-ladder <<'EOF'
#!/usr/bin/env bash
exec "$HOME/.build-ladder/bin/build-ladder.sh" "$@"
EOF

  chmod +x $PREFIX/bin/build-ladder
}
