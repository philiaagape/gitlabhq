# Helpers to send Git blobs or archives through Workhorse.
# Workhorse will also serve files when using `send_file`.
module WorkhorseHelper
  # Send a Git blob through Workhorse
  def send_git_blob(repository, blob)
    headers.store(*Gitlab::Workhorse.send_git_blob(repository, blob))
    headers['Content-Disposition'] = 'inline'
    headers['Content-Type'] = safe_content_type(blob)
    head :ok # 'render nothing: true' messes up the Content-Type
  end

  # Archive a Git repository and send it through Workhorse
  def send_git_archive(repository, ref:, format:)
    headers.store(*Gitlab::Workhorse.send_git_archive(repository, ref: ref, format: format))
    head :ok
  end
end
