class GlobalMilestone
  include Milestoneish

  EPOCH = DateTime.parse('1970-01-01')

  attr_accessor :title, :milestones
  alias_attribute :name, :title

  def for_display
    @first_milestone
  end

  def self.build_collection(projects, params)
    child_milestones = MilestonesFinder.new.execute(projects, params)

    milestones = child_milestones.select(:id, :title).group_by(&:title).map do |title, grouped|
      milestones_relation = Milestone.where(id: grouped.map(&:id))
      new(title, milestones_relation)
    end

    milestones.sort_by { |milestone| milestone.due_date || EPOCH }
  end

  def self.build(projects, title)
    child_milestones = Milestone.of_projects(projects).where(title: title)
    return if child_milestones.blank?

    new(title, child_milestones)
  end

  def initialize(title, milestones)
    @title = title
    @name = title
    @milestones = milestones
    @first_milestone = milestones.find {|m| m.description.present? } || milestones.first
  end

  def milestoneish_ids
    milestones.select(:id)
  end

  def safe_title
    @title.to_slug.normalize.to_s
  end

  def projects
    @projects ||= Project.for_milestones(milestoneish_ids)
  end

  def state
    milestones.each do |milestone|
      return 'active' if milestone.state != 'closed'
    end

    'closed'
  end

  def active?
    state == 'active'
  end

  def closed?
    state == 'closed'
  end

  def issues
    @issues ||= Issue.of_milestones(milestoneish_ids).includes(:project, :assignee, :labels)
  end

  def merge_requests
    @merge_requests ||= MergeRequest.of_milestones(milestoneish_ids).includes(:target_project, :assignee, :labels)
  end

  def participants
    @participants ||= milestones.includes(:participants).map(&:participants).flatten.compact.uniq
  end

  def labels
    @labels ||= GlobalLabel.build_collection(milestones.includes(:labels).map(&:labels).flatten)
                           .sort_by!(&:title)
  end

  def due_date
    return @due_date if defined?(@due_date)

    @due_date =
      if @milestones.all? { |x| x.due_date == @milestones.first.due_date }
        @milestones.first.due_date
      end
  end

  def start_date
    return @start_date if defined?(@start_date)

    @start_date =
      if @milestones.all? { |x| x.start_date == @milestones.first.start_date }
        @milestones.first.start_date
      end
  end
end
