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

require 'thread'

module Couchbase

  class Model

    # Generator of CouchDB specfic UUIDs. This is the ruby implementation of
    # couch_uuids.erl from couchdb distribution. It is threadsafe.
    #
    # @since 0.0.1

    class UUID
      # Get default UUID generator. You can create your own if you like.
      #
      # @since 0.0.1
      #
      # @return [UUID]
      def self.generator
        @generator ||= UUID.new
      end

      # Initialize generator.
      #
      # @since 0.0.1
      #
      # @param [Fixnum] seed seed for pseudorandom number generator.
      def initialize(seed = nil)
        seed ? srand(seed) : srand
        @prefix, _ = rand_bytes(13).unpack('H26')
        @inc = rand(0xfff) + 1
        @lock = Mutex.new
      end

      # Generate list of UUIDs.
      #
      # @since 0.0.1
      #
      # @param [Fixnum] count number of UUIDs you need
      #
      # @param [Symbol] algorithm Algorithm to use. Known algorithms:
      #   [:random]
      #     128 bits of random awesome. All awesome, all the time.
      #   [:sequential]
      #     Monotonically increasing ids with random increments.  First 26 hex
      #     characters are random. Last 6 increment in random amounts until an
      #     overflow occurs. On overflow, the random prefix is regenerated and
      #     the process starts over.
      #   [:utc_random]
      #     Time since Jan 1, 1970 UTC with microseconds. First 14 characters
      #     are the time in hex. Last 18 are random.
      #
      # @return [String, Array] single string value or array of strings. Where
      #   each value represents 128-bit number written in hexadecimal format.
      def next(count = 1, algorithm = :sequential)
        raise ArgumentError, 'count should be a positive number' unless count > 0
        uuids = case algorithm
                when :random
                  rand_bytes(16 * count).unpack('H32' * count)
                when :utc_random
                  now = Time.now.utc
                  prefix = '%014x' % [now.to_i * 1_000_000 + now.usec]
                  rand_bytes(9 * count).unpack('H18' * count).map do |tail|
                    "#{prefix}#{tail}"
                  end
                when :sequential
                  (1..count).map{ next_seq }
                else
                  raise ArgumentError, "Unknown algorithm #{algo}. Should be one :sequential, :random or :utc_random"
                end
        uuids.size == 1 ? uuids[0] : uuids
      end

      private

      def next_seq
        @lock.synchronize do
          if @inc >= 0xfff000
            @prefix, _ = rand_bytes(13).unpack('H26')
            @inc = rand(0xfff) + 1
          end
          @inc += rand(0xfff) + 1
          '%s%06x' % [@prefix, @inc]
        end
      end

      def rand_bytes(count)
        bytes = ''
        count.times { bytes << rand(256) }
        bytes
      end

    end

  end

end
