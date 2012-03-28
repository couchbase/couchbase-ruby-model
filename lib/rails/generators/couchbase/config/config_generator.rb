# encoding: utf-8
#
# Author:: Couchbase <info@couchbase.com>
# Copyright:: 2012 Couchbase, Inc.
# License:: Apache License, Version 2.0
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
#

require 'rails/generators/couchbase_generator'

module Couchbase
  module Generators
    class ConfigGenerator < Rails::Generators::Base
      desc "Creates a Couchbase configuration file at config/couchbase.yml"

      argument :database_name, :type => :string, :optional => true

      def self.source_root
        @_couchbase_source_root ||= File.expand_path("../templates", __FILE__)
      end

      def app_name
        Rails::Application.subclasses.first.parent.to_s.underscore
      end

      def create_config_file
        template 'couchbase.yml', File.join('config', "couchbase.yml")
      end

    end
  end
end
