shared_context 'version header' do |version|
  let(:version_header) { { 'Accept' => "application/vnd.scc.suse.com.v#{version}+json" } }
end

shared_context 'auth header' do |login_object, login_method, password_method|
  let(:auth_header) do
    basic_auth_header send(login_object).send(login_method), send(login_object).send(password_method)
  end
end
