
# vim:tabstop=2:sw=2:et:

# Copyright 2016, Javier Fontán Muiños <jfontan@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'json'
require 'systemu'
require 'tempfile'
require 'fileutils'
require 'shellwords'
require 'rubygems'

class Cangallo

  class LibGuestfs
    CUSTOMIZE_CMD = /^([^\s]+)\s+(.*)$/

    def self.virt_customize(image, commands, params = "")
      version = self.version

      if !version
        raise "Could not get virt-customize version"
      end

      target_version = Gem::Version.new('1.30')
      current_version = Gem::Version.new(version)
      good_version = false

      customize_command = nil

      good_version = true if current_version >= target_version

      if good_version
        cmd_file = Tempfile.new("canga")

        cmd_file.puts(commands)
        cmd_file.close

        customize_command = "virt-customize -a #{image} #{params.join(" ")} " <<
                            "--commands-from-file #{cmd_file.path}"
      else
        cmd_params = commands.map do |line|
          m = line.match(CUSTOMIZE_CMD)
          if m
            command = m[1]
            parms = m[2].strip

            if command == 'copy-in'
              command = 'upload'
              parms, new_command = copy_in(parms)

              [
                "--" + command + " " + Shellwords.escape(parms),
                "--run-command " + Shellwords.escape(new_command)
              ]
            else
              "--" + command + " " + Shellwords.escape(parms)
            end
          else
            nil
          end
        end

        cmd_params.flatten!
        cmd_params.compact!

        customize_command = "virt-customize -a #{image} #{params.join(" ")} " <<
                            "#{cmd_params.join(" ")}"
      end

      rc = system(customize_command)

      cmd_file.unlink if good_version

      return rc
    end

    def self.virt_sparsify(image)
      rc = system("virt-sparsify --in-place #{image}")

      return rc
    end

    def self.version
      str = `virt-customize --version`

      m = str.match(/^virt-customize (\d+\.\d+\.\d+).*$/)

      if m
        m[1]
      else
        nil
      end
    end

    def self.copy_in(str)
      local, remote = str.split(':')

      raise "Source '#{local}' does not exist" if !File.exist?(local)

      upload_local = local
      upload_remote = remote
      run_command = nil

      if File.directory?(local)
        upload_local_tmp = Tempfile.new("canga")
        upload_local_tmp.close

        upload_local = upload_local_tmp.path
        upload_remote = "/tmp/#{File.basename(upload_local)}"


        local_parent_dir = File.dirname(local)
        local_name = File.basename(local)
        rc = system("tar czf #{upload_local} -C #{local_parent_dir} #{local_name}")

        raise "Error creating tar archive for '#{local_name}'" if !rc

        run_command = "tar xf #{upload_remote} -C #{remote}"
      end

      upload_param = "#{upload_local}:#{upload_remote}"

      return upload_param, run_command
    end
  end
end
