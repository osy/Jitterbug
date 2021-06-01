project('jitterbugpair', 'c')
sources = ['JitterbugPair/main.c',
           'Libraries/libimobiledevice/common/debug.c',
           'Libraries/libimobiledevice/common/userpref.c',
           'Libraries/libimobiledevice/common/utils.c']
incdir = include_directories(['Libraries/include',
                              'Libraries/libimobiledevice',
                              'Libraries/libimobiledevice/common',
                              'Libraries/libimobiledevice/include'])
openssl = dependency('openssl', version: ['>= 0.9.8'], static: true)
libusbmuxd = dependency('libusbmuxd-2.0', static: true)
libimobiledevice = dependency('libimobiledevice-1.0', static: true)
dependencies = [openssl, libusbmuxd, libimobiledevice]
cflags = ['-DHAVE_CONFIG_H']
executable('jitterbugpair',
           sources,
           include_directories: incdir,
           dependencies: dependencies,
           c_args: cflags)
