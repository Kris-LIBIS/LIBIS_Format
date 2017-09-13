# encoding: utf-8

require 'singleton'

require 'libis-tools'
require 'libis/tools/extend/string'
require 'libis/tools/extend/empty'

require 'libis/format/type_database'

require_relative 'fido'
require_relative 'droid'

module Libis
  module Format

    class BulkIdentifier
      include ::Libis::Tools::Logger
      include Singleton

      attr_reader :xml_validations

      protected

      def result_ok?(result, who_is_asking = nil)
        result = ::Libis::Format::TypeDatabase.enrich(result, PUID: :puid, MIME: :mimetype)
        return false if result.empty?
        return true unless result[:TYPE].empty?
        return false if RETRY_MIMETYPES.include? result[:mimetype]
        return false if FIDO_FAILURES.include? result[:mimetype] and who_is_asking == :DROID
        !(result[:mimetype].empty? and result[:puid].empty?)
      end

      def get_puid(mimetype)
        ::Libis::Format::TypeDatabase.mime_infos(mimetype).first[:PUID].first rescue nil
      end

      public

      def self.add_fido_format(f)
        ::Libis::Format::Fido.add_format f
      end

      def self.add_xml_validation(mimetype, xsd_file)
        instance.xml_validations[mimetype] = xsd_file
      end

      def self.xml_validations
        instance.xml_validations
      end

      def self.get(file_path)
        instance.get file_path
      end

      def get_list(filelist, options = nil)

      end

      def get_dir(dir, recursive = true, options = nil)

      end

      def get(file, options = nil)

        unless File.exists? file
          error 'File %s cannot be found.', file
          return nil
        end

        if File.directory? file
          return get_dir(file, false, options)
        end

        result = {messages: []}

        result =

        # use FIDO
        # Note: FIDO does not always do a good job, mainly due to lacking container inspection.
        # FIDO misses should be registered in
        result = get_fido_identification(file, result, options[:formats]) unless options[:droid]

        # use DROID
        result = get_droid_identification file, result

        # use FILE
        result = get_file_identification(file, result)

        # Try file extension
        result = get_extension_identification(file, result)

        # determine XML type. Add custom types at runtime with
        # Libis::Tools::Format::Identifier.add_xml_validation('my_type', '/path/to/my_type.xsd')
        result = validate_against_xml_schema(file, result)

        result[:mimetype] ?
            log_msg(result, :info, "Identification of '#{file}': '#{result}'") :
            log_msg(result, :warn, "Could not identify MIME type of '#{file}'")
      end

      def get_fido_identification(file, result = {})
        fido_result = ::Libis::Format::Fido.run(file)

        return result unless fido_result.is_a? Hash

        result.merge! fido_result
        result[:method] = 'fido'

        log_msg(result, :debug, "Fido MIME-type: #{result[:mimetype]} (PRONOM UID: #{result[:puid]})")
      end

      def get_droid_identification(file, result = {})
        return result if result_ok? result, :DROID
        droid_output = ::Libis::Format::Droid.run file
        result[:messages] << [:debug, "DROID: #{droid_output}"]
        warn 'Droid found multiple matches; using first match only' if droid_output.size > 1
        result.clear
        droid_output = droid_output.first
        result[:mimetype] = droid_output[:mime_type].to_s.split(/[\s,]+/).find { |x| x =~ /.*\/.*/ }
        result[:matchtype] = droid_output[:method]
        result[:puid] = droid_output[:puid]
        result[:format_name] = droid_output[:format_name]
        result[:format_version] = droid_output[:format_version]
        result[:method] = 'droid'

        log_msg(result, :debug, "Droid MIME-type: #{result[:mimetype]} (PRONOM UID: #{result[:puid]})")
      end

      def get_file_identification(file, result = nil)
        return result if result_ok? result
        begin
          output = ::Libis::Tools::Command.run('file', '-b', '--mime-type', "\"#{file.escape_for_string}\"")[:err]
          mimetype = output.strip.split
          if mimetype
            log_msg(result, :debug, "File result: '#{mimetype}'")
            result[:mimetype] = mimetype
            result[:puid] = get_puid(mimetype)
          end
          result[:method] = 'file'
        rescue Exception
          # ignored
        end
        result
      end

      def get_extension_identification(file, result = nil)
        return result if result_ok? result
        info = ::Libis::Format::TypeDatabase.ext_infos(File.extname(file)).first
        log_msg result, :debug, "File extension info: #{info}"
        if info
          result[:mimetype] = info[:MIME].first rescue nil
          result[:puid] = info[:PUID].first rescue nil
        end
        result[:method] = 'extension'
        result
      end

      def validate_against_xml_schema(file, result)
        return result unless result[:mimetype] =~ /^(text|application)\/xml$/
        doc = ::Libis::Tools::XmlDocument.open file
        xml_validations.each do |mime, xsd_file|
          next unless xsd_file
          begin
            if doc.validates_against?(xsd_file)
              log_msg result, :debug, "XML file validated against XML Schema: #{xsd_file}"
              result[:mimetype] = mime
              result[:puid] = nil
              result = ::Libis::Format::TypeDatabase.enrich(result, PUID: :puid, MIME: :mimetype)
            end
          rescue
            # Do nothing - probably Nokogiri chrashed during validation.
            # Could have many causes (remote schema: firewall, network, link rot, ...; schema syntax error; ...)
            # so we just ignore and continue.
          end
        end
        result
      end

      private

      def log_msg(result, severity, text)
        return {} unless result.is_a?(Hash)
        (result[:messages] ||= []) << [severity, text]
        result
      end

    end

  end
end
