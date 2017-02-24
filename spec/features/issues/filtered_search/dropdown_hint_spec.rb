require 'rails_helper'

describe 'Dropdown hint', js: true, feature: true do
  include WaitForAjax

  let!(:project) { create(:empty_project) }
  let!(:user) { create(:user) }
  let(:filtered_search) { find('.filtered-search') }
  let(:js_dropdown_hint) { '#js-dropdown-hint' }

  def dropdown_hint_size
    page.all('#js-dropdown-hint .filter-dropdown .filter-dropdown-item').size
  end

  def click_hint(text)
    find('#js-dropdown-hint .filter-dropdown .filter-dropdown-item', text: text).click
  end

  before do
    project.team << [user, :master]
    login_as(user)
    create(:issue, project: project)

    visit namespace_project_issues_path(project.namespace, project)
  end

  describe 'behavior' do
    before do
      expect(page).to have_css(js_dropdown_hint, visible: false)
      filtered_search.click
    end

    it 'opens when the search bar is first focused' do
      expect(page).to have_css(js_dropdown_hint, visible: true)
    end

    it 'closes when the search bar is unfocused' do
      find('body').click

      expect(page).to have_css(js_dropdown_hint, visible: false)
    end
  end

  describe 'filtering' do
    it 'does not filter `Keep typing and press Enter`' do
      filtered_search.set('randomtext')

      expect(page).to have_css(js_dropdown_hint, text: 'Keep typing and press Enter', visible: false)
      expect(dropdown_hint_size).to eq(0)
    end

    it 'filters with text' do
      filtered_search.set('a')

      expect(dropdown_hint_size).to eq(3)
    end
  end

  describe 'selecting from dropdown with no input' do
    before do
      filtered_search.click
    end

    it 'opens the author dropdown when you click on author' do
      click_hint('author')

      expect(page).to have_css(js_dropdown_hint, visible: false)
      expect(page).to have_css('#js-dropdown-author', visible: true)
      expect(filtered_search.value).to eq('author:')
    end

    it 'opens the assignee dropdown when you click on assignee' do
      click_hint('assignee')

      expect(page).to have_css(js_dropdown_hint, visible: false)
      expect(page).to have_css('#js-dropdown-assignee', visible: true)
      expect(filtered_search.value).to eq('assignee:')
    end

    it 'opens the milestone dropdown when you click on milestone' do
      click_hint('milestone')

      expect(page).to have_css(js_dropdown_hint, visible: false)
      expect(page).to have_css('#js-dropdown-milestone', visible: true)
      expect(filtered_search.value).to eq('milestone:')
    end

    it 'opens the label dropdown when you click on label' do
      click_hint('label')

      expect(page).to have_css(js_dropdown_hint, visible: false)
      expect(page).to have_css('#js-dropdown-label', visible: true)
      expect(filtered_search.value).to eq('label:')
    end
  end

  describe 'selecting from dropdown with some input' do
    it 'opens the author dropdown when you click on author' do
      filtered_search.set('auth')
      click_hint('author')

      expect(page).to have_css(js_dropdown_hint, visible: false)
      expect(page).to have_css('#js-dropdown-author', visible: true)
      expect(filtered_search.value).to eq('author:')
    end

    it 'opens the assignee dropdown when you click on assignee' do
      filtered_search.set('assign')
      click_hint('assignee')

      expect(page).to have_css(js_dropdown_hint, visible: false)
      expect(page).to have_css('#js-dropdown-assignee', visible: true)
      expect(filtered_search.value).to eq('assignee:')
    end

    it 'opens the milestone dropdown when you click on milestone' do
      filtered_search.set('mile')
      click_hint('milestone')

      expect(page).to have_css(js_dropdown_hint, visible: false)
      expect(page).to have_css('#js-dropdown-milestone', visible: true)
      expect(filtered_search.value).to eq('milestone:')
    end

    it 'opens the label dropdown when you click on label' do
      filtered_search.set('lab')
      click_hint('label')

      expect(page).to have_css(js_dropdown_hint, visible: false)
      expect(page).to have_css('#js-dropdown-label', visible: true)
      expect(filtered_search.value).to eq('label:')
    end
  end
end
