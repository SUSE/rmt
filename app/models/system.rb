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
  end
end
