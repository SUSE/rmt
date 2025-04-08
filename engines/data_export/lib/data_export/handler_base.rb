class DataExport::HandlerBase
  def self.inherited(child_class) # rubocop:disable Lint/MissingSuper
    DataExport.handler = child_class
  end

  def initialize(system, request, params, logger)
    @system = system
    @request = request
    @params = params
    @logger = logger
  end
end
