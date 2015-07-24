MRuby::Gem::Specification.new('mruby-onig-regexp') do |spec|
  spec.license = 'MIT'
  spec.authors = 'mattn'

  spec.linker.libraries << 'onig'

  next if ENV['OS'] == 'Windows_NT'
  if build.cc.respond_to? :search_header_path
    next if build.cc.search_header_path 'oniguruma.h'
  end

  require 'open3'
  require 'open-uri'

  version = '5.9.5'
  oniguruma_dir = "#{build_dir}/onig-#{version}"
  oniguruma_lib = libfile "#{oniguruma_dir}/.libs/libonig"
  header = "#{oniguruma_dir}/oniguruma.h"

  task :clean do
    FileUtils.rm_rf [oniguruma_dir]
  end

  file header do |t|
    FileUtils.mkdir_p oniguruma_dir

    _pp 'getting', "onig-#{version}"
    begin
      FileUtils.mkdir_p build_dir
      Dir.chdir(build_dir) do
        File.open("onig-#{version}.tar.gz", 'wb') do |f|
          open("http://www.geocities.jp/kosako3/oniguruma/archive/onig-#{version}.tar.gz", "accept-encoding" => "none") do |io|
            f.write io.read
          end
        end

        _pp 'extracting', "onig-#{version}"
        `gzip -dc onig-#{version}.tar.gz | tar x`
        raise IOError unless $?.exitstatus
      end
    rescue IOError
      File.delete "onig-#{version}.tar.gz"
      exit(-1)
    end
  end

  def run_command(env, command)
    STDOUT.sync = true
    Open3.popen2e(env, command) do |stdin, stdout, thread|
      print stdout.read
      fail "#{command} failed" if thread.value != 0
    end
  end

  file oniguruma_lib => header do |t|
    Dir.chdir(oniguruma_dir) do
      e = {
        'CC' => "#{spec.build.cc.command} #{spec.build.cc.flags.join(' ')}",
        'CXX' => "#{spec.build.cxx.command} #{spec.build.cxx.flags.join(' ')}",
        'LD' => "#{spec.build.linker.command} #{spec.build.linker.flags.join(' ')}",
        'AR' => spec.build.archiver.command }
      _pp 'autotools', oniguruma_dir
      run_command e, './autogen.sh' if File.exists? 'autogen.sh'
      configure_opts = '--disable-shared --enable-static'
      if build.kind_of?(MRuby::CrossBuild) && build.host_target && build.build_target
        configure_opts += " --host #{spec.build.host_target} --build #{spec.build.build_target}"
        e['LD'] = "x86_64-w64-mingw32-ld #{spec.build.linker.flags.join(' ')}" if build.host_target == "x86_64-w64-mingw32"
        e['LD'] = "i686-w64-mingw32-ld #{spec.build.linker.flags.join(' ')}" if build.host_target == "i686-w64-mingw32"
      end
      run_command e, "./configure #{configure_opts}"
      run_command e, 'make'
    end
  end

  file "#{dir}/src/mruby_onig_regexp.c" => oniguruma_lib
  spec.cc.include_paths << oniguruma_dir
  spec.linker.library_paths << File.dirname(oniguruma_lib)
end
