# encoding: utf-8

require_relative 'base'

require 'libis/format/tool/pdf_watermark'

module Libis
  module Format
    module Converter

      class PdfWatermarkerHeader < Libis::Format::Converter::Base

        def self.input_types
          [:PDF]
        end

        def self.output_types(format = nil)
          return [] unless input_types.include?(format) if format
          [:PDF]
        end

        def pdf_watermark_header(_)
          #force usage of this converter
        end

        def initialize
          super
        end

        def text(v)
          @options[:text] = v.blank? ? nil : v
        end

        def convert(source, target, format, opts = {})
          super

          result = convert_pdf(source, target)
          return nil unless result

          result

        end

        # noinspection DuplicatedCode
        def convert_pdf(source, target)

          using_temp(target) do |tmpname|
            result = Libis::Format::Tool::PdfWatermark.run(
                source, tmpname, 'header',
                @options.map {|k, v|
                  if v.nil?
                    nil
                  else
                    ["--#{k}", v.to_s]
                  end
                  }.compact.flatten
            )
            unless result[:err].empty?
              error("Pdf conversion encountered errors:\n%s", result[:err].join(join("\n")))
              next nil
            end
            tmpname
          end

        end

      end

    end
  end
end
