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
$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'dependency_resolver'

# Test case for dependency resolver.
class TestDependencyResolver < Test::Unit::TestCase

  # Create a context object and load tasks in it.
  def setup
    super
    @resolver = Bee::Task::Maven2DependencyResolver.new('test/pom.xml', false)
  end

  def test_classpath
    classpath = @resolver.classpath
    # TODO
  end

end
