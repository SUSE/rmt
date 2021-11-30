require 'rails_helper'

RSpec.describe RMT::Config do
  describe '#mirroring mirror_src' do
    context 'defaults' do
      [nil, ''].each do |config_provided|
        before { Settings['mirroring'].mirror_src = config_provided }
        it("defaults when supplied #{config_provided}") { expect(described_class.mirror_src_files?).to be_falsey }
      end
    end

    context 'true' do
      [true, 'true'].each do |config_provided|
        before { Settings['mirroring'].mirror_src = config_provided }
        it("defaults when supplied #{config_provided}") { expect(described_class.mirror_src_files?).to be_truthy }
      end
    end

    context 'false' do
      [false, 'false'].each do |config_provided|
        before { Settings['mirroring'].mirror_src = config_provided }
        it("defaults when supplied #{config_provided}") { expect(described_class.mirror_src_files?).to be_falsey }
      end
    end
  end

  describe '#mirroring dedup_method' do
    context 'defaults' do
      [nil, ''].each do |dedup_method|
        before { deduplication_method(dedup_method) }
        it("defaults when supplied #{dedup_method}") { expect(described_class.deduplication_by_hardlink?).to be_truthy }
      end
    end

    context 'hardlink' do
      [:hardlink, 'hardlink'].each do |dedup_method|
        before { deduplication_method(dedup_method) }
        it("uses hardlink with #{dedup_method} as #{dedup_method.class.name}") do
          expect(described_class.deduplication_by_hardlink?).to be_truthy
        end
      end
    end

    context 'copy' do
      [:copy, 'copy'].each do |dedup_method|
        before { deduplication_method(dedup_method) }
        it("uses copy with #{dedup_method} as #{dedup_method.class.name}") do
          expect(described_class.deduplication_by_hardlink?).to be_falsey
        end
      end
    end
  end

  describe '.web_server' do
    let(:default_config) do
      { max_threads: 5, min_threads: 5, workers: 2 }
    end

    context 'defaults' do
      shared_examples 'default web server config' do |config_provided|
        it 'returns the default configuration when none is provided' do
          Settings['web_server'] = config_provided

          expect(described_class.web_server).to have_attributes(default_config)
        end
      end

      include_examples 'default web server config', nil
      include_examples 'default web server config', ''
    end

    context 'valid configuration provided' do
      shared_examples 'valid web server config' do |config_provided|
        it 'returns the provided configuration' do
          Settings['web_server'] = Config::Options.new(config_provided)

          expect(described_class.web_server).to have_attributes(config_provided)
        end
      end

      include_examples 'valid web server config', { max_threads: 4,  min_threads: 4, workers: 3 }
      include_examples 'valid web server config', { max_threads: 9,  min_threads: 3, workers: 1 }
      include_examples 'valid web server config', { max_threads: 10, min_threads: 2, workers: 4 }
    end

    context 'invalid configuration provided' do
      shared_examples 'invalid web server configuration' do |config|
        it 'returns a config with default values instead of invalid ones' do
          config_provided = config.fetch(:provided)
          Settings['web_server'] = Config::Options.new(config_provided)

          expected_config = config_provided
            .merge(default_config.slice(*config.fetch(:invalid)))
            .transform_values(&:to_i)

          expect(described_class.web_server).to have_attributes(expected_config)
        end
      end

      include_examples 'invalid web server configuration', {
        provided: { max_threads: 0, min_threads: 0, workers: 0 },
        invalid: %i[max_threads min_threads workers]
      }
      include_examples 'invalid web server configuration', {
        provided: { max_threads: -1, min_threads: -1, workers: -1 },
        invalid: %i[max_threads min_threads workers]
      }
      include_examples 'invalid web server configuration', {
        provided: { max_threads: -1000, min_threads: -1000, workers: -1000 },
        invalid: %i[max_threads min_threads workers]
      }
      include_examples 'invalid web server configuration', {
        provided: { max_threads: 'a', min_threads: 'b', workers: 'c' },
        invalid: %i[max_threads min_threads workers]
      }
      include_examples 'invalid web server configuration', {
        provided: { max_threads: '', min_threads: '', workers: '' },
        invalid: %i[max_threads min_threads workers]
      }
      include_examples 'invalid web server configuration', {
        provided: { max_threads: nil, min_threads: nil, workers: nil },
        invalid: %i[max_threads min_threads workers]
      }
      include_examples 'invalid web server configuration', {
        provided: { max_threads: true, min_threads: 'true', workers: 2 },
        invalid: %i[max_threads min_threads]
      }
      include_examples 'invalid web server configuration', {
        provided: { max_threads: 'false', min_threads: false, workers: 2 },
        invalid: %i[max_threads min_threads]
      }
      include_examples 'invalid web server configuration', {
        provided: { max_threads: '10', min_threads: '3', workers: '0' },
        invalid: %i[workers]
      }
    end
  end

  describe '#host_system' do
    subject(:method_call) { described_class.send(:set_host_system!) }

    it 'returns an empty string when the credentials file does not exist' do
      allow(File).to receive(:exist?).with(RMT::CREDENTIALS_FILE_LOCATION).and_return(false)

      expect(method_call).to be_empty
    end

    it 'returns an empty string when the credentials file is not readable' do
      allow(File).to receive(:exist?).with(RMT::CREDENTIALS_FILE_LOCATION).and_return(true)
      allow(File).to receive(:readable?).with(RMT::CREDENTIALS_FILE_LOCATION).and_return(false)

      expect(method_call).to be_empty
    end

    it 'returns the proper string when the credentials file is readable and the contents are as expected' do
      allow(File).to receive(:exist?).with(RMT::CREDENTIALS_FILE_LOCATION).and_return(true)
      allow(File).to receive(:readable?).with(RMT::CREDENTIALS_FILE_LOCATION).and_return(true)
      allow(File).to receive(:foreach).with(RMT::CREDENTIALS_FILE_LOCATION).and_yield('username=12341234')

      expect(method_call).to eq('12341234')
    end

    it 'returns an empty string when the credentials file is readable but the contents are not as expected' do
      allow(File).to receive(:exist?).with(RMT::CREDENTIALS_FILE_LOCATION).and_return(true)
      allow(File).to receive(:readable?).with(RMT::CREDENTIALS_FILE_LOCATION).and_return(true)
      allow(File).to receive(:foreach).with(RMT::CREDENTIALS_FILE_LOCATION).and_yield('whatever=12341234')

      expect(method_call).to be_empty
    end
  end
end
