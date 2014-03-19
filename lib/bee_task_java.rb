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

require 'rubygems'
require 'bee_task_package'
require 'fileutils'
require 'rexml/document'
require 'rexml/xpath'
require 'dependency_resolver'

module Bee
  
  module Task
  
    # Package for Java tasks.
    class Java < Package

      # Classpath scopes.
      SCOPES = ['compile', 'runtime', 'test']
    
      # Compile Java source files.
      # 
      # - src: directory or list of directories containing Java source files to
      #   compile.
      # - dest: destination directory for generated class files.
      # - classpath: the classpath as defined on javac command line (optional,
      #   if dependencies not set).
      # - dependencies: the list of files to include into classpath (optional,
      #   if classpath not set).
      # - deprecation: tells if we should show deprecation description, should
      #   be true or false (defaults to false).
      # - encoding: specify encoding for source files (defaults to platform
      #   encoding).
      # - debug: tells if we should generate debug information, must be true
      #   or false (defaults to false).
      # - nowarn: tells if we should ignore warnings, must be true or false
      #   (defaults to false).
      # - verbose: tells if we should generate verbose output, must be true
      #   or false (defaults to false).
      # - options: custom options to use on command line (optional).
      # 
      # Example
      # 
      #  - java.javac:
      #      src:       "test"
      #      dest:      "#{build_dir}/test_classes"
      #      classpath: ["#{build_dir}/classes", "lib/*.jar"]
      def javac(params)
        # check parameters
        params_desc = {
          :src          => { :mandatory => true,  :type => :string_or_array },
          :dest         => { :mandatory => true,  :type => :string },
          :classpath    => { :mandatory => false, :type => :string },
          :dependencies => { :mandatory => false, :type => :string_or_array },
          :deprecation  => { :mandatory => false, :type => :boolean,
                             :default => false },
          :encoding     => { :mandatory => false, :type => :string },
          :debug        => { :mandatory => false, :type => :boolean,
                             :default => false },
          :nowarn       => { :mandatory => false, :type => :boolean,
                             :default => false },
          :verbose      => { :mandatory => false, :type => :boolean,
                             :default => false },
          :options      => { :mandatory => false, :type => :string }
        }
        check_parameters(params, params_desc)
        src          = params[:src]
        dest         = params[:dest]
        classpath    = params[:classpath]
        dependencies = params[:dependencies]
        deprecation  = params[:deprecation]
        encoding     = params[:encoding]
        debug        = params[:debug]
        nowarn       = params[:nowarn]
        verbose      = params[:verbose]
        options      = params[:options]
        # build the list of java source files
        src = Array(src)
        files = []
        for dir in src
          files += Dir.glob("#{dir}/**/*.java")
        end
        files.map! { |file| "\"#{file}\"" }
        files.uniq!
        # build classpath
        error "Only one of classpath or dependencies may be set" if
          classpath and dependencies
        path = classpath if classpath
        path = build_classpath(dependencies) if dependencies
        # make destination directory if it doesn't exist
        FileUtils.makedirs(dest) if not File.exists?(dest)
        error "javac 'dest' parameter must be a writable directory" unless
          File.directory?(dest) and File.writable?(dest)
        # run javac command
        puts "Compiling #{files.length} Java source file(s)"
        command = "javac "
        command += "-classpath #{path} " if path
        command += "-d \"#{dest}\" "
        command += "-deprecation " if deprecation
        command += "-encoding #{encoding} " if encoding
        command += "-g " if debug
        command += "-nowarn " if nowarn
        command += "-verbose " if verbose
        command += "#{options} " if options
        command += "#{files.join(' ')}"
        puts "Running command '#{command}'" if @verbose
        ok = system(command)
        error "Error compiling Java source files" unless ok
      end

      # Generate Jar file.
      # 
      # - src: directory or list of directories to include to the archive.
      # - includes: glob or list of globs for files to include in the Jar file.
      # - excludes: glob or list of globs for files to exclude from the Jar
      #   file.
      # - manifest: manifest file to include in generated Jar file (optional).
      # - dest: the Jar file to generate.
      # - options: custom options to use on command line (optional).
      # 
      # Example
      # 
      #  - java.jar:
      #      src: "#{build_dir}/classes"
      #      dest: "#{build_dir}/myjar.jar"
      def jar(params)
        # check parameters
        params_desc = {
          :src      => { :mandatory => false, :type => :string_or_array },
          :includes => { :mandatory => false, :type => :string_or_array },
          :excludes => { :mandatory => false, :type => :string_or_array },
          :manifest => { :mandatory => false, :type => :string },
          :dest     => { :mandatory => true,  :type => :string },
          :options  => { :mandatory => false, :type => :string }
        }
        check_parameters(params, params_desc)
        src      = params[:src]
        includes = params[:includes]
        excludes = params[:excludes]
        manifest = params[:manifest]
        dest     = params[:dest]
        options  = params[:options]
        error "jar 'src' or 'includes' parameter must be specified" unless
          src or includes
        error "jar 'manifest' parameter must be an existing file" unless 
          not manifest or File.exists?(manifest)
        # select directories to include in the Jar file
        directories = []
        if src
          dirs = Array(src)
          for dir in dirs
            directories += Dir.glob(dir)
          end
        end
        # select files to include in the Jar file
        files = []
        if includes
          files = filter_files(nil, includes, excludes)
          files.map! { |file| "\"#{file}\"" }
        end
        # run command line
        puts "Processing Jar archive '#{dest}'"
        command = "jar c"
        command += "v" if @verbose
        command += "m" if manifest
        command +="f "
        command += "\"#{manifest}\" " if manifest
        command += "\"#{dest}\" "
        command += "#{options} " if options
        if directories.length > 0
          for dir in directories
            command += "-C \"#{dir}\" ."
          end
        end
        if files.length > 0
          command += "#{files.join(' ')}"
        end
        puts "Running command '#{command}'" if @verbose
        ok = system(command)
        error "Error generating Jar archive" unless ok
      end

      # Run a Java class.
      #
      # - main: main Java class to run.
      # - classpath: the classpath as defined on javac command line (optional,
      #   if dependencies not set).
      # - dependencies: the list of files to include into classpath (optional,
      #   if classpath not set).
      # - jar: Jar file to launch.
      # - server: run server version of the VM, must be true or false
      #   (defaults to false).
      # - properties: system properties to pass to virtual machine, must be
      #   a hash, such as { foo: bar } (optional).
      # - assertions: enables assertions, must be true or false (defaults to
      #   true).
      # - verbose: tells if we should generate verbose output, must be true
      #   or false (defaults to false).
      # - options: custom options to use on command line (optional).
      # - arguments: arguments to pass on Java program command line.
      #
      # Example
      #
      #  - java.java:
      #      main: test/Test
      #      classpath: build/classes
      def java(params)
        # check parameters
        params_desc = {
          :main         => { :mandatory => false, :type => :string },
          :classpath    => { :mandatory => false, :type => :string },
          :dependencies => { :mandatory => false, :type => :string_or_array },
          :jar          => { :mandatory => false, :type => :string },
          :server       => { :mandatory => false, :type => :boolean,
                             :default => false },
          :properties   => { :mandatory => false, :type => :hash },
          :assertions   => { :mandatory => false, :type => :boolean,
                             :default => true },
          :verbose      => { :mandatory => false, :type => :boolean,
                             :default => false },
          :options      => { :mandatory => false, :type => :string },
          :arguments    => { :mandatory => false, :type => :string }
        }
        check_parameters(params, params_desc)
        main         = params[:main]
        classpath    = params[:classpath]
        dependencies = params[:dependencies]
        jar          = params[:jar]
        server       = params[:server]
        properties   = params[:properties]
        assertions   = params[:assertions]
        verbose      = params[:verbose]
        options      = params[:options]
        arguments    = params[:arguments]
        error "jar 'classpath', 'dependencies' or 'jar' parameters must be set" if
          not classpath and not dependencies and not jar
        # build classpath
        error "Only one of classpath or dependencies may be set" if
          classpath and dependencies
        path = classpath if classpath
        path = build_classpath(dependencies) if dependencies
        # run command line
        if main
          puts "Running java class '#{main}'"
        else
          puts "Running jar file '#{jar}'"
        end
        command = "java "
        command += "-server " if server
        if properties
          for key in properties.keys
            command += "-D#{key}=#{properties[key]} "
          end
        end
        command += "-enableassertions " if assertions
        command += "-verbose " if verbose
        command += "#{options} " if options
        command += "-jar #{jar} " if jar
        command += "-classpath #{path} " if path
        command += "\"#{main}\"" if main
        command += " #{arguments}" if arguments
        puts "Running command '#{command}'" if @verbose
        ok = system(command)
        error "Error running java" unless ok
      end

      # Generate Java documentation. Parameters is a hash with following
      # entries:
      #
      # - src: directory or list of directories for Java source files to
      #   document.
      # - includes: glob or list of globs for files to document.
      # - excludes: glob or list of globs for files to exclude from
      #   documentation.
      # - dest: destination directory for generated documentation.
      # - verbose: tells if we should generate verbose output, must be true
      #   or false (defaults to false).
      # - options: custom options to use on command line (optional).
      #
      # Example
      #
      #  - java.javadoc:
      #      src: :src
      #      dest: "#{build_dir}/api"
      def javadoc(params)
        # check parameters
        params_desc = {
          :src      => { :mandatory => false, :type => :string_or_array },
          :includes => { :mandatory => false, :type => :string_or_array },
          :excludes => { :mandatory => false, :type => :string_or_array },
          :dest     => { :mandatory => true,  :type => :string },
          :verbose  => { :mandatory => false, :type => :boolean,
                         :default => false },
          :options  => { :mandatory => false, :type => :string }
        }
        check_parameters(params, params_desc)
        src      = params[:src]
        includes = params[:includes]
        excludes = params[:excludes]
        dest     = params[:dest]
        verbose  = params[:verbose]
        options  = params[:options]
        error "javadoc 'src' or 'includes' parameter must be specified" unless
          src or includes
        # select files to document
        files = []
        if src
          dirs = Array(src)
          for dir in dirs
            files += Dir.glob("#{dir}/**/*.java")
          end
        end
        if includes
          files = filter_files(nil, includes, excludes)
        end
        files.map! { |file| "\"#{file}\"" }
        # run command line
        puts "Running javadoc on #{files.length} Java source file(s)"
        command = "javadoc -d \"#{dest}\" "
        command += "-quiet " if not verbose
        command += "#{options} " if options
        command += "#{files.join(' ')}"
        puts "Running command '#{command}'" if @verbose
        ok = system(command)
        error "Error running javadoc" unless ok
      end

      # Run Junit tests.
      #
      # - src: directory or list of directories of Java source files for
      #   tests to run.
      # - includes: glob or list of globs for tests to run within source
      #   directory(ies) (defaults to '**/*Test.java').
      # - excludes: glob or list of globs for tests to exclude within
      #   source directory(ies) (optional).
      # - classpath: the list of directories and files to include into
      #   classpath. Note that this should include Jar file for JUnit,
      #   class files for classes under test and unit tests themselves.
      # - skip: tells if we should skip test. Optional, defaults to false.
      # - options: custom options to use on command line (optional).
      # - version: the JUnit version (defaults to 4 and later). This may
      #   be important for 3 and earlier versions where runner is in
      #   'junit.runner' package instead of 'org.junit.runner'. Note that
      #   for JUnit 3 and earlier, JUnit test runner will run once for
      #   each test class.
      #
      # Example
      #
      #  - java.junit:
      #      src:       :test_src
      #      classpath: [:junit_jar, :classes, :test-classes]
      def junit(params)
        # check parameters
        params_desc = {
          :src          => { :mandatory => true,  :type => :string_or_array },
          :includes     => { :mandatory => false, :type => :string_or_array,
                             :default => '**/*Test.java' },
          :excludes     => { :mandatory => false, :type => :string_or_array },
          :classpath    => { :mandatory => false, :type => :string },
          :dependencies => { :mandatory => false, :type => :string_or_array },
          :skip         => { :mandatory => false, :type => :boolean,
                             :default => false },
          :options      => { :mandatory => false, :type => :string },
          :version      => { :mandatory => false, :type => :string,
                             :default => '4' }
        }
        check_parameters(params, params_desc)
        src          = params[:src]
        includes     = params[:includes]
        excludes     = params[:excludes]
        classpath    = params[:classpath]
        dependencies = params[:dependencies]
        skip         = params[:skip]
        options      = params[:options]
        version      = params[:version]
        for dir in src
          error "junit 'src' directory was not found" unless
            File.exists?(dir) and File.directory?(dir)
        end
        if not skip
          # build classpath
          error "Only one of classpath or dependencies may be set" if
            classpath and dependencies
          path = classpath if classpath
          path = build_classpath(dependencies) if dependencies
          # select test files to run
          files = []
          for dir in src
            files += filter_files(dir, includes, excludes)
          end
          files.uniq!
          classes = files.map do |file|
            file = file[0, file.rindex('.')] if File.extname(file).length > 0
            file.gsub!(/\//, '.')
            "\"#{file}\""
          end
          # run command line
          major_version = version.split('.')[0].to_i
          if major_version > 3
            main_class = 'org.junit.runner.JUnitCore'
            puts "Running JUnit on #{files.length} test file(s)"
            command = "java "
            command += "#{options} " if options
            command += "-classpath #{path} " if path
            command += "#{main_class} #{classes.join(' ')}"
            puts "Running command '#{command}'" if @verbose
            ok = system(command)
            error "Error running JUnit" unless ok
          else
            main_class = 'junit.textui.TestRunner'
            for test_class in classes
              puts "Running JUnit on '#{test_class}' test class"
              command = "java "
              command += "#{options} " if options
              command += "-classpath #{path} " if path
              command += "#{main_class} #{test_class}"
              puts "Running command '#{command}'" if @verbose
              ok = system(command)
              error "Error running JUnit" unless ok
            end
          end
          # run command line
        else
          puts "Skipping unit tests!!!"
        end
      end

      # Resolve dependencies and generate a classpath for a given dependencies
      # file. Synchronize dependencies with local repository if necessary
      # (default location is ~/.java/dependencies directory).
      #
      # - file: Dependencies file to parse ('dependencies.yml', 'project.xml'
      #   or 'pom.xml' depending on type). Defaults to 'dependencies.yml'.
      # - type: the dependencies type: 'bee', 'maven1' or 'maven2'. Defaults to
      #   'bee'.
      # - scope: the scope of the classpath to build ('compile', 'test' and so
      #   on, as defined in dependencies file).
      # - directories: directory or list of directories to add to classpath.
      # - classpath: the property name to set with classpath.
      # - dependencies: the property name to set with the list of dependencies
      #   files.
      def classpath(params)
        params_desc = {
          :file         => { :mandatory => false, :type => :string,
                             :default => 'dependencies.yml'},
          :type         => { :mandatory => false, :type => :string,
                             :default => 'bee' },
          :scope        => { :mandatory => false, :type => :string,
                             :default => 'compile' },
          :directories  => { :mandatory => false, :type => :string_or_array },
          :classpath    => { :mandatory => false,  :type => :string },
          :dependencies => { :mandatory => false,  :type => :string }
        }
        check_parameters(params, params_desc)
        file         = params[:file]
        type         = params[:type]
        scope        = params[:scope]
        directories  = params[:directories]
        classpath    = params[:classpath]
        dependencies = params[:dependencies]
        if not SCOPES.include?(scope)
          scopes = SCOPES.map{ |s| "'#{s}'"}.join(', ')
          error "Unknown scope '#{scope}', must be one of #{scopes}"
        end
        puts "Building CLASSPATH for dependencies '#{file}' and scope '#{scope}'..."
        if type == 'bee'
          resolver = Bee::Task::BeeDependencyResolver.new(file, scope, @verbose)
        elsif type == 'maven1'
          resolver = Bee::Task::MavenDependencyResolver.new(file, scope, @verbose)
        elsif type == 'maven2'
          resolver = Bee::Task::Maven2DependencyResolver.new(file, scope, @verbose)
        else
          error "Unknown type, must be 'bee', 'maven1' or 'maven2'"
        end
        if classpath
          path = resolver.classpath
          path += ':' + directories.join(File::PATH_SEPARATOR) if directories
          @build.context.set_property(classpath, path)
        end
        if dependencies
          deps = resolver.dependencies
          deps += directories if directories
          @build.context.set_property(dependencies, deps)
        end
      end

      private

      # Build a classpath from a set of globs.
      # - globs: glob or list of globs that make this classpath.
      def build_classpath(globs)
        return nil if not globs
        globs = Array(globs)
        files = []
        for glob in globs
          files += Dir.glob(glob)
        end
        files.map! { |entry| "\"#{entry}\"" }
        return files.join(File::PATH_SEPARATOR)
      end

    end

  end

end
