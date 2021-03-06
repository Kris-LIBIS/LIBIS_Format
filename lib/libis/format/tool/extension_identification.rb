require_relative 'identification_tool'

module Libis
  module Format
    module Tool

      class ExtensionIdentification < Libis::Format::Tool::IdentificationTool

        def run_list(filelist, _options = {})

          output = runner(nil, filelist)

          process_output(output)

        end

        def run_dir(dir, recursive = true, _options = {})

          filelist = find_files(dir, recursive)

          output = runner(nil, filelist)

          process_output(output)

        end

        def run(file, _options)

          output = runner(file)

          process_output(output)

        end

        protected

        def runner(*args)

          args.map do |file|
            info = ::Libis::Format::TypeDatabase.ext_infos(File.extname(file)).first
            if info
              {
                  filepath: file,
                  mimetype: (info[:MIME].first rescue nil),
                  puid: (info[:PUID].first rescue nil),
                  matchtype: 'extension',
                  tool: :type_database
              }
            end
          end.cleanup

        end

      end

    end
  end
end