class Api::Connect::V4::Systems::ProductsController < ApplicationController
  respond_to :json

  def activate
    render json: {"name"=>"SMT-potato",
                  "product"=>
                      {"id"=>0,
                       "repositories"=>
                           [
                           ],

                  },
                  "url"=>"http://potato?credentials=potato",
                  "id"=>1,
                  "obsoleted_service_name"=>"SMT-potato"}
  end
end
