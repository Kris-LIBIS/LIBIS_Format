# encoding: utf-8

require_relative 'base'

require 'libis/format/tool/pdf_split'

module Libis
  module Format
    module Converter

      # noinspection DuplicatedCode
      class PdfSplitter < Libis::Format::Converter::Base

        def self.input_types
          [:PDF]
        end

        def self.output_types(format = nil)
          return [] unless input_types.include?(format) if format
          [:PDFA]
        end

        def self.category
          :splitter
        end

        def initialize
          super
        end

        # Split at given page. If omitted, nil or 0, the source PDF will be split at every page
        def page(v)
          @options[:page] = v unless v.blank?
        end

        def convert(source, target, format, opts = {})
          super

          result = split(source, target)
          return nil unless result

          result
        end

        private

        def split(source, target)

          result = Libis::Format::Tool::PdfSplit.run(
            source, target,
            @options.map { |k, v|
              if v.nil?
                nil
              else
                ["--#{k}", v.to_s]
              end }.compact.flatten
          )
          unless result[:err].empty?
            error("Pdf split encountered errors:\n%s", result[:err].join(join("\n")))
            return nil
          end
          result[:out]

        end

      end

    end
  end
end