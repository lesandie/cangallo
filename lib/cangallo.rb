
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

require 'cangallo/qcow2'
require 'cangallo/config'
require 'cangallo/repo'
require 'cangallo/cangafile'
require 'cangallo/libguestfs'
require 'cangallo/keybase'
require 'cangallo/version'
require 'cangallo/check'

class Cangallo
  def initialize
    @config = Cangallo::Config.new
  end

  def repo(name = nil)
    @config.repo(name)
  end

  def get_images(repo_name = nil)
    info = []
    repos = []

    if repo_name
      repos = [repo_name]
    else
      repos = @config.repos
    end

    repos.each do |r|
      repo = self.repo(r)

      repo.images.each do |sha256, image|
        name = repo.short_name(sha256)

        info << {
          "repo"    => r,
          "sha256"  => sha256,
          "name"    => "#{r}:#{name}",
          "size"    => image["actual-size"],
          "parent"  => short_name(image["parent"], r),
          "description" => image["description"],
          "available" => File.exist?(repo.image_path(sha256)),
          "creation-time" => image["creation-time"]
        }
      end
    end

    info
  end

  def parse_name(name)
    slices = name.split(':')

    repo = nil
    name = name

    if slices.length > 1
      repo = slices[0]
      name = slices[1]
    end

    return repo, name
  end

  def short_name(string, repo = nil)
    return nil if !string

    img_repo, img_name = parse_name(string)
    img_repo ||= repo

    image = self.repo(img_repo).find(img_name)
    name = self.repo(img_repo).short_name(image)

    "#{img_repo}:#{name}"
  end

  def find(string)
    repo, name = parse_name(string)
    return "#{repo}:#{self.repo(repo).find(name)}" if repo

    image = self.repo.find(name)
    return "#{self.repo.name}:#{image}" if image

    @config.repos.each do |r|
      image = self.repo(r).find(name)
      return "#{r}:#{image}" if image
    end

    nil
  end

  def get(string)
    image = find(string)
    return nil if !image

    repo, name = parse_name(image)

    img = self.repo(repo).get(name)

    img["repo"] = repo if img
    img
  end
end

