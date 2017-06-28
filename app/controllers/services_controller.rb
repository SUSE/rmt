class ServicesController < ActionController::Base

  include ActionController::MimeResponds

  def show
    # TODO: add optional authentication?

    @service    = Service.find(params[:id])
    @repos      = @service.repositories
    @expires_at = nil

    render :xml, template: 'services/show.xml.builder'

  rescue ActiveRecord::RecordNotFound
    untranslated = N_('Requested service not found')
    render(xml: { error: untranslated, localized_error: _(untranslated) }, status: 404) and return
  end

end
