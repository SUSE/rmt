require 'English'

class RMT::Gpg
  class RMT::Gpg::Exception < RuntimeError
  end

  def initialize(metadata_file:, key_file:, signature_file:, logger:)
    @metadata_file = metadata_file
    @key_file = key_file
    @signature_file = signature_file
    @logger = logger
  end

  def verify_signature
    @keyring = Tempfile.new('rmt-mirror-keyring')
    @keyring.close

    run_import_key
    run_verify_signature

    true
  ensure
    @keyring.unlink
  end

  protected

  def run_import_key
    cmd = "gpg --no-default-keyring --keyring #{@keyring.path} --import #{@key_file} 2>&1"
    out = `#{cmd}`

    if $CHILD_STATUS.exitstatus != 0
      @logger.debug "GPG command: #{cmd}"
      @logger.debug "GPG output: #{out}"
      raise RMT::Gpg::Exception.new(_('GPG key import failed'))
    end
  end

  def run_verify_signature
    cmd = "gpg --no-default-keyring --keyring #{@keyring.path} --verify #{@signature_file} #{@metadata_file} 2>&1"
    out = `#{cmd}`

    if $CHILD_STATUS.exitstatus != 0
      @logger.debug "GPG command: #{cmd}"
      @logger.debug "GPG output: #{out}"
      raise RMT::Gpg::Exception.new(_('GPG signature verification failed'))
    end
  end
end
