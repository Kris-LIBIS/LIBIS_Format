require 'os'

require 'libis/tools/extend/string'
require 'libis/tools/logger'
require 'libis/tools/command'

require 'libis/format/config'

module Libis
  module Format
    module Tool

      class PdfMerge
        include ::Libis::Tools::Logger

        def self.run(source, target, options = [])
          self.new.run source, target, options
        end

        def run(source, target, options = [])
          source = [source] unless source.is_a?(Array)

          if OS.java?
            # TODO: import library and execute in current VM. For now do exactly as in MRI.
          end

          timeout = Libis::Format::Config[:timeouts][:pdf_merge]
          result = Libis::Tools::Command.run(
              Libis::Format::Config[:java_cmd],
              '-cp', Libis::Format::Config[:pdf_tool],
              'MergePdf',
              '--file_output', target,
              *options,
              *source,
              timeout: timeout,
              kill_after: timeout * 2
          )

          raise RuntimeError, "#{self.class} took too long (> #{timeout} seconds) to complete" if result[:timeout]
          raise RuntimeError, "#{self.class} errors: #{result[:err].join("\n")}" unless result[:status] == 0 && result[:err].empty?

          result
        end
      end

    end
  end
end
