class System < ApplicationRecord

  after_initialize :init

  has_many :activations, dependent: :destroy
  has_many :services, through: :activations
  has_many :repositories, -> { distinct }, through: :services
  has_many :products, -> { distinct }, through: :services
  has_one :hw_info, dependent: :destroy

  validates :login, uniqueness: { case_sensitive: false }

  def init
    self.login ||= System.generate_secure_login
    self.password ||= System.generate_secure_password
    self.registered_at ||= Time.zone.now
  end

  # Generate secure token for System login
  def self.generate_secure_login
    generated_login = nil
    # Generate a new login as long as it is not in use.
    while !generated_login || System.find_by(login: generated_login)
      # The login credentials has to have the prefix "SCC_" in order to recognize SCC authentication
      generated_login = "SCC_#{build_secure_token}"
    end
    generated_login
  end

  # Generate secure token for System password
  def self.generate_secure_password
    build_secure_token[0..15]
  end

  def self.build_secure_token
    SecureRandom.uuid.delete('-')
  end

  before_update do |system|
    # reset SCC sync timestamp so that the system can be re-synced on change
    system.scc_registered_at = nil
  end

  after_destroy do |system|
    if system.scc_system_id
      DeregisteredSystem.find_or_create_by(scc_system_id: system.scc_system_id)
    end

    # save the information for registration sharing
    peers = Settings[:regsharing][:peers] rescue nil
    _save_for_sharing(system.login, peers) if peers && _need_save?(caller_locations)
  end

  def _need_save?(call_data)
    call_data.each do |location|
      return false if location.absolute_path =~ /\bregistration_sharing\b/
    end

    true
  end

  def _save_for_sharing(login, peers)
    peers = (peers.class == String) ? [peers] : peers
    config_data_dir = Settings[:regsharing][:data_dir]
    peers.each do |peer|
      dirname = File.join(config_data_dir, peer)
      FileUtils.mkpath(dirname)

      filename = File.join(config_data_dir, peer, login)

      File.open(filename, 'w') do |f|
        f.flock(File::LOCK_EX)
        f.puts(Time.now.to_f.to_s)
      end
    end
  end

end
