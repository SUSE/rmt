class ApplicationSerializer < ActiveModel::Serializer

  include Rails.application.routes.url_helpers

  def base_url
    instance_options.fetch(:base_url)
  end

end
