project('BrowserJam2024', 'c',
  default_options : ['warning_level=3'])

cc = meson.get_compiler('c')

m_dep = cc.find_library('m', required : true)
raylib_sp = subproject('raylib')
raylib_dep = raylib_sp.get_variable('raylib_dep')

executable('browser', 'main.c', dependencies: [raylib_dep, m_dep])

