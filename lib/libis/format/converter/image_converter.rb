# encoding: utf-8

require_relative 'base'
require 'libis/format/identifier'

require 'mini_magick'

MiniMagick.configure do |config|
  config.debug = false
end

module Libis
  module Format
    module Converter

      class ImageConverter < Libis::Format::Converter::Base

        def self.input_types(format = nil)
          [:TIFF, :JPG, :PNG, :BMP, :GIF, :JP2, :PDF]
        end

        def self.output_types(_ = nil)
          [:TIFF, :JPG, :PNG, :BMP, :GIF, :JP2, :PDF]
        end

        def initialize
          @wm_image = nil
          super
        end

        def imaginate(_)
          #force usage of this converter
        end

        def scale(percent)
          @options[:scale] = percent
        end

        def resize(geometry)
          @options[:resize] = geometry
        end

        def quality(value)
          @options[:quality] = value
        end

        def dpi(value)
          @options[:density] = value
        end

        def resample(value)
          @options[:density] = value
        end

        def flatten
          @flags[:flatten] = true
        end

        def colorspace(value)
          @options[:colorspace] = value
        end

        # Create or use a watermark image.
        #
        # The watermark options are:
        #     - file: watermark image to use
        #     - text: text to create a watermark from
        #     - rotation: rotation of the watermark text (counter clockwise in degrees; integer number) - default 30
        #     - size: size of the watermark (integer > 0, 1/n of image size) - default 4
        #     - opacity: opacity of the watermark (fraction 0.0 - 1.0) - default 0.3
        #     - gap: size of the gap between watermark instances. Fractions as percentage of widht/height. - default 0.2
        # If both options are given, the file will be used as-is if it exists and is a valid image file. Otherwise the
        # file will be created or overwritten with a newly created watermark image.
        #
        # The created watermark file will be a PNG image with transparent background containing the supplied text
        # slanted by 30 degrees counter-clockwise.
        #
        # @param [Hash] options Hash of options for watermark creation.
        def watermark(options = {})
          text = options[:text] || '© LIBIS'
          image = options[:file] || (Dir::Tmpname.create(%w(wm_image .png)) { |_|})
          @wm_size = (options[:size] || '4').to_int
          @wm_opacity = ((options[:opacity] || 0.1).to_f * 100).to_int
          @wm_composition = options[:composition] || 'modulate'
          gap = ((options[:gap] || 0.2).to_f * 100).to_int
          rotation = 360 - (options[:rotation] || 30).to_i
          @wm_image = MiniMagick::Image.new(image)
          unless @wm_image.valid?
            # noinspection RubyResolve
            MiniMagick::Tool::Convert.new do |convert|
              # noinspection RubyLiteralArrayInspection
              convert.background 'transparent'
              convert.size('2000x2000')
              convert.gravity 'Center'
              convert.font('Helvetica').fill('black').pointsize(72) #.stroke('black').strokewidth(1)
              convert << "label:#{text}"
              convert.rotate rotation
              convert.trim.repage.+
              convert.bordercolor('transparent').border("#{gap}%")
              convert << image
            end
            if options[:file]
              @wm_image = MiniMagick::Image.new(image)
            else
              @wm_image = MiniMagick::Image.open(image)
              File.delete(image)
            end
            # noinspection RubyResolve
            unless @wm_image.valid?
              error "Problem creating watermark image '#{image}'."
              @wm_image = nil
            end
          end
        end

        def convert(source, target, format, opts = {})
          super

          if source.is_a? Array
            sources = source

            unless [:PDF, :TIFF, :GIF, :PBM, :PGM, :PPM].include? format
              error 'Can ony assemble multiple images into multi-page/layer format'
              return nil
            end

            assemble_and_convert(sources, target, format)

          elsif File.directory?(source)
            sources = Dir[File.join(source, '**', '*')].reject { |p| File.directory? p }

            unless [:TIFF, :PDF].include? format
              error 'Can ony assemble multiple images into multi-page/layer format'
              return nil
            end

            assemble_and_convert(sources, target, format)

          else

            image = MiniMagick::Image.new(source)

            if image.pages.size > 1
              assemble_and_convert(image.pages.map {|page| page.path}, target, format)
            else
              convert_image(source, target, format)
            end
          end

          target

        end

        def assemble_and_convert(sources, target, format)
          converted_pages = sources.inject([]) do |list, path|
            converted = Tempfile.new(['page-', ".#{Libis::Format::TypeDatabase.type_extentions(format).first}"])
            convert_image(path, converted.path, format)
            list << converted
          end
          MiniMagick::Tool::Convert.new do |b|
            converted_pages.each { |page| b << page.path }
            b << target
          end
          converted_pages.each do |temp_file|
            temp_file.close
            temp_file.unlink
          end
        end

        protected

        def convert_image(source, target, format)

          image = MiniMagick::Image.new(source)

          MiniMagick::Tool::Convert.new do |convert|
            if @wm_image
              convert << @wm_image.path
              convert.filter('Lagrange')
              convert.resize("#{image.width / @wm_size}x#{image.height / @wm_size}").write('mpr:watermark').delete.+
            end

            convert << source
            convert.flatten if format == :JPG
            if @wm_image
              # noinspection RubyResolve
              convert.stack do |stack|
                stack.size("#{image.width}x#{image.height}")
                stack << 'xc:transparent'
                stack.tile('mpr:watermark')
                stack.draw "rectangle 0,0,#{image.width},#{image.height}"
              end
              convert.compose(@wm_composition).define("compose:args=#{@wm_opacity}").composite
            end

            @options.each { |o, v| convert.send(o, v) }
            @flags.each { |f, v| v.is_a?(FalseClass) ? convert.send(f).+ : convert.send(f) }

            convert.format(format)
            convert << target
          end

          target

        end

      end

    end
  end
end