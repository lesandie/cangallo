
# vim:ts=2:sw=2

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

require "yaml"
require "open-uri"
require "uri"

class Cangallo

  class Repo
    attr_reader :images, :tags, :path, :name

    VERSION = 0

    def initialize(conf)
      @conf = conf
      @path = File.expand_path(@conf["path"])
      @name = @conf["name"]
      @type = @conf["type"]
      @url  = @conf["url"]

      if !@type && @url
        @type = "remote"
      else
        @type = "local"
      end

      read_index
    end

    def index_data(images = {}, tags = {}, version = VERSION)
      {
        "version" => version,
        "images"  => images,
        "tags"    => tags
      }
    end

    def index_path
      metadata_path("index")
    end

    def read_index(index = nil)
      if !index
        if File.exist?(index_path)
          data = YAML.load(File.read(index_path))
        else
          data = index_data()
        end
      else
        data = YAML.load(index)
      end

      @images       = data["images"]
      @tags         = data["tags"]
      @reverse_tags = @tags.invert
    end

    def write_index
      data = index_data(@images, @tags)

      open(metadata_path("index"), "w") do |f|
        f.write(data.to_yaml)
      end
    end

    def metadata_path(name)
      File.join(@path, "#{name}.yaml")
    end

    def image_path(name)
      File.join(@path, "#{name}.qcow2")
    end

    def remote_url(name)
      URI.join(@url, name)
    end

    def remote_image_url(name)
      remote_url("#{name}.qcow2")
    end

    def add(name, data)
      data["creation-time"] = Time.now
      data["sha256"] = name
      @images[name] = data
    end

    def add_image(file, data = {})
      parent_sha256 = nil
      parent = nil
      parent_path = nil

      only_copy = data.delete("only_copy")

      if data["parent"]
        parent_sha256 = data["parent"]
        parent = self.images[parent_sha256]

        if !parent
          raise "Parent not found"
        end

        parent_path = File.expand_path(self.image_path(parent_sha256))
      end

      puts "Calculating image sha256 with libguestfs (it will take some time)"
      qcow2 = Cangallo::Qcow2.new(file)
      sha256 = qcow2.sha256
      sha256.strip! if sha256

      puts "Image SHA256: #{sha256}"

      puts "Copying file to repository"
      image_path = self.image_path(sha256)
      qcow2.copy(image_path, parent: parent_path, only_copy: only_copy)

      qcow2 = Cangallo::Qcow2.new(image_path)
      info = qcow2.info

      info_data = info.select do |k,v|
        %w{virtual-size format actual-size format-specific}.include?(k)
      end

      data.merge!(info_data)

      data["file-sha256"] = Digest::SHA256.file(file).hexdigest

      if parent
        qcow2.rebase("#{parent_sha256}.qcow2")
        data["parent"] = parent_sha256
      end

      self.add(sha256, data)
      self.write_index

      sha256
    end

    def del_image(image)
      sha256 = find(image)

      raise %Q{Image "#{image}" does not exist} if !sha256

      path = image_path(sha256)
      begin
          File.delete(path)
      rescue Errno::ENOENT
          STDERR.puts "Image file not found"
      end

      @images.delete(sha256)

      @tags.select {|key, value| value == sha256 }.keys.each do |tag|
          @tags.delete(tag)
      end

      write_index
    end

    def add_tag(tag, image)
      img = find(image)
      @tags[tag] = img
      write_index
    end

    def del_tag(tag)
      @tags.delete(tag)
      write_index
    end

    def find(name, search_tags = true)
      length = name.length
      found = @images.select do |sha256, data|
        sha256[0, length] == name
      end

      if found && found.length > 0
        return found.first.first
      end

      if search_tags
        found = @tags.select do |tag, sha256|
          tag == name
        end
      end

      if found && found.length > 0
        return found.first[1]
      end

      nil
    end

    def get(name)
      image = find(name)

      return nil if !image

      @images[image]
    end

    def ancestors(name)
      ancestors = []

      image = get(name)
      ancestors << image["sha256"]

      while image["parent"]
        image = get(image["parent"])
        ancestors << image["sha256"]
      end

      ancestors
    end

    def url
      @conf["url"]
    end

    def fetch
      return nil if @conf["type"] != "remote"

      uri = remote_url("index.yaml")

      open(uri, "r") do |f|
        data = f.read
        read_index(data)
      end

      write_index
    end

    def sign
      Keybase.sign(index_path)
    end

    def verify
      Keybase.verify(index_path)
    end

    def pull(name)
      image = get(name)

      raise "Image not found" if !image

      sha256 = image["sha256"]
      image_url = remote_image_url(sha256)
      image_path = image_path(sha256)
      cmd = "curl -o '#{image_path}' '#{image_url}'"

      STDERR.puts(cmd)

      system(cmd)
    end

    def short_name(sha256)
      tag = @reverse_tags[sha256]

      if tag
        name = "#{tag}"
      else
        name = "#{sha256[0..15]}"
      end

      name
    end
  end

end

