project('jitterbugpair', 'c')

sources = ['JitterbugPair/main.c',
           'Libraries/libimobiledevice/common/debug.c',
           'Libraries/libimobiledevice/common/userpref.c',
           'Libraries/libimobiledevice/common/utils.c']
incdir = include_directories(['Libraries/include',
                              'Libraries/libimobiledevice',
                              'Libraries/libimobiledevice/common',
                              'Libraries/libimobiledevice/include'])

os = host_machine.system()

if os == 'linux'
  crypto = dependency('libgcrypt', static: true)
  libusbmuxd = dependency('libusbmuxd', static: true)
  cflags = ['-DHAVE_ASPRINTF', '-DHAVE_VASPRINTF']
else
  crypto = dependency('openssl', version: ['>= 0.9.8'], static: true)
  libusbmuxd = dependency('libusbmuxd-2.0', static: true)
  cflags = ['-DHAVE_CONFIG_H']
endif

libimobiledevice = dependency('libimobiledevice-1.0', static: true)
dependencies = [crypto, libusbmuxd, libimobiledevice]
executable('jitterbugpair',
           sources,
           include_directories: incdir,
           dependencies: dependencies,
           c_args: cflags,
           install: true)
