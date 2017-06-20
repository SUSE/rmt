class RepositoriesServicesAssociation < ApplicationRecord

  self.table_name = 'repositories_services'

  belongs_to :repository
  belongs_to :service

end
