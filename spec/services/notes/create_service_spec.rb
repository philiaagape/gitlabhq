require 'spec_helper'

describe Notes::CreateService, services: true do
  let(:project) { create(:empty_project) }
  let(:issue) { create(:issue, project: project) }
  let(:user) { create(:user) }
  let(:opts) do
    { note: 'Awesome comment', noteable_type: 'Issue', noteable_id: issue.id }
  end

  describe '#execute' do
    before do
      project.team << [user, :master]
    end

    context "valid params" do
      it 'returns a valid note' do
        note = described_class.new(project, user, opts).execute

        expect(note).to be_valid
      end

      it 'returns a persisted note' do
        note = described_class.new(project, user, opts).execute

        expect(note).to be_persisted
      end

      it 'note has valid content' do
        note = described_class.new(project, user, opts).execute

        expect(note.note).to eq(opts[:note])
      end

      it 'note belongs to the correct project' do
        note = described_class.new(project, user, opts).execute

        expect(note.project).to eq(project)
      end

      it 'TodoService#new_note is called' do
        note = build(:note, project: project)
        allow(Note).to receive(:new).with(opts) { note }

        expect_any_instance_of(TodoService).to receive(:new_note).with(note, user)

        described_class.new(project, user, opts).execute
      end

      it 'enqueues NewNoteWorker' do
        note = build(:note, id: 999, project: project)
        allow(Note).to receive(:new).with(opts) { note }

        expect(NewNoteWorker).to receive(:perform_async).with(note.id)

        described_class.new(project, user, opts).execute
      end
    end

    describe 'note with commands' do
      describe '/close, /label, /assign & /milestone' do
        let(:note_text) { %(HELLO\n/close\n/assign @#{user.username}\nWORLD) }

        it 'saves the note and does not alter the note text' do
          expect_any_instance_of(Issues::UpdateService).to receive(:execute).and_call_original

          note = described_class.new(project, user, opts.merge(note: note_text)).execute

          expect(note.note).to eq "HELLO\nWORLD"
        end
      end

      describe '/merge with sha option' do
        let(:note_text) { %(HELLO\n/merge\nWORLD) }
        let(:params) { opts.merge(note: note_text, merge_request_diff_head_sha: 'sha') }

        it 'saves the note and exectues merge command' do
          note = described_class.new(project, user, params).execute

          expect(note.note).to eq "HELLO\nWORLD"
        end
      end
    end

    describe 'personal snippet note' do
      subject { described_class.new(nil, user, params).execute }

      let(:snippet) { create(:personal_snippet) }
      let(:params) do
        { note: 'comment', noteable_type: 'Snippet', noteable_id: snippet.id }
      end

      it 'returns a valid note' do
        expect(subject).to be_valid
      end

      it 'returns a persisted note' do
        expect(subject).to be_persisted
      end

      it 'note has valid content' do
        expect(subject.note).to eq(params[:note])
      end
    end
  end

  describe "award emoji" do
    before do
      project.team << [user, :master]
    end

    it "creates an award emoji" do
      opts = {
        note: ':smile: ',
        noteable_type: 'Issue',
        noteable_id: issue.id
      }
      note = described_class.new(project, user, opts).execute

      expect(note).to be_valid
      expect(note.name).to eq('smile')
    end

    it "creates regular note if emoji name is invalid" do
      opts = {
        note: ':smile: moretext:',
        noteable_type: 'Issue',
        noteable_id: issue.id
      }
      note = described_class.new(project, user, opts).execute

      expect(note).to be_valid
      expect(note.note).to eq(opts[:note])
    end

    it "normalizes the emoji name" do
      opts = {
        note: ':+1:',
        noteable_type: 'Issue',
        noteable_id: issue.id
      }

      expect_any_instance_of(TodoService).to receive(:new_award_emoji).with(issue, user)

      described_class.new(project, user, opts).execute
    end
  end
end
