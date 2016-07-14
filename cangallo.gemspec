
$LOAD_PATH << './lib'
require 'cangallo/version'

Gem::Specification.new do |s|
  s.name        = 'cangallo'
  s.version     = Cangallo::VERSION
  s.date        = '2016-06-28'
  s.summary     = "Cangallo!!"
  s.description = "VM Image manager"
  s.authors     = ["Javier Fontan"]
  s.email       = 'jfontan@gmail.com'
  s.license     = 'Apache-2.0'
  s.files       = [
    'bin/canga',
    'lib/cangallo.rb',
    'lib/cangallo/cangafile.rb',
    'lib/cangallo/config.rb',
    'lib/cangallo/keybase.rb',
    'lib/cangallo/libguestfs.rb',
    'lib/cangallo/qcow2.rb',
    'lib/cangallo/repo.rb',
    'lib/cangallo/version.rb'
  ]
  s.homepage    = 'http://canga.io'
  s.executables = [ 'canga' ]
  s.add_runtime_dependency 'thor'
  s.add_runtime_dependency 'systemu'
end
