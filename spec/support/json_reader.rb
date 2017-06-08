def json_response
  JSON.parse(response.body, symbolize_names: true)
end
