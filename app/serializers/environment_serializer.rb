class EnvironmentSerializer < BaseSerializer
  Item = Struct.new(:name, :size, :latest)

  entity EnvironmentEntity

  def within_folders
    tap { @itemize = true }
  end

  def with_pagination(request, response)
    tap { @paginator = Gitlab::Serializer::Pagination.new(request, response) }
  end

  def itemized?
    @itemize
  end

  def paginated?
    @paginator.present?
  end

  def represent(resource, opts = {})
    if itemized?
      itemize(resource).map do |item|
        { name: item.name,
          size: item.size,
          latest: super(item.latest, opts) }
      end
    else
      resource = @paginator.paginate(resource) if paginated?

      super(resource, opts)
    end
  end

  private

  def itemize(resource)
    items = resource.order('folder_name ASC')
      .group('COALESCE(environment_type, name)')
      .select('COALESCE(environment_type, name) AS folder_name',
              'COUNT(*) AS size', 'MAX(id) AS last_id')

    # It makes a difference when you call `paginate` method, because
    # although `page` is effective at the end, it calls counting methods
    # immediately.
    items = @paginator.paginate(items) if paginated?

    environments = resource.where(id: items.map(&:last_id)).index_by(&:id)

    items.map do |item|
      Item.new(item.folder_name, item.size, environments[item.last_id])
    end
  end
end
