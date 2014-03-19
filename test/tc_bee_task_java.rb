#!/usr/bin/env ruby

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

require 'bee_context'
require 'test/unit'
$:.unshift(File.expand_path(File.dirname(__FILE__)))
require 'test_build'
require 'test_build_listener'
$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'bee_task_java'

# Test case for bee task.
class TestBeeTaskJava < Test::Unit::TestCase

  # Create a context object and load tasks in it.
  def setup
    super
    @context = Bee::Context.new()
    @listener = TestBuildListener.new
    @build = TestBuild.new(@context, @listener)
    @package = Bee::Task::Java.new(@build)
  end

  def test_javac
    # change directory to test dir
    previous_dir = Dir.pwd
    Dir.chdir(File.expand_path(File.dirname(__FILE__)))
    begin
      # run nominal case
      @package.javac({'src' => 'src', 'dest' => 'build/classes'})
      assert_equal("Compiling 1 Java source file(s)\n", @listener.output)
      assert(File.exists?('build/classes/test/Test.class'))
      # run error case: missing src parameter
      begin
        @package.javac({'dest' => 'build/classes'})
      rescue
        assert_equal("javac 'src' parameter is mandatory", $!.message)
      end
      # run error case: missing dest parameter
      begin
        @package.javac({'src' => 'src'})
      rescue
        assert_equal("javac 'dest' parameter is mandatory", $!.message)
      end
    ensure
      if File.exists?('build')
        FileUtils.rm_rf('build')
      end
      Dir.chdir(previous_dir)
    end
  end

  def test_jar
    # change directory to test dir
    previous_dir = Dir.pwd
    Dir.chdir(File.expand_path(File.dirname(__FILE__)))
    begin
      # run nominal case
      @package.javac({'src' => 'src', 'dest' => 'build/classes'})
      @listener.clear()
      @package.jar({'src' => 'build/classes', 'dest' => 'build/test.jar'})
      assert_equal("Processing Jar archive 'build/test.jar'\n",
                   @listener.output)
      assert(File.exists?('build/test.jar'))
    ensure
      if File.exists?('build')
        FileUtils.rm_rf('build')
      end
      Dir.chdir(previous_dir)
    end
  end

  def test_java
    # change directory to test dir
    previous_dir = Dir.pwd
    Dir.chdir(File.expand_path(File.dirname(__FILE__)))
    begin
      # run nominal case
      @package.javac({'src' => 'src', 'dest' => 'build/classes'})
      @listener.clear()
      @package.java({'classpath' => 'build/classes', 'main' => 'test.Test'})
      assert_equal("Running java class 'test.Test'\n",
                   @listener.output)
    ensure
      if File.exists?('build')
        FileUtils.rm_rf('build')
      end
      Dir.chdir(previous_dir)
    end
1  end

  def test_javadoc
    # change directory to test dir
    previous_dir = Dir.pwd
    Dir.chdir(File.expand_path(File.dirname(__FILE__)))
    begin
      # run nominal case
      @package.javadoc({'src' => 'src', 'dest' => 'build/api'})
      assert_equal("Running javadoc on 1 Java source file(s)\n",
                   @listener.output)
      assert(File.exists?('build/api/index.html'))
    ensure
      if File.exists?('build')
        FileUtils.rm_rf('build')
      end
      Dir.chdir(previous_dir)
    end
  end

  def test_junit
    if ENV['NET_TEST'] == 'true'
      # change directory to test dir
      previous_dir = Dir.pwd
      Dir.chdir(File.expand_path(File.dirname(__FILE__)))
      begin
        # run nominal case
        @package.javac({'src' => 'src', 'dest' => 'build/classes'})
        @package.deps({ 'src' => 'dependencies.yml', 'dest' => 'build/lib',
                        'repos' => 'http://www.ibiblio.org/maven'})
        @package.javac({ 'src' => 'test',
                         'dest' => 'build/classes',
                         'classpath' => ['build/classes', 'build/lib/*.jar']})
        @listener.clear()
        @package.junit({ 'src' => 'test',
                         'classpath' => ['build/classes', 'build/lib/*.jar']})
        assert_equal("Running JUnit on 1 test file(s)\n",
                     @listener.output)
      ensure
        if File.exists?('build')
          FileUtils.rm_rf('build')
        end
        Dir.chdir(previous_dir)
      end
    end
  end

  def test_deps
    if ENV['NET_TEST'] == 'true'
      # change directory to test dir
      previous_dir = Dir.pwd
      Dir.chdir(File.expand_path(File.dirname(__FILE__)))
      begin
        # run nominal case
        @package.deps({ 'src'   => 'dependencies.yml',
                        'dest'  => 'build/lib',
                        'repos' => 'http://www.ibiblio.org/maven'})
        assert_equal("Fetching 1 dependency(ies) to directory 'build/lib'\n",
                     @listener.output)
        assert(File.exists?('build/lib/junit-4.3.jar'))
      ensure
        if File.exists?('build')
          FileUtils.rm_rf('build')
        end
        Dir.chdir(previous_dir)
      end
    end
  end

  def test_classpath
    if ENV['NET_TEST'] == 'true'
      # change directory to test dir
      previous_dir = Dir.pwd
      Dir.chdir(File.expand_path(File.dirname(__FILE__)))
      begin
        @package.classpath( { 'file' => 'pom.xml',
                              'property' => 'classpath' } )
        dependencies = ['ehcache:ehcache:1.2beta4:jar',
                        'commons-logging-api:commons-logging:1.0.4:jar',
                        'commons-collections:commons-collections:2.1.1:jar']
        message = dependencies.map { |dep| "Downloading dependency '#{dep}'...\n" }.join
        assert_equal(messages, @listener.output)
        root = File.expand('~/.m2/repository')
        puts 'TEST'
        puts @package.build.get_property('classpath')
      ensure
        Dir.chdir(previous_dir)
      end
    end
  end
  
end
