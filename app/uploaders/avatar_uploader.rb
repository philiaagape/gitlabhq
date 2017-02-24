class AvatarUploader < GitlabUploader
  include UploaderHelper

  storage :file

  def store_dir
    "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end

  def exists?
    model.avatar.file && model.avatar.file.exists?
  end

  # We set move_to_store and move_to_cache to 'false' to prevent stealing
  # the avatar file from a project when forking it.
  # https://gitlab.com/gitlab-org/gitlab-ce/issues/26158
  def move_to_store
    false
  end

  def move_to_cache
    false
  end
end
