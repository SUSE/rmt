# frozen_string_literal: true

require 'yabeda'
require 'yabeda/prometheus'
require 'prometheus/client/push'

module Yabeda
  module PrometheusPatch
    def patched_push_gateway(grouping_key: {})
      @push_gateway ||= # rubocop:disable Naming/MemoizedInstanceVariableName
        ::Prometheus::Client::Push.new(
          job: Settings.scc.metrics.job_name,
          gateway:Settings.scc.metrics.url,
          grouping_key: grouping_key,
          open_timeout: 5, read_timeout: 30
        )
    end

    def self.apply!(mod)
      mod.extend(self)
    end
  end
end

Yabeda::PrometheusPatch.apply!(Yabeda::Prometheus)