################################################################################
#
# Chromium
#
################################################################################

CHROMIUM_VERSION = 86.0.4240.198
CHROMIUM_SITE = https://commondatastorage.googleapis.com/chromium-browser-official
CHROMIUM_SOURCE = chromium-$(CHROMIUM_VERSION).tar.xz
CHROMIUM_LICENSE = BSD-Style
CHROMIUM_LICENSE_FILES = LICENSE
CHROMIUM_DEPENDENCIES = atk at-spi2-core at-spi2-atk alsa-lib cairo ffmpeg \
			flac fontconfig freetype harfbuzz host-clang host-ninja host-nodejs \
			host-pkgconf host-python icu jpeg libdrm libglib2 libkrb5 libnss libpng libxml2 libxslt \
			minizip opus ncurses pango snappy webp xlib_libXcomposite xlib_libXScrnSaver \
			xlib_libXcursor xlib_libXrandr zlib compiler-rt libvpx libgtk3

CHROMIUM_TOOLCHAIN_CONFIG_PATH = $(shell pwd)/package/chromium/toolchain

CHROMIUM_OPTS = \
	host_toolchain="$(CHROMIUM_TOOLCHAIN_CONFIG_PATH):host" \
	custom_toolchain="$(CHROMIUM_TOOLCHAIN_CONFIG_PATH):target" \
        v8_snapshot_toolchain="$(CHROMIUM_TOOLCHAIN_CONFIG_PATH):host" \
	target_cpu=$(BR2_PACKAGE_CHROMIUM_TARGET_ARCH) \
	is_clang=true \
	clang_use_chrome_plugins=false \
	treat_warnings_as_errors=false \
	use_gnome_keyring=false \
	linux_use_bundled_binutils=false \
	use_sysroot=false \
	enable_nacl=false \
	enable_swiftshader=false \
	enable_linux_installer=false \
	is_official_build=true \
	use_custom_libcxx=false \
	clang_use_default_sample_profile=false \
	is_cfi=false
	pkg_config=\"PKG_CONFIG_PATH="$(STAGING_DIR)/usr/lib/pkgconfig:$(STAGING_DIR)/usr/share/pkgconfig" $(HOST_DIR)/usr/bin/pkgconf\" \
	use_system_libjpeg=true \
	use_system_libpng=true \
	use_system_harfbuzz=true \
	enable_remoting=false \
        use_kerberos=false \
	use_system_freetype=true \
	enable_js_type_check=false \
	host_pkg_config="pkg-config-native" \
	fieldtrial_testing_like_official_build=true \
	is_debug=false \
        google_api_key="invalid-api-key" \
        google_default_client_id="invalid-client-id" \
        google_default_client_secret="invalid-client-secret" \
        use_allocator="none" \
        use_allocator_shim=false

CHROMIUM_SYSTEM_LIBS = \
	ffmpeg \
	flac \
	fontconfig \
	freetype \
	harfbuzz-ng \
	libdrm \
	libjpeg \
	libpng \
	libvpx \
	libwebp \
	libxml \
	libxslt \
	openh264 \
	opus \
	re2 \
	snappy \
	zlib 

	
CHROMIUM_OPTS += use_lld=false
CHROMIUM_OPTS += use_gold=false

ifeq ($(BR2_i386)$(BR2_x86_64),y)
CHROMIUM_SYSTEM_LIBS += yasm
CHROMIUM_DEPENDENCIES += host-yasm
endif

# V8 snapshots require compiling V8 with the same word size as the target
# architecture, which means the host needs to have that toolchain available.
#
# Additionally, v8_context_snapshot_generator requires host-ffmpeg, which
# doesn't currently build.
CHROMIUM_OPTS += v8_use_snapshot=false

ifeq ($(BR2_CCACHE),y)
CHROMIUM_OPTS += cc_wrapper=\"ccache\"
endif


ifeq ($(BR2_PACKAGE_CUPS),y)
CHROMIUM_DEPENDENCIES += cups
CHROMIUM_OPTS += use_cups=true
else
CHROMIUM_OPTS += use_cups=false
endif

ifeq ($(BR2_PACKAGE_CHROMIUM_PROPRIETARY_CODECS),y)
CHROMIUM_OPTS += proprietary_codecs=true ffmpeg_branding=\"Chrome\"
endif

