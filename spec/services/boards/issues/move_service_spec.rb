require 'spec_helper'

describe Boards::Issues::MoveService, services: true do
  describe '#execute' do
    let(:user)    { create(:user) }
    let(:project) { create(:empty_project) }
    let(:board1)  { create(:board, project: project) }

    let(:bug) { create(:label, project: project, name: 'Bug') }
    let(:development) { create(:label, project: project, name: 'Development') }
    let(:testing)  { create(:label, project: project, name: 'Testing') }

    let!(:list1)   { create(:list, board: board1, label: development, position: 0) }
    let!(:list2)   { create(:list, board: board1, label: testing, position: 1) }
    let!(:done)    { create(:done_list, board: board1) }

    before do
      project.team << [user, :developer]
    end

    context 'when moving an issue between lists' do
      let(:issue)  { create(:labeled_issue, project: project, labels: [bug, development]) }
      let(:params) { { board_id: board1.id, from_list_id: list1.id, to_list_id: list2.id } }

      it 'delegates the label changes to Issues::UpdateService' do
        expect_any_instance_of(Issues::UpdateService).to receive(:execute).with(issue).once

        described_class.new(project, user, params).execute(issue)
      end

      it 'removes the label from the list it came from and adds the label of the list it goes to' do
        described_class.new(project, user, params).execute(issue)

        expect(issue.reload.labels).to contain_exactly(bug, testing)
      end
    end

    context 'when moving to done' do
      let(:board2) { create(:board, project: project) }
      let(:regression) { create(:label, project: project, name: 'Regression') }
      let!(:list3) { create(:list, board: board2, label: regression, position: 1) }

      let(:issue)  { create(:labeled_issue, project: project, labels: [bug, development, testing, regression]) }
      let(:params) { { board_id: board1.id, from_list_id: list2.id, to_list_id: done.id } }

      it 'delegates the close proceedings to Issues::CloseService' do
        expect_any_instance_of(Issues::CloseService).to receive(:execute).with(issue).once

        described_class.new(project, user, params).execute(issue)
      end

      it 'removes all list-labels from project boards and close the issue' do
        described_class.new(project, user, params).execute(issue)
        issue.reload

        expect(issue.labels).to contain_exactly(bug)
        expect(issue).to be_closed
      end
    end

    context 'when moving from done' do
      let(:issue)  { create(:labeled_issue, :closed, project: project, labels: [bug]) }
      let(:params) { { board_id: board1.id, from_list_id: done.id, to_list_id: list2.id } }

      it 'delegates the re-open proceedings to Issues::ReopenService' do
        expect_any_instance_of(Issues::ReopenService).to receive(:execute).with(issue).once

        described_class.new(project, user, params).execute(issue)
      end

      it 'adds the label of the list it goes to and reopen the issue' do
        described_class.new(project, user, params).execute(issue)
        issue.reload

        expect(issue.labels).to contain_exactly(bug, testing)
        expect(issue).to be_reopened
      end
    end

    context 'when moving to same list' do
      let(:issue)  { create(:labeled_issue, project: project, labels: [bug, development]) }
      let(:params) { { board_id: board1.id, from_list_id: list1.id, to_list_id: list1.id } }

      it 'returns false' do
        expect(described_class.new(project, user, params).execute(issue)).to eq false
      end

      it 'keeps issues labels' do
        described_class.new(project, user, params).execute(issue)

        expect(issue.reload.labels).to contain_exactly(bug, development)
      end
    end
  end
end