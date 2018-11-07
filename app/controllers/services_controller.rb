require 'rmt'
require 'rmt/misc'
require 'active_support/builder'

class ServicesController < ApplicationController

  include ActionController::MimeResponds

  ZYPPER_SERVICE_TTL = 86400

  def show
    @service    = Service.find(params[:id])
    @repos      = @service.repositories
    @expires_at = nil
    @base_url   = request.base_url

    builder = Builder::XmlMarkup.new
    service_xml = builder.repoindex(ttl: ZYPPER_SERVICE_TTL) do
      @repos.each do |repo|
        attributes = {
          url: RMT::Misc.make_repo_url(@base_url, repo.local_path),
          alias: repo.name,
          name: repo.name,
          autorefresh: repo.autorefresh,
          enabled: repo.enabled
        }

        builder.repo attributes
      end
    end

    render xml: service_xml
  rescue ActiveRecord::RecordNotFound
    untranslated = N_('Requested service not found')
    render(xml: { error: untranslated, localized_error: _(untranslated) }, status: 404) and return
  end

end
