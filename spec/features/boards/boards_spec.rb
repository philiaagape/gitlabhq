require 'rails_helper'

describe 'Issue Boards', feature: true, js: true do
  include WaitForAjax
  include WaitForVueResource
  include DragTo

  let(:project) { create(:empty_project, :public) }
  let(:board)   { create(:board, project: project) }
  let(:user)    { create(:user) }
  let!(:user2)  { create(:user) }

  before do
    project.team << [user, :master]
    project.team << [user2, :master]

    login_as(user)
  end

  context 'no lists' do
    before do
      visit namespace_project_board_path(project.namespace, project, board)
      wait_for_vue_resource
      expect(page).to have_selector('.board', count: 2)
    end

    it 'shows blank state' do
      expect(page).to have_content('Welcome to your Issue Board!')
    end

    it 'disables add issues button by default' do
      button = page.find('.issue-boards-search button', text: 'Add issues')

      expect(button[:disabled]).to eq true
    end

    it 'hides the blank state when clicking nevermind button' do
      page.within(find('.board-blank-state')) do
        click_button("Nevermind, I'll use my own")
      end
      expect(page).to have_selector('.board', count: 1)
    end

    it 'creates default lists' do
      lists = ['To Do', 'Doing', 'Done']

      page.within(find('.board-blank-state')) do
        click_button('Add default lists')
      end
      wait_for_vue_resource

      expect(page).to have_selector('.board', count: 3)

      page.all('.board').each_with_index do |list, i|
        expect(list.find('.board-title')).to have_content(lists[i])
      end
    end
  end

  context 'with lists' do
    let(:milestone) { create(:milestone, project: project) }

    let(:planning)    { create(:label, project: project, name: 'Planning', description: 'Test') }
    let(:development) { create(:label, project: project, name: 'Development') }
    let(:testing)     { create(:label, project: project, name: 'Testing') }
    let(:bug)         { create(:label, project: project, name: 'Bug') }
    let!(:backlog)    { create(:label, project: project, name: 'Backlog') }
    let!(:done)       { create(:label, project: project, name: 'Done') }
    let!(:accepting)  { create(:label, project: project, name: 'Accepting Merge Requests') }

    let!(:list1) { create(:list, board: board, label: planning, position: 0) }
    let!(:list2) { create(:list, board: board, label: development, position: 1) }

    let!(:confidential_issue) { create(:labeled_issue, :confidential, project: project, author: user, labels: [planning]) }
    let!(:issue1) { create(:labeled_issue, project: project, assignee: user, labels: [planning]) }
    let!(:issue2) { create(:labeled_issue, project: project, author: user2, labels: [planning]) }
    let!(:issue3) { create(:labeled_issue, project: project, labels: [planning]) }
    let!(:issue4) { create(:labeled_issue, project: project, labels: [planning]) }
    let!(:issue5) { create(:labeled_issue, project: project, labels: [planning], milestone: milestone) }
    let!(:issue6) { create(:labeled_issue, project: project, labels: [planning, development]) }
    let!(:issue7) { create(:labeled_issue, project: project, labels: [development]) }
    let!(:issue8) { create(:closed_issue, project: project) }
    let!(:issue9) { create(:labeled_issue, project: project, labels: [planning, testing, bug, accepting]) }

    before do
      visit namespace_project_board_path(project.namespace, project, board)

      wait_for_vue_resource

      expect(page).to have_selector('.board', count: 3)
      expect(find('.board:nth-child(1)')).to have_selector('.card')
      expect(find('.board:nth-child(2)')).to have_selector('.card')
      expect(find('.board:nth-child(3)')).to have_selector('.card')
    end

    it 'shows lists' do
      expect(page).to have_selector('.board', count: 3)
    end

    it 'shows description tooltip on list title' do
      page.within('.board:nth-child(1)') do
        expect(find('.board-title span.has-tooltip')[:title]).to eq('Test')
      end
    end

    it 'shows issues in lists' do
      wait_for_board_cards(1, 8)
      wait_for_board_cards(2, 2)
    end

    it 'shows confidential issues with icon' do
      page.within(find('.board', match: :first)) do
        expect(page).to have_selector('.confidential-icon', count: 1)
      end
    end

    it 'search done list' do
      page.within('#js-boards-search') do
        find('.form-control').set(issue8.title)
      end

      wait_for_vue_resource

      expect(find('.board:nth-child(1)')).to have_selector('.card', count: 0)
      expect(find('.board:nth-child(2)')).to have_selector('.card', count: 0)
      expect(find('.board:nth-child(3)')).to have_selector('.card', count: 1)
    end

    it 'search list' do
      page.within('#js-boards-search') do
        find('.form-control').set(issue5.title)
      end

      wait_for_vue_resource

      expect(find('.board:nth-child(1)')).to have_selector('.card', count: 1)
      expect(find('.board:nth-child(2)')).to have_selector('.card', count: 0)
      expect(find('.board:nth-child(3)')).to have_selector('.card', count: 0)
    end

    it 'allows user to delete board' do
      page.within(find('.board:nth-child(1)')) do
        find('.board-delete').click
      end

      wait_for_vue_resource

      expect(page).to have_selector('.board', count: 2)
    end

    it 'removes checkmark in new list dropdown after deleting' do
      click_button 'Add list'
      wait_for_ajax

      page.within(find('.board:nth-child(1)')) do
        find('.board-delete').click
      end

      wait_for_vue_resource

      expect(page).to have_selector('.board', count: 2)
    end

    it 'infinite scrolls list' do
      50.times do
        create(:labeled_issue, project: project, labels: [planning])
      end

      visit namespace_project_board_path(project.namespace, project, board)
      wait_for_vue_resource

      page.within(find('.board', match: :first)) do
        expect(page.find('.board-header')).to have_content('58')
        expect(page).to have_selector('.card', count: 20)
        expect(page).to have_content('Showing 20 of 58 issues')

        evaluate_script("document.querySelectorAll('.board .board-list')[0].scrollTop = document.querySelectorAll('.board .board-list')[0].scrollHeight")
        wait_for_vue_resource

        expect(page).to have_selector('.card', count: 40)
        expect(page).to have_content('Showing 40 of 58 issues')

        evaluate_script("document.querySelectorAll('.board .board-list')[0].scrollTop = document.querySelectorAll('.board .board-list')[0].scrollHeight")
        wait_for_vue_resource

        expect(page).to have_selector('.card', count: 58)
        expect(page).to have_content('Showing all issues')
      end
    end

    context 'done' do
      it 'shows list of done issues' do
        wait_for_board_cards(3, 1)
        wait_for_ajax
      end

      it 'moves issue to done' do
        drag(list_from_index: 0, list_to_index: 2)

        wait_for_board_cards(1, 7)
        wait_for_board_cards(2, 2)
        wait_for_board_cards(3, 2)

        expect(find('.board:nth-child(1)')).not_to have_content(issue9.title)
        expect(find('.board:nth-child(3)')).to have_selector('.card', count: 2)
        expect(find('.board:nth-child(3)')).to have_content(issue9.title)
        expect(find('.board:nth-child(3)')).not_to have_content(planning.title)
      end

      it 'removes all of the same issue to done' do
        drag(list_from_index: 0, list_to_index: 2)

        wait_for_board_cards(1, 7)
        wait_for_board_cards(2, 2)
        wait_for_board_cards(3, 2)

        expect(find('.board:nth-child(1)')).not_to have_content(issue9.title)
        expect(find('.board:nth-child(3)')).to have_content(issue9.title)
        expect(find('.board:nth-child(3)')).not_to have_content(planning.title)
      end
    end

    context 'lists' do
      it 'changes position of list' do
        drag(list_from_index: 1, list_to_index: 0, selector: '.board-header')

        wait_for_board_cards(1, 2)
        wait_for_board_cards(2, 8)
        wait_for_board_cards(3, 1)

        expect(find('.board:nth-child(1)')).to have_content(development.title)
        expect(find('.board:nth-child(1)')).to have_content(planning.title)
      end

      it 'issue moves between lists' do
        drag(list_from_index: 0, from_index: 1, list_to_index: 1)

        wait_for_board_cards(1, 7)
        wait_for_board_cards(2, 2)
        wait_for_board_cards(3, 1)

        expect(find('.board:nth-child(2)')).to have_content(issue6.title)
        expect(find('.board:nth-child(2)').all('.card').last).not_to have_content(development.title)
      end

      it 'issue moves between lists' do
        drag(list_from_index: 1, list_to_index: 0)

        wait_for_board_cards(1, 9)
        wait_for_board_cards(2, 1)
        wait_for_board_cards(3, 1)

        expect(find('.board:nth-child(1)')).to have_content(issue7.title)
        expect(find('.board:nth-child(1)').all('.card').first).not_to have_content(planning.title)
      end

      it 'issue moves from done' do
        drag(list_from_index: 2, list_to_index: 1)

        expect(find('.board:nth-child(2)')).to have_content(issue8.title)

        wait_for_board_cards(1, 8)
        wait_for_board_cards(2, 3)
        wait_for_board_cards(3, 0)
      end

      context 'issue card' do
        it 'shows assignee' do
          page.within(find('.board', match: :first)) do
            expect(page).to have_selector('.avatar', count: 1)
          end
        end
      end

      context 'new list' do
        it 'shows all labels in new list dropdown' do
          click_button 'Add list'
          wait_for_ajax

          page.within('.dropdown-menu-issues-board-new') do
            expect(page).to have_content(planning.title)
            expect(page).to have_content(development.title)
            expect(page).to have_content(testing.title)
          end
        end

        it 'creates new list for label' do
          click_button 'Add list'
          wait_for_ajax

          page.within('.dropdown-menu-issues-board-new') do
            click_link testing.title
          end

          wait_for_vue_resource

          expect(page).to have_selector('.board', count: 4)
        end

        it 'creates new list for Backlog label' do
          click_button 'Add list'
          wait_for_ajax

          page.within('.dropdown-menu-issues-board-new') do
            click_link backlog.title
          end

          wait_for_vue_resource

          expect(page).to have_selector('.board', count: 4)
        end

        it 'creates new list for Done label' do
          click_button 'Add list'
          wait_for_ajax

          page.within('.dropdown-menu-issues-board-new') do
            click_link done.title
          end

          wait_for_vue_resource

          expect(page).to have_selector('.board', count: 4)
        end

        it 'keeps dropdown open after adding new list' do
          click_button 'Add list'
          wait_for_ajax

          page.within('.dropdown-menu-issues-board-new') do
            click_link done.title
          end

          wait_for_vue_resource

          expect(find('.issue-boards-search')).to have_selector('.open')
        end

        it 'creates new list from a new label' do
          click_button 'Add list'

          wait_for_ajax

          click_link 'Create new label'

          fill_in('new_label_name', with: 'Testing New Label')

          first('.suggest-colors a').click

          click_button 'Create'

          wait_for_ajax
          wait_for_vue_resource

          expect(page).to have_selector('.board', count: 4)
        end
      end
    end

    context 'filtering' do
      it 'filters by author' do
        page.within '.issues-filters' do
          click_button('Author')
          wait_for_ajax

          page.within '.dropdown-menu-author' do
            click_link(user2.name)
          end
          wait_for_vue_resource

          expect(find('.js-author-search')).to have_content(user2.name)
        end

        wait_for_vue_resource
        wait_for_board_cards(1, 1)
        wait_for_empty_boards((2..3))
      end

      it 'filters by assignee' do
        page.within '.issues-filters' do
          click_button('Assignee')
          wait_for_ajax

          page.within '.dropdown-menu-assignee' do
            click_link(user.name)
          end
          wait_for_vue_resource

          expect(find('.js-assignee-search')).to have_content(user.name)
        end

        wait_for_vue_resource

        wait_for_board_cards(1, 1)
        wait_for_empty_boards((2..3))
      end

      it 'filters by milestone' do
        page.within '.issues-filters' do
          click_button('Milestone')
          wait_for_ajax

          page.within '.milestone-filter' do
            click_link(milestone.title)
          end
          wait_for_vue_resource

          expect(find('.js-milestone-select')).to have_content(milestone.title)
        end

        wait_for_vue_resource
        wait_for_board_cards(1, 1)
        wait_for_board_cards(2, 0)
        wait_for_board_cards(3, 0)
      end

      it 'filters by label' do
        page.within '.issues-filters' do
          click_button('Label')
          wait_for_ajax

          page.within '.dropdown-menu-labels' do
            click_link(testing.title)
            wait_for_vue_resource
            find('.dropdown-menu-close').click
          end
        end

        wait_for_vue_resource
        wait_for_board_cards(1, 1)
        wait_for_empty_boards((2..3))
      end

      it 'filters by label with space after reload' do
        page.within '.issues-filters' do
          click_button('Label')
          wait_for_ajax

          page.within '.dropdown-menu-labels' do
            click_link(accepting.title)
            wait_for_vue_resource(spinner: false)
            find('.dropdown-menu-close').click
          end
        end

        # Test after reload
        page.evaluate_script 'window.location.reload()'

        wait_for_vue_resource

        page.within(find('.board', match: :first)) do
          expect(page.find('.board-header')).to have_content('1')
          expect(page).to have_selector('.card', count: 1)
        end

        page.within(find('.board:nth-child(2)')) do
          expect(page.find('.board-header')).to have_content('0')
          expect(page).to have_selector('.card', count: 0)
        end
      end

      it 'removes filtered labels' do
        wait_for_vue_resource

        page.within '.labels-filter' do
          click_button('Label')
          wait_for_ajax

          page.within '.dropdown-menu-labels' do
            click_link(testing.title)
            wait_for_vue_resource(spinner: false)
          end

          expect(page).to have_css('input[name="label_name[]"]', visible: false)

          page.within '.dropdown-menu-labels' do
            click_link(testing.title)
            wait_for_vue_resource(spinner: false)
          end

          expect(page).not_to have_css('input[name="label_name[]"]', visible: false)
        end
      end

      it 'infinite scrolls list with label filter' do
        50.times do
          create(:labeled_issue, project: project, labels: [planning, testing])
        end

        page.within '.issues-filters' do
          click_button('Label')
          wait_for_ajax

          page.within '.dropdown-menu-labels' do
            click_link(testing.title)
            wait_for_vue_resource
            find('.dropdown-menu-close').click
          end
        end

        wait_for_vue_resource

        page.within(find('.board', match: :first)) do
          expect(page.find('.board-header')).to have_content('51')
          expect(page).to have_selector('.card', count: 20)
          expect(page).to have_content('Showing 20 of 51 issues')

          evaluate_script("document.querySelectorAll('.board .board-list')[0].scrollTop = document.querySelectorAll('.board .board-list')[0].scrollHeight")

          expect(page).to have_selector('.card', count: 40)
          expect(page).to have_content('Showing 40 of 51 issues')

          evaluate_script("document.querySelectorAll('.board .board-list')[0].scrollTop = document.querySelectorAll('.board .board-list')[0].scrollHeight")

          expect(page).to have_selector('.card', count: 51)
          expect(page).to have_content('Showing all issues')
        end
      end

      it 'filters by multiple labels' do
        page.within '.issues-filters' do
          click_button('Label')
          wait_for_ajax

          page.within(find('.dropdown-menu-labels')) do
            click_link(testing.title)
            wait_for_vue_resource
            click_link(bug.title)
            wait_for_vue_resource
            find('.dropdown-menu-close').click
          end
        end

        wait_for_vue_resource

        wait_for_board_cards(1, 1)
        wait_for_empty_boards((2..3))
      end

      it 'filters by clicking label button on issue' do
        page.within(find('.board', match: :first)) do
          expect(page).to have_selector('.card', count: 8)
          expect(find('.card', match: :first)).to have_content(bug.title)
          click_button(bug.title)
          wait_for_vue_resource
        end

        wait_for_vue_resource

        wait_for_board_cards(1, 1)
        wait_for_empty_boards((2..3))

        page.within('.labels-filter') do
          expect(find('.dropdown-toggle-text')).to have_content(bug.title)
        end
      end

      it 'removes label filter by clicking label button on issue' do
        page.within(find('.board', match: :first)) do
          page.within(find('.card', match: :first)) do
            click_button(bug.title)
          end
          wait_for_vue_resource

          expect(page).to have_selector('.card', count: 1)
        end

        wait_for_vue_resource

        page.within('.labels-filter') do
          expect(find('.dropdown-toggle-text')).to have_content(bug.title)
        end
      end
    end
  end

  context 'keyboard shortcuts' do
    before do
      visit namespace_project_board_path(project.namespace, project, board)
      wait_for_vue_resource
    end

    it 'allows user to use keyboard shortcuts' do
      find('.boards-list').native.send_keys('i')
      expect(page).to have_content('New Issue')
    end
  end

  context 'signed out user' do
    before do
      logout
      visit namespace_project_board_path(project.namespace, project, board)
      wait_for_vue_resource
    end

    it 'displays lists' do
      expect(page).to have_selector('.board')
    end

    it 'does not show create new list' do
      expect(page).not_to have_selector('.js-new-board-list')
    end

    it 'does not allow dragging' do
      expect(page).not_to have_selector('.user-can-drag')
    end
  end

  context 'as guest user' do
    let(:user_guest) { create(:user) }

    before do
      project.team << [user_guest, :guest]
      logout
      login_as(user_guest)
      visit namespace_project_board_path(project.namespace, project, board)
      wait_for_vue_resource
    end

    it 'does not show create new list' do
      expect(page).not_to have_selector('.js-new-board-list')
    end
  end

  def drag(selector: '.board-list', list_from_index: 0, from_index: 0, to_index: 0, list_to_index: 0)
    drag_to(selector: selector,
            scrollable: '#board-app',
            list_from_index: list_from_index,
            from_index: from_index,
            to_index: to_index,
            list_to_index: list_to_index)
  end

  def wait_for_board_cards(board_number, expected_cards)
    page.within(find(".board:nth-child(#{board_number})")) do
      expect(page.find('.board-header')).to have_content(expected_cards.to_s)
      expect(page).to have_selector('.card', count: expected_cards)
    end
  end

  def wait_for_empty_boards(board_numbers)
    board_numbers.each do |board|
      wait_for_board_cards(board, 0)
    end
  end
end
