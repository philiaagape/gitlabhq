require 'spec_helper'

describe Projects::BlameController do
  let(:project) { create(:project, :repository) }
  let(:user)    { create(:user) }

  before do
    sign_in(user)

    project.team << [user, :master]
    controller.instance_variable_set(:@project, project)
  end

  describe "GET show" do
    render_views

    before do
      get(:show,
          namespace_id: project.namespace.to_param,
          project_id: project.to_param,
          id: id)
    end

    context "valid file" do
      let(:id) { 'master/files/ruby/popen.rb' }
      it { is_expected.to respond_with(:success) }
    end

    context "invalid file" do
      let(:id) { 'master/files/ruby/missing_file.rb'}
      it { expect(response).to have_http_status(404) }
    end
  end
end
