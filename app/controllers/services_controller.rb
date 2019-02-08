require 'rmt'
require 'rmt/misc'
require 'active_support/builder'

class ServicesController < ApplicationController

  include ActionController::MimeResponds

  before_action :authenticate_system, only: %w[legacy_service]

  ZYPPER_SERVICE_TTL = 86400

  def show
    service = Service.find(params[:id])
    repos = service.repositories

    builder = Builder::XmlMarkup.new
    service_xml = builder.repoindex(ttl: ZYPPER_SERVICE_TTL) do
      repos.each do |repo|
        attributes = {
          url: make_repo_url(request.base_url, repo.local_path, service.name),
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

  def legacy_service
    repos = Repository.joins(services: :activations).where('activations.system_id' => @system.id, mirroring_enabled: true)

    builder = Builder::XmlMarkup.new
    service_xml = builder.repoindex do
      repos.each do |repo|
        attributes = {
          url: make_repo_url(
            request.base_url,
            repo.local_path,
            RMT::Misc.make_smt_service_name(request.base_url)
          ),
          alias: repo.name,
          name: repo.name,
          autorefresh: repo.autorefresh,
          enabled: repo.enabled
        }

        builder.repo attributes
      end
    end

    render xml: service_xml
  end

  protected

  # overridden by ZypperAuth plugin
  def make_repo_url(base_url, repo_local_path, service_name)
    RMT::Misc.make_repo_url(base_url, repo_local_path, service_name)
  end

end
