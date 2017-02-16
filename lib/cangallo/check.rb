
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
      problem = false

      problem ||= !check_kernel
      problem ||= !check_qemu_img
      problem ||= !check_libguestfs

      if problem
        text = <<-EOT
There is at least one problem in your system. You can go this page to
get more information on how to fix it:

https://canga.io/install/

        EOT

        STDERR.puts text
      end

      STDERR.puts <<-EOT
It's also a good idea to execute libguestfs test tool:

    $ libguestfs-test-tool

EOT

      problem
    end

    def check_kernel
      Dir['/boot/vmlinuz*'].each do |file|
        if File.readable?(file)
          return true
        end
      end

      help_kernel
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

    def check_qemu_img
      version = Cangallo::Qcow2.qemu_img_version

      if !version
        text = "Could not get qemu-img version. Is it installed in your system?"

        STDERR.puts text
        STDERR.puts
        exit(-1)
      end

      good = Gem::Version.new('2.4.0')
      current = Gem::Version.new(version)

      if current >= good
        true
      else
        help_qemu_img
        false
      end
    end

    def help_qemu_img
      text = <<-EOT
Cangallo needs a qemu-img version equal or greater than 2.4.0. Yours appears
to be older. This will make impossible to compress delta images. You can
download this qemu-img binary and add it to the path. Make sure the path
possition is before #{%x(which qemu-img).strip}.

https://canga.io/downloads/qemu-img.bz2

      EOT

      STDERR.puts text
    end

    def check_libguestfs
      version = Cangallo::LibGuestfs.version

      if !version
        text = "Could not get virt-customize version. Is libguestfs installed?"

        STDERR.puts text
        STDERR.puts
        exit(-1)
      end

      current = Gem::Version.new(version)
      good = Gem::Version.new("1.30.0")
      enough = Gem::Version.new("1.28.0")

      if current < enough
        help_libguestfs
        return false
      elsif current < good
        STDERR.puts "libguestfs >= 1.30.0 recomended"
        STDERR.puts
      end

      true
    end

    def help_libguestfs
      text = <<-EOT
libguestfs version 1.28.0 is needed although 1.30.0 or newer is recomended.

      EOT

      STDERR.puts text
    end
  end
end

