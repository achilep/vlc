# Qt

QT_VERSION := 5.11.0
QT_URL := https://download.qt.io/official_releases/qt/5.11/$(QT_VERSION)/submodules/qtbase-everywhere-src-$(QT_VERSION).tar.xz

ifdef HAVE_MACOSX
#PKGS += qt
endif
ifdef HAVE_WIN32
PKGS += qt
endif

ifeq ($(call need_pkg,"Qt5Core Qt5Gui Qt5Widgets"),)
PKGS_FOUND += qt
endif

$(TARBALLS)/qt-$(QT_VERSION).tar.xz:
	$(call download,$(QT_URL))

.sum-qt: qt-$(QT_VERSION).tar.xz

qt: qt-$(QT_VERSION).tar.xz .sum-qt
	$(UNPACK)
	mv qtbase-everywhere-src-$(QT_VERSION) qt-$(QT_VERSION)
	$(APPLY) $(SRC)/qt/0001-Windows-QPA-prefer-lower-value-when-rounding-fractio.patch
	$(APPLY) $(SRC)/qt/0002-Windows-QPA-Disable-systray-notification-sounds.patch
	$(MOVE)

ifdef HAVE_MACOSX
QT_PLATFORM := -platform darwin-g++
endif
ifdef HAVE_WIN32
ifdef HAVE_CLANG
QT_SPEC := win32-clang-g++
else
QT_SPEC := win32-g++
endif
ifdef HAVE_CROSS_COMPILE
QT_PLATFORM := -xplatform $(QT_SPEC) -device-option CROSS_COMPILE=$(HOST)-
else
QT_PLATFORM := -platform $(QT_SPEC)
endif
endif

QT_CONFIG := -static -opensource -confirm-license -no-pkg-config \
	-no-sql-sqlite -no-gif -qt-libjpeg -no-openssl -no-opengl -no-dbus \
	-no-sql-odbc -no-pch \
	-no-compile-examples -nomake examples -qt-zlib

QT_CONFIG += -release

.qt: qt
	cd $< && ./configure $(QT_PLATFORM) $(QT_CONFIG) -prefix $(PREFIX)
	# Make && Install libraries
	cd $< && $(MAKE)
	cd $< && $(MAKE) -C src sub-corelib-install_subtargets sub-gui-install_subtargets sub-widgets-install_subtargets sub-platformsupport-install_subtargets sub-zlib-install_subtargets sub-bootstrap-install_subtargets
	# Install tools
	cd $< && $(MAKE) -C src sub-moc-install_subtargets sub-rcc-install_subtargets sub-uic-install_subtargets
	# Install plugins
	cd $< && $(MAKE) -C src/plugins sub-platforms-install_subtargets
	mv $(PREFIX)/plugins/platforms/libqwindows.a $(PREFIX)/lib/ && rm -rf $(PREFIX)/plugins
	# Move includes to match what VLC expects
	mkdir -p $(PREFIX)/include/QtGui/qpa
	cp $(PREFIX)/include/QtGui/$(QT_VERSION)/QtGui/qpa/qplatformnativeinterface.h $(PREFIX)/include/QtGui/qpa
	# Clean Qt mess
	rm -rf $(PREFIX)/lib/libQt5Bootstrap* $</lib/libQt5Bootstrap*
	# Fix .pc files to remove debug version (d)
	cd $(PREFIX)/lib/pkgconfig; for i in Qt5Core.pc Qt5Gui.pc Qt5Widgets.pc; do sed -i.orig -e 's/d\.a/.a/g' -e 's/d $$/ /' $$i; done
	# Fix Qt5Gui.pc file to include qwindows (QWindowsIntegrationPlugin) and platform support libraries
	cd $(PREFIX)/lib/pkgconfig; sed -i.orig -e 's/ -lQt5Gui/ -lqwindows -lQt5ThemeSupport -lQt5FontDatabaseSupport -lQt5EventDispatcherSupport -lQt5WindowsUIAutomationSupport -lqtfreetype -lQt5Gui/g' Qt5Gui.pc
ifdef HAVE_CROSS_COMPILE
	# Building Qt build tools for Xcompilation
	cd $</include/QtCore; ln -sf $(QT_VERSION)/QtCore/private
	cd $<; $(MAKE) -C qmake
	cd $<; $(MAKE) sub-qmake-qmake-aux-pro-install_subtargets install_mkspecs
	cd $</src/tools; \
	for i in bootstrap uic rcc moc; \
		do (cd $$i; echo $$i && ../../../bin/qmake -spec $(QT_SPEC) QMAKE_RC=$(HOST)-windres && $(MAKE) clean && $(MAKE) CC=$(HOST)-gcc CXX=$(HOST)-g++ LINKER=$(HOST)-g++ LIB="$(HOST)-ar -rc" && $(MAKE) install); \
	done
endif
	touch $@
