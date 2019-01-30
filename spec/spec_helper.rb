require 'coveralls'
Coveralls.wear!

require 'bundler/setup'
Bundler.setup

require 'rspec'
require 'libis-format'
require 'libis-tools'

require 'chromaprint'

def data_dir
  @data_dir ||= (ENV['DATA_DIR'] ||  File.join(File.absolute_path(File.dirname(__FILE__)), 'data'))
end

Libis::Format::Config << ENV['CONFIG_FILE'] if ENV['CONFIG_FILE']

RSpec::Matchers.define(:be_same_file_as) do |exected_file_path|
  match do |actual_file_path|
    expect(md5_hash(actual_file_path)).to eq md5_hash(exected_file_path)
  end

  def md5_hash(file_path)
    Digest::MD5.hexdigest(File.read(file_path))
  end
end

RSpec::Matchers.define :sound_like do |exp_file, threshold, rate, channels|
  match do |tgt_file|
    Libis::Format::Converter::AudioConverter.sounds_like(exp_file, tgt_file, threshold, rate, channels)
  end
end
