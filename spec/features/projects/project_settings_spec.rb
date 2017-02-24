require 'spec_helper'

describe 'Edit Project Settings', feature: true do
  let(:user) { create(:user) }
  let(:project) { create(:empty_project, path: 'gitlab', name: 'sample') }

  before do
    login_as(user)
    project.team << [user, :master]
  end

  describe 'Project settings', js: true do
    it 'shows errors for invalid project name' do
      visit edit_namespace_project_path(project.namespace, project)

      fill_in 'project_name_edit', with: 'foo&bar'

      click_button 'Save changes'

      expect(page).to have_field 'project_name_edit', with: 'foo&bar'
      expect(page).to have_content "Name can contain only letters, digits, emojis, '_', '.', dash, space. It must start with letter, digit, emoji or '_'."
      expect(page).to have_button 'Save changes'
    end

    scenario 'shows a successful notice when the project is updated' do
      visit edit_namespace_project_path(project.namespace, project)

      fill_in 'project_name_edit', with: 'hello world'

      click_button 'Save changes'

      expect(page).to have_content "Project 'hello world' was successfully updated."
    end
  end

  describe 'Rename repository' do
    it 'shows errors for invalid project path/name' do
      visit edit_namespace_project_path(project.namespace, project)

      fill_in 'project_name', with: 'foo&bar'
      fill_in 'Path', with: 'foo&bar'

      click_button 'Rename project'

      expect(page).to have_field 'Project name', with: 'foo&bar'
      expect(page).to have_field 'Path', with: 'foo&bar'
      expect(page).to have_content "Name can contain only letters, digits, emojis, '_', '.', dash, space. It must start with letter, digit, emoji or '_'."
      expect(page).to have_content "Path can contain only letters, digits, '_', '-' and '.'. Cannot start with '-', end in '.git' or end in '.atom'"
    end
  end

  describe 'Rename repository name with emojis' do
    it 'shows error for invalid project name' do
      visit edit_namespace_project_path(project.namespace, project)

      fill_in 'project_name', with: '🚀 foo bar ☁️'

      click_button 'Rename project'

      expect(page).to have_field 'Project name', with: '🚀 foo bar ☁️'
      expect(page).not_to have_content "Name can contain only letters, digits, emojis '_', '.', dash and space. It must start with letter, digit, emoji or '_'."
    end
  end
end
