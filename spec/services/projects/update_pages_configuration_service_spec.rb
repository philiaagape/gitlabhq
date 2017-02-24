require 'spec_helper'

describe Projects::UpdatePagesConfigurationService, services: true do
  let(:project) { create(:empty_project) }
  subject { described_class.new(project) }

  describe "#update" do
    let(:file) { Tempfile.new('pages-test') }

    after do
      file.close
      file.unlink
    end

    it 'updates the .update file' do
      # Access this reference to ensure scoping works
      Projects::Settings # rubocop:disable Lint/Void
      expect(subject).to receive(:pages_config_file).and_return(file.path)
      expect(subject).to receive(:reload_daemon).and_call_original

      expect(subject.execute).to eq({ status: :success })
    end
  end
end