ifeq ($(BR2_PACKAGE_PCIUTILS),y)
CHROMIUM_DEPENDENCIES += pciutils
CHROMIUM_OPTS += use_libpci=true
else
CHROMIUM_OPTS += use_libpci=false
endif

ifeq ($(BR2_PACKAGE_PULSEAUDIO),y)
CHROMIUM_DEPENDENCIES += pulseaudio
CHROMIUM_OPTS += use_pulseaudio=true
else
CHROMIUM_OPTS += use_pulseaudio=false
endif


define CHROMIUM_CONFIGURE_CMDS
	( cd $(@D); \
		sed -i 's/OFFICIAL_BUILD/GOOGLE_CHROME_BUILD/' \
			tools/generate_shim_headers/generate_shim_headers.py \
	)
	( cd $(@D); \
		$(TARGET_MAKE_ENV) \
		build/linux/unbundle/replace_gn_files.py \
			--system-libraries $(CHROMIUM_SYSTEM_LIBS) \
	)
	mkdir -p $(@D)/bin
	ln -sf $(HOST_DIR)/usr/bin/python2 $(@D)/bin/python
	
	$(HOST_DIR)/bin/python2 $(@D)/tools/gn/bootstrap/bootstrap.py --skip-generate-buildfiles
	(  cd $(@D); \
		$(TARGET_MAKE_ENV) \
		BUILD_CC="/usr/bin/clang" \
		BUILD_CXX="/usr/bin/clang++ " \
		BUILD_AR="ar" \
		BUILD_NM="nm" \
		BUILD_CFLAGS="$(HOST_CFLAGS)" \
		BUILD_CXXFLAGS="$(HOST_CXXFLAGS)" \
		BUILD_LDFLAGS="$(HOST_LDFLAGS)" \
		CC="$(HOST_DIR)/bin/clang  --sysroot=/mnt/buildroot-chromium2/buildroot/output/staging/" \
		CXX="$(HOST_DIR)/bin/clang++ --sysroot=/mnt/buildroot-chromium2/buildroot/output/staging/" \
		AR="$(TARGET_AR)" \
		NM="$(TARGET_NM)" \
		CFLAGS="$(TARGET_CFLAGS) -I/mnt/buildroot-chromium2/buildroot/output/staging/usr/include/ " \
		CXXFLAGS="$(TARGET_CXXFLAGS) -I/mnt/buildroot-chromium2/buildroot/output/staging/usr/include/ " \
		LDFLAGS="$(TARGET_LDFLAGS) -L/mnt/buildroot-chromium2/buildroot/output/staging/usr/lib -L/mnt/buildroot-chromium2/buildroot/output/staging/lib -Wl,-rpath-link,/mnt/buildroot-chromium2/buildroot/output/staging/usr/lib -Wl,-rpath-link,/mnt/buildroot-chromium2/buildroot/output/staging/lib" \
		ARCH="$(BR2_PACKAGE_CHROMIUM_TARGET_ARCH)" \
	  ./out/Release/gn gen --args='${CHROMIUM_OPTS}' --script-executable='$(HOST_DIR)/bin/python2' "out/Release"  \
	)
endef

define CHROMIUM_BUILD_CMDS
	( cd $(@D); \
		$(TARGET_MAKE_ENV) \
		PATH=$(@D)/bin:$(BR_PATH) \
		LD_LIBRARY_PATH=/mnt/buildroot-chromium2/buildroot/output/staging/lib:/mnt/buildroot-chromium2/buildroot/output/staging/usr/lib \
		ninja -j$(PARALLEL_JOBS) -C out/Release chrome chromedriver \
	)
endef

define CHROMIUM_INSTALL_TARGET_CMDS
	$(INSTALL) -D $(@D)/out/Release/chrome $(TARGET_DIR)/usr/lib/chromium/chromium
	$(INSTALL) -Dm4755 $(@D)/out/Release/chrome_sandbox \
		$(TARGET_DIR)/usr/lib/chromium/chrome-sandbox
	cp $(@D)/out/Release/{chrome_{100,200}_percent,resources}.pak \
		$(@D)/out/Release/chromedriver \
		$(TARGET_DIR)/usr/lib/chromium/
	$(INSTALL) -Dm644 -t $(TARGET_DIR)/usr/lib/chromium/locales \
		$(@D)/out/Release/locales/*.pak
endef

$(eval $(generic-package))
