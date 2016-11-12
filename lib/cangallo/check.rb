
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

require 'rubygems'

class Cangallo
  class Check
    def initialize
    end

    def check
      valid = true

      valid = valid_kernel = check_kernel
      help_kernel if !valid_kernel


      if !valid
        text = "There is at least one one problem in your system."

        STDERR.puts
        STDERR.puts text
      end

      valid
    end

    def check_kernel
      Dir['/boot/vmlinuz*'].each do |file|
        if File.readable?(file)
          return true
        end
      end

      false
    end

    def help_kernel
      text = <<-EOT
libguestfs needs a kernel to boot it's qemu appliance. There is no kernel
in your /boot directory readable by your kernel. Change the permissions of
at least one kernel in that directory to be readable by the current user.
      EOT

      STDERR.puts text
    end
  end
end

