require 'spec_helper'

describe ChatMessage::IssueMessage, models: true do
  subject { described_class.new(args) }

  let(:args) do
    {
      user: {
        name: 'Test User',
        username: 'test.user'
      },
      project_name: 'project_name',
      project_url: 'http://somewhere.com',

      object_attributes: {
        title: 'Issue title',
        id: 10,
        iid: 100,
        assignee_id: 1,
        url: 'http://url.com',
        action: 'open',
        state: 'opened',
        description: 'issue description'
      }
    }
  end

  let(:color) { '#C95823' }

  context '#initialize' do
    before do
      args[:object_attributes][:description] = nil
    end

    it 'returns a non-null description' do
      expect(subject.description).to eq('')
    end
  end

  context 'open' do
    it 'returns a message regarding opening of issues' do
      expect(subject.pretext).to eq(
        '[<http://somewhere.com|project_name>] Issue opened by test.user')
      expect(subject.attachments).to eq([
        {
          title: "#100 Issue title",
          title_link: "http://url.com",
          text: "issue description",
          color: color,
        }
      ])
    end
  end

  context 'close' do
    before do
      args[:object_attributes][:action] = 'close'
      args[:object_attributes][:state] = 'closed'
    end

    it 'returns a message regarding closing of issues' do
      expect(subject.pretext). to eq(
        '[<http://somewhere.com|project_name>] Issue <http://url.com|#100 Issue title> closed by test.user')
      expect(subject.attachments).to be_empty
    end
  end
end
