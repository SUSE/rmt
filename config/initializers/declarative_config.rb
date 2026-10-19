Rails.application.config.after_initialize do
  if ActiveRecord::Base.connection.active? && ActiveRecord::Base.connection.table_exists?('products')
    DeclarativeConfigService.enforce!
  end
rescue ActiveRecord::NoDatabaseError, Mysql2::Error::ConnectionError
  Rails.logger.warn('Database not ready, skipping declarative configuration enforcement')
end
