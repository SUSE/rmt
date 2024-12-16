require 'English'
require 'fileutils'
require 'tmpdir'
require 'shellwords'

class RMT::GPG
  class RMT::GPG::Exception < RuntimeError
  end

  def initialize(metadata_file:, key_file:, signature_file:, logger:)
    @metadata_file = metadata_file
    @key_file = key_file
    @signature_file = signature_file
    @logger = logger
  end

  def verify_signature
    @tmpdir = Dir.mktmpdir('rmt-mirror-gpg')
    @keyring = File.join(@tmpdir, 'keyring')

    run_import_key
    run_verify_signature

    true
  ensure
    FileUtils.rm_rf(@tmpdir)
  end

  protected

  def run_import_key
    cmd = "gpg --homedir #{@tmpdir.shellescape} --no-default-keyring " \
      "--keyring #{@keyring.shellescape} --import #{@key_file.shellescape} 2>&1"
    out = `#{cmd}`

    if $CHILD_STATUS.exitstatus != 0
      @logger.warn "GPG command failed with #{$CHILD_STATUS.exitstatus}: #{cmd}"
      @logger.warn "GPG output: #{out}"
      raise RMT::GPG::Exception.new(_('GPG key import failed'))
    end
  end

  def run_verify_signature
    cmd = "gpg --homedir #{@tmpdir.shellescape} --no-default-keyring " \
      "--keyring #{@keyring.shellescape} --verify #{@signature_file.shellescape} #{@metadata_file.shellescape} 2>&1"
    out = `#{cmd}`

    if $CHILD_STATUS.exitstatus != 0
      @logger.warn "GPG command: #{cmd}"
      @logger.warn "GPG output: #{out}"
      raise RMT::GPG::Exception.new(_('GPG signature verification failed'))
    end
  end
end
