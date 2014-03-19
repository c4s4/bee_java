#!/usr/bin/env ruby

# Copyright 2006-2010 Michel Casabianca <michel.casabianca@gmail.com>
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

# Script that runs all tests in current directory (and subdirectories) 
# in a single test suite.

require 'find'

Find.find(File.dirname(__FILE__)) do |path|
  if File.file?(path) and path =~ /tc_.+\.rb$/
    load path
  end
end
