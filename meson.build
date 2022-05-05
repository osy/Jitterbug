project('jitterbugpair', 'c')

sources = ['JitterbugPair/main.c']
incdir = include_directories(['Libraries/include',
                              'Libraries/libimobiledevice',
                              'Libraries/libimobiledevice/common',
                              'Libraries/libimobiledevice/include',
                              'Libraries/libimobiledevice-glue/include'])

os = host_machine.system()
cflags = []
ldflags = []

if os == 'linux'
  crypto = dependency('libgcrypt', static: true)
  libusbmuxd = dependency('libusbmuxd', static: true)
  cflags += ['-DHAVE_ASPRINTF', '-DHAVE_VASPRINTF']
else
  crypto = dependency('openssl', version: ['>= 0.9.8'], static: true)
  libusbmuxd = dependency('libusbmuxd-2.0', static: true)
  cflags += ['-DHAVE_CONFIG_H']
  if os == 'windows'
    ldflags += ['-lIphlpapi']
  endif
endif

if os == 'windows'
  winpthread_path = run_command('which', 'libwinpthread-1.dll').stdout()
  winpthread = custom_target('winpthread',
                             output: 'libwinpthread-1.dll',
                             command: ['cp', winpthread_path, '@OUTPUT@'],
                             install: false,
                             build_by_default: true)
endif

libimobiledevice = dependency('libimobiledevice-1.0', static: true)
dependencies = [crypto, libusbmuxd, libimobiledevice]
executable('jitterbugpair',
           sources,
           include_directories: incdir,
           dependencies: dependencies,
           c_args: cflags,
           link_args: ldflags,
           install: true)
