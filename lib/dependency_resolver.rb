# Copyright 2008-2009 Michel Casabianca <michel.casabianca@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'net/http'
require 'fileutils'
require 'rexml/document'
require 'rexml/xpath'
require 'bee_util'
require 'pathname'

module Bee
  
  module Task

    # Parent of all dependency resolvers.
    class BaseDependencyResolver

      include Bee::Util::BuildErrorMixin

      # Default repository.
      DEFAULT_REPOSITORY = nil
      # Default cache location.
      DEFAULT_CACHE      = nil

      # Constructor:
      # - file: dependency file (should be maven.xml).
      # - scope: the scope for dependencies (compile, runtime or test).
      # - verbose: tells if we should be verbose.
      def initialize(file, scope, verbose=false)
        @file = file
        @scope = scope
        @verbose = verbose
        @repositories = parse_repositories
        @cache = DEFAULT_CACHE
        @dependencies = nil
        # print information if verbose
        puts "Repositories: #{@repositories.join(', ')}" if @verbose
      end

      # Return the classpath.
      def classpath
        return dependencies.join(File::PATH_SEPARATOR)
      end

      # Return dependencies as a list.
      def dependencies
        synchronize
        dependencies = @dependencies.map do |dependency| 
          build_path(@cache, dependency)
        end
        return dependencies
      end

      private

      # Resolve dependencies.
      # Returns dependencies as a list.
      def resolve
        @dependencies = parse_dependencies(File.read(@file)) if
          not @dependencies
        return @dependencies
      end

      # Synchronize dependencies with local cache.
      def synchronize
        resolve
        for dependency in @dependencies
          tofile = build_path(@cache, dependency)
          if not File.exists?(tofile)
            download_save(dependency, tofile)
          else
            puts "Dependency '#{build_name(dependency)}' already downloaded" if
              @verbose
          end
        end
      end

      # Extract repository list from file.
      # Return: repository list.
      def parse_repositories
        raise 'Not implemented'
      end

      # Download a given dependency.
      # - dependency: dependency as a map.
      # Return: dependency as a binary.
      def download(dependency, log=true)
        name = build_name(dependency)
        puts "Downloading dependency '#{name}'..." if log or @verbose
        if dependency[:path]
          path = Pathname.new(dependency[:path])
          path = File.join(File.dirname(@file), path) if !path.absolute?
          return File.open(path) { |f| f.read() }
        else
          for repository in @repositories
            url = build_path(repository, dependency)
            puts "Trying '#{url}'..." if @verbose
            begin
              return fetch(url)
            rescue
            end
          end
          error "Dependency '#{name}' not found"
        end
      end

      # Download a given dependency and save in a file.
      # - dependency: dependency as a map.
      # - file: the file where to save depndency.
      def download_save(dependency, file, log=true)
        name = build_name(dependency)
        puts "Downloading dependency '#{name}'..." if log or @verbose
        if dependency[:path]
          path = Pathname.new(dependency[:path])
          path = File.join(File.dirname(@file), path) if !path.absolute?
          return File.open(path) { |f| f.read() }
        else
          for repository in @repositories
            url = build_path(repository, dependency)
            puts "Trying '#{url}'..." if @verbose
            begin
              fetch_save(url, file)
              return
            rescue
            end
          end
          error "Dependency '#{name}' not found"
        end
      end

      # Build a path.
      # - root: the path root (root directory for repository or cache).
      # - dependency: dependency as a map.
      # Return: path as a string.
      def build_path(root, dependency)
        raise 'Not implemented'
      end

      # Build dependency name for display.
      # - dependency: dependency as a map.
      # Return: name as a string.      
      def build_name(dependency)
        groupid = dependency[:groupid]
        artifactid = dependency[:artifactid]
        version = dependency[:version]
        type = dependency[:type] || 'jar'
        return "#{artifactid}:#{groupid}:#{version}:#{type}"
      end

      # Extract dependencies from a file.
      # - source: file source.
      # Return: dependencies as a list of maps with keys groupid, artifactid,
      # version, type, optional.
      def parse_dependencies(source)
        raise 'Not implemented'
      end

      # Save a given binary in a file and create directories as necessary.
      # - binary: data to save.
      # - tofile: file to save into.
      def save_file(binary, tofile)
        puts "Saving file '#{tofile}'..." if @verbose
        directory = File.dirname(tofile)
        FileUtils.makedirs(directory) if not File.exists?(directory)
        File.open(tofile, 'wb') { |file| file.write(binary) }    
      end

      # Maximum number of HTTP redirection.
      HTTP_REDIRECTION_LIMIT = 10
  
      # Get a given URL.
      # - url: URL to get.
      # - limit: redirection limit (defaults to HTTP_REDIRECTION_LIMIT).
      def fetch(url, limit = HTTP_REDIRECTION_LIMIT)
        puts "Fetching '#{url}'..." if @verbose
        raise 'HTTP redirect too deep' if limit == 0
        response = Net::HTTP.get_response(URI.parse(url))
        case response
        when Net::HTTPSuccess
          response.body
        when Net::HTTPRedirection
        when Net::HTTPMovedPermanently
          fetch(build_url(url, response['location']), limit - 1)
        else
          response.error!
        end
      end

      # Get a given URL and save body in a file.
      # - url: URL to get.
      # - file: the file where to save the body.
      # - limit: redirection limit (defaults to HTTP_REDIRECTION_LIMIT).
      def fetch_save(url, file, limit = HTTP_REDIRECTION_LIMIT)
        puts "Fetching '#{url}'..." if @verbose
        raise 'HTTP redirect too deep' if limit <= 0
        directory = File.dirname(file)
        FileUtils.makedirs(directory) if not File.exists?(directory)
        uri = URI.parse(url)
        Net::HTTP.start(uri.host, uri.port) do |http|
          http.request_get(uri.path) do |response|
            if response.is_a?(Net::HTTPRedirection) or response.is_a?(Net::HTTPMovedPermanently)
              fetch_save(build_url(url, response['location']), file, limit - 1)
              return
            elsif !response.is_a?(Net::HTTPSuccess)
              raise "Bad status code '#{response.code}'"
            end
            File.open(file,'wb') do |f|
              response.read_body do |segment|
                f.write(segment)
                # hack, else 100% CPU
                sleep 0.001
              end
            end
          end
        end
      end

      def build_url(base, path)
        if path =~ /^http:\/\//
          return path
        else
          uri = URI(base)
          return "#{uri.scheme}://#{uri.host}#{path}"
        end
      end

    end
  
    # Bee dependency resolver.
    class BeeDependencyResolver < BaseDependencyResolver

      # Default repository address.
      DEFAULT_REPOSITORY = 'http://repo1.maven.org/maven2'
      # Default cache location.
      DEFAULT_CACHE      = File.expand_path('~/.java/dependencies')

      # Constructor:
      # - file: dependency file (should be maven.xml).
      # - scope: the scope for dependencies (compile, runtime or test).
      # - verbose: tells if we should be verbose.
      def initialize(file, scope, verbose=false)
        super(file, scope, verbose)
        @cache = DEFAULT_CACHE
      end

      # Extract dependencies from a file.
      # - source: file source.
      # Return: dependencies as a list of maps with keys groupid, artifactid,
      # version, type, optional.
      def parse_dependencies(source)
        dependencies = YAML::load(source)
        new_dependencies = []
        for dependency in dependencies
          if dependency['group']
            if Array(dependency['scope']).include?(@scope) or !dependency['scope']
              new_dependency = {}
              for key in dependency.keys
                if key != 'group' and key != 'artifact'
                  new_dependency[key.to_sym] = dependency[key]
                elsif key == 'group'
                  new_dependency[:groupid] = dependency['group']
                elsif key == 'artifact'
                  new_dependency[:artifactid] = dependency['artifact']
                end
              end
              new_dependencies << new_dependency
            end
          end
        end
        return new_dependencies
      end

      # Extract repository list from file.
      # Return: repository list.
      def parse_repositories
        repositories = YAML::load(File.read(@file))
        new_repositories = []
        for repository in repositories
          if repository['repository']
            new_repositories << repository['repository']
          elsif repository['repositories']
            new_repositories = new_repositories + repository['repositories']
          end
        end
        return new_repositories
      end

      # Build a Maven path.
      # - root: the path root (root directory for repository or cache).
      # - dependency: dependency as a map.
      # Return: path as a string.
      def build_path(root, dependency)
        groupid = dependency[:groupid].split('.').join('/')
        artifactid = dependency[:artifactid]
        version = dependency[:version]
        type = dependency[:type] || 'jar'
        classifier = dependency[:classifier]
        if classifier
          return "#{root}/#{groupid}/#{artifactid}/#{version}/#{artifactid}-#{version}-#{classifier}.#{type}"
        else
          return "#{root}/#{groupid}/#{artifactid}/#{version}/#{artifactid}-#{version}.#{type}"
        end        
      end

    end

    # Maven 1 dependency resolver.
    class MavenDependencyResolver < BaseDependencyResolver

      include Bee::Util::BuildErrorMixin

      # Default repository.
      DEFAULT_REPOSITORY = 'http://repo1.maven.org/maven'
      # Default cache location.
      DEFAULT_CACHE      = File.expand_path('~/.maven/repository')
      # Default dependency scope.
      DEFAULT_SCOPE      = 'compile'
      # scope availability: list for a given dependency scope the implied classpath scopes
      SCOPE_AVAILABILITY = {
        'compile'  => ['compile', 'test', 'runtime'],
        'provided' => ['compile', 'test'],
        'runtime'  => ['test', 'runtime'],
        'test'     => ['test'],
      }

      # Constructor:
      # - file: dependency file (should be maven.xml).
      # - scope: the scope for dependencies (compile, runtime or test).
      # - verbose: tells if we should be verbose.
      def initialize(file, scope, verbose=false)
        super(file, scope, verbose)
        @cache = DEFAULT_CACHE
      end

      private

      # Extract repository list from file.
      # Return: repository list.
      def parse_repositories
        repositories = []
        doc = REXML::Document.new(File.read(@file))
        REXML::XPath.each(doc, '/project/repository') do |element|
          REXML::XPath.each(element, 'url') do |entry|
            repositories << entry.text.strip
          end
        end
        repositories << DEFAULT_REPOSITORY if repositories.empty?
        return repositories
      end

      # Build a Maven path.
      # - root: the path root (root directory for repository or cache).
      # - dependency: dependency as a map.
      # Return: path as a string.
      def build_path(root, dependency)
        groupid = dependency[:groupid]
        artifactid = dependency[:artifactid]
        version = dependency[:version]
        type = dependency[:type] || 'jar'
        return "#{root}/#{groupid}/#{type}s/#{artifactid}-#{version}.#{type}"
      end

      # Extract dependencies from a file.
      # - source: file source.
      # Return: dependencies as a list of maps with keys groupid, artifactid,
      # version, type, optional.
      def parse_dependencies(source)
        dependencies = []
        doc = REXML::Document.new(source)
        properties = {}
        REXML::XPath.each(doc, '/project/properties/*') do |element|
          name = element.name.strip
          value = element.text
          value = value.strip if value
          properties[name] = value
        end
        REXML::XPath.each(doc, '/project/dependencies/dependency') do |element|
          dependency = {}
          REXML::XPath.each(element, '*') do |entry|
            name = entry.name.downcase.to_sym
            value = entry.text.strip
            for key in properties.keys
              value = value.gsub(/\$\{#{key}\}/, properties[key]) if 
                properties[key]
            end
            dependency[name] = value
          end
          dependencies << dependency if selected?(dependency)
        end
        return dependencies
      end

      # Tells if a given dependency should be selected.
      # - dependency: the dependency to consider.
      def selected?(dependency)
        return false if dependency[:optional] == 'true'
        dep_scope = dependency[:scope] || DEFAULT_SCOPE
        raise "Unknown dependency scope '#{dep_scope}'" if
          !SCOPE_AVAILABILITY.keys.include?(dep_scope)
        return SCOPE_AVAILABILITY[dep_scope].include?(@scope)
      end

    end

    # Maven 2 dependency resolver.
    class Maven2DependencyResolver < MavenDependencyResolver

      # Default repository address.
      DEFAULT_REPOSITORY = 'http://repo1.maven.org/maven2'
      # Default cache location.
      DEFAULT_CACHE      = File.expand_path('~/.m2/repository')

      # Constructor:
      # - file: dependency file (should be maven.xml).
      # - scope: the scope for dependencies (compile, runtime or test).
      # - verbose: tells if we should be verbose.
      def initialize(file, scope, verbose=false)
        super(file, scope, verbose)
        @cache = DEFAULT_CACHE
      end

      private

      # Resolve dependencies.
      # Returns dependencies as a list.
      def resolve
        if not @dependencies
          @dependencies = parse_dependencies(File.read(@file))
          for dependency in @dependencies
            @dependencies = @dependencies + recurse_dependency(dependency)
          end
        end
        return @dependencies
      end

      # Recurse on a given dependency.
      # - dependency: depedency to recurse over as a map.
      # Return: dependencies as a list.
      def recurse_dependency(dependency)
        pom = dependency.clone
        pom[:type] = 'pom'
        new_dependencies = []
        begin
          pom_file = build_path(@cache, pom)
          if not File.exists?(pom_file)
            new_pom = download(pom, false)
            save_file(new_pom, pom_file)
          else
            name = build_name(pom)
            puts "POM file '#{name}' already downloaded" if @verbose
            new_pom = File.read(pom_file)
          end
          new_dependencies = parse_dependencies(new_pom)
          for new_dependency in new_dependencies
            to_add = recurse_dependency(new_dependency)
            new_dependencies = new_dependencies + to_add if not to_add.empty
          end
        rescue
        end
        return new_dependencies
      end

      # Extract repository list from POM file or 
      # Return: repository list.
      def parse_repositories
        repositories = []
        # search for repositories in POM file
        doc = REXML::Document.new(File.read(@file))
        REXML::XPath.each(doc, '/project/distributionManagement/repository') do |element|
          REXML::XPath.each(element, 'url') do |entry|
            repositories << entry.text.strip
          end
        end
        # search for repositories in cache repository
        begin
          doc = REXML::Document.new(File.read(File.expand_path('~/.m2/settings.xml')))
          REXML::XPath.each(doc, '/settings/mirrors/mirror') do |element|
            REXML::XPath.each(element, 'url') do |entry|
              repositories << entry.text.strip
            end
          end
          REXML::XPath.each(doc, '/settings/profiles/profile/repositories/repository') do |element|
            REXML::XPath.each(element, 'url') do |entry|
              repositories << entry.text.strip
            end
          end
        rescue
        end
        repositories << DEFAULT_REPOSITORY if repositories.empty?
        return repositories.uniq
      end

      # Build a Maven path.
      # - root: the path root (root directory for repository or cache).
      # - dependency: dependency as a map.
      # Return: path as a string.
      def build_path(root, dependency)
        groupid = dependency[:groupid].split('.').join('/')
        artifactid = dependency[:artifactid]
        version = dependency[:version]
        type = dependency[:type] || 'jar'
        classifier = dependency[:classifier]
        path = dependency[:path]
        if classifier
          return "#{root}/#{groupid}/#{artifactid}/#{version}/#{artifactid}-#{version}-#{classifier}.#{type}"
        else
          return "#{root}/#{groupid}/#{artifactid}/#{version}/#{artifactid}-#{version}.#{type}"
        end
      end

    end

  end

end
