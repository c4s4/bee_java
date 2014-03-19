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

# Context for bee build file. Defines utility functions used in Ruby
# tasks.

$:.unshift(File.expand_path(File.join(base, 'lib')))
require 'bee_task_package'
require 'bee_task_java'

# Generate tasks reference page in RDoc format.
# - rdoc_tasks_reference: file for generated rdoc.
def generate_tasks_reference(rdoc_tasks_reference)
  methods = Bee::Task::Java.instance_methods(false)
  rdoc = "Here is the reference for Bee Java tasks:\n\n"
  for method in methods.sort
    comment = Bee::Task::Java.method_info(method).comment
    rdoc << "== #{method}\n\n"
    rdoc << "#{comment}\n\n"
  end
  rdoc.strip!
  File.open(rdoc_tasks_reference, 'w') { |file| file.write(rdoc) }
end

# Generate templates reference page in RDoc format.
# - rdoc_templates_reference: file for generated rdoc.
def generate_templates_reference(rdoc_templates_reference)
  files = Dir.glob('egg/*.yml').sort!
  rdoc = "Here is the list of available Java project templates. You can 
instantiate a given template typing 'bee -t <template>', get help with 
'bee -e <template>' and list all templates with 'bee -e ?'.\n\n"
  for file in files
    template = file[file.index('/')+1 ... file.index('.')]
    data = YAML::load(File.read(file))
    for entry in data
      if entry['properties']
        properties = entry['properties']
        if properties['description']
          description = properties['description']
        end
      end
    end
    rdoc << "== #{template}\n\n"
    rdoc << "#{description}\n\n"
  end
  rdoc.strip!
  File.open(rdoc_templates_reference, 'w') { |file| file.write(rdoc) }
end

# Stuff to get notes in files.

require 'find'

# Patterns to look for (all downcase)
NOTE = /\W+todo[^(]?\W+|\W+debug[^(]?\W+|\W+fixme[^(]?\W+/
# File extensions to parse (all uppercase)
EXTS = /.rb|.py|.java|.txt|.xml|.html|.yaml|.yml/
# Regular expressions that tells if a line is comment depending on the extension
COMMENT = { 
  '.rb'   => /^\s*\#/,
  '.py'   => /^\s*\#/,
  '.java' => /^\s*[\/\/|\/*]/,
  '.txt'  => //,
  '.xml'  => /^\s*<!\-\-/,
  '.html' => /^\s*<!\-\-/,
  '.yaml' => /^\s*\#/,
  '.yml'  => /^\s*\#/
}
# Regular expressions to trim comments depending on the extension
TRIM = { 
  '.rb'   => [/^(\s+|\#)+/,     /(\s+|\#)+$/],
  '.py'   => [/^(\s+|\#)+/,     /(\s+|\#)+$/],
  '.java' => [/^(\s|\/|\*)+/,   /(\s|\/|\*)+$/],
  '.txt'  => [/^\s+/,           /\s+$/],
  '.xml'  => [/^(\s+|<!\-\-)+/, /(\-\->|\s+)+$/],
  '.html' => [/^(\s+|<!\-\-)+/, /(\-\->|\s+)+$/],
  '.yaml' => [/^(\s+|\#)+/,     /(\s+|\-)+$/],
  '.yml'  => [/^(\s+|\#)+/,     /(\s+|\-)+$/]
}

# Parse a given file and print notes:
# - filename is the name of the file to parse.
# Return: notes as a hash with notes for lines.
def parse(filename)
  notes = {}
  if filename.downcase =~ EXTS
    if File.file?(filename)
      File.open(filename, 'r') do |file|
        ext = filename[filename.rindex('.'), filename.length].downcase
        number = 1
        file.each do |line|
          if line =~ COMMENT[ext]
            if line.downcase =~ NOTE
              for pattern in TRIM[ext]
                line.sub!(pattern, '')
              end
              notes[number] = line
            end
          end
          number += 1
        end
      end
    end
  end
  return notes
end

# Return notes for all files in directory (and subdirectories).
# - directory: directory to look into.
def notes(directory)
  files = {}
  Find.find(directory) do |filename|
    if File.file?(filename)
      notes = parse(filename)
      if not notes.empty?
        files[filename] = notes
      end
    end
  end
  return files
end

# Print notes for a given directory.
# - directory: directory to look into.
def print_notes(directory)
  files = notes('.')
  for file in files.keys.sort
    if file =~ /^\.\/.*/
      filename = file.match(/^\.\/(.*)/)[1]
    end
    puts filename||file
    for line in files[file].keys.sort
      puts "  #{line}: #{files[file][line]}"
    end
  end
end
