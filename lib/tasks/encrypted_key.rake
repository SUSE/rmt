namespace :rmt do
  namespace :secrets do
    desc 'Create encryption key for Rails secrets'
    task create_encryption_key: :environment do
      require "rails/generators/rails/encryption_key_file/encryption_key_file_generator"

      Rails::Generators::EncryptionKeyFileGenerator
        .new.add_key_file("config/secrets.yml.key")
    end

    desc 'Create the `secret_key_base` for Rails'
    task create_secret_key_base: :environment do
      Rails::Secrets.write(
        { 'production' => {'secret_key_base' => SecureRandom.hex(64) } }.to_yaml
      )
    end
  end
end
