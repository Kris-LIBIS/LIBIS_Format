# coding: utf-8

require_relative 'base'

module LIBIS
  module Format
    module Converter

      class AudioConverter < Base

        private

        TYPES = [:WAV, :MP3, :FLAC, :OGG]

        protected

        def self.input_types
          TYPES
        end

        def self.output_types
          TYPES
        end

        def init(source)
          puts "Initializing #{self.class} with '#{source}'"
        end

        def do_convert(target, format)
          puts "#{self.class}::do_convert(#{target},#{format}) not implemented yet."
        end

      end
    end
  end
end
