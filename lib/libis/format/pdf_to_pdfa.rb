require 'tempfile'
require 'csv'
require 'fileutils'

require 'libis/tools/extend/string'
require 'libis/tools/logger'
require 'libis/tools/command'

require 'libis/format'

module Libis
  module Format

    class PdfToPdfa
      include ::Libis::Tools::Logger

      def self.run(source, target = nil, options = {})
        self.new.run source, target, options
      end

      def run(source, target = nil, options = nil)

        target ||= File.join(Dir.tmpdir, Dir::Tmpname.make_tmpname([File.basename(source, '.*'), '.pdf']))

        icc_info = icc_options(options[:colorspace])

        icc_file = File.join(Dir.tmpdir, "#{icc_info[:icc_name]}#{Random.new.bytes(12).unpack('H*').first}.icc")
        FileUtils.cp(File.join(Libis::Format::DATA_DIR, "#{icc_info[:icc_name]}.icc"), icc_file)

        def_filename = File.join(Dir.tmpdir, "PDFA_def_#{Random.new.bytes(12).unpack('H*').first}.ps")
        File.open(def_filename, 'w') do |f|
          f.puts File.read(File.join(Libis::Format::DATA_DIR, 'PDFA_def.ps')).
                     gsub('[** Fill in ICC profile location **]', icc_file).
                     gsub('[** Fill in ICC reference name **]', icc_info[:icc_ref])
        end

        result = Libis::Tools::Command.run(
            Libis::Format::Config[:ghostscript_path],
            '-dBATCH', '-dNOPAUSE', '-dNOOUTERSAVE',
            '-sColorConversionStrategy=/UseDeviceIndependentColor',
            "-sProcessColorModel=#{icc_info[:device]}",
            '-sDEVICE=pdfwrite', '-dPDFA', '-dPDFACompatibilityPolicy=1',
            "-sOutputICCProfile=#{icc_file}",
            '-o', File.absolute_path(target),
            def_filename,
            source
        )

        FileUtils.rm [icc_file, def_filename].compact, force: true

        unless PdfaValidator.run(target)
          result[:status] = -999
          result[:err] << 'Failed to validate generated PDF/A file.'
        end

        result
      end


      private

      def icc_options(colorspace)
        case colorspace.to_s.downcase
          when 'cmyk'
            {icc_name: 'ISOcoated_v2_eci', icc_ref: 'FOGRA39L', device: 'DeviceCMYK'}
          else
            {icc_name: 'eciRGB_v2', icc_ref: 'sRGB', device: 'DeviceRGB'}
        end
      end

    end

  end
end
