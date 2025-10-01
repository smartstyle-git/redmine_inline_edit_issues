module InlineIssuesHelper
  include CustomFieldsHelper
  include ProjectsHelper

  def inline_project_id
    @project.present? ? @project.id : ""
  end

  def column_form_content(column, issue, f)
    if column.class.name == "QueryCustomFieldColumn"
      custom_field_values = issue.editable_custom_field_values
      value = custom_field_values.detect { |cfv| cfv.custom_field_id == column.custom_field.id }
      custom_field_tag :issues, value, issue, f if value.present?
    else
      case column.name
      when :tracker
        f.select :tracker_id, issue.project.trackers.collect { |t| [t.name, t.id] }
      when :status
        f.select :status_id, issue.new_statuses_allowed_to.collect { |p| [p.name, p.id] }
      when :priority
        f.select :priority_id, @priorities.collect { |p| [p.name, p.id] }
      when :subject
        f.text_field :subject, size: 20
      when :assigned_to
        f.select :assigned_to_id, principals_options_for_select(issue.assignable_users, issue.assigned_to), :include_blank => true
      when :estimated_hours
        f.text_field :estimated_hours, size: 3
      when :start_date
        f.date_field(:start_date, size: 8) +
            calendar_for('issues_' + issue.id.to_s + '_start_date')
      when :due_date
        f.date_field(:due_date, size: 8) +
            calendar_for('issues_' + issue.id.to_s + '_due_date')
      when :done_ratio
        f.select :done_ratio, ((0..10).to_a.collect { |r| ["#{r * 10} %", r * 10] })
      when :is_private
        f.check_box :is_private
      when :description
        f.text_area :description
      when :category
        f.select :category_id, [["", ""]] + issue.project.issue_categories.collect { |t| [t.name, t.id] }
      when :fixed_version
        f.select :fixed_version_id, [["", ""]] + issue.project.versions.collect { |t| [t.name, t.id] }
      when :relations
        render_issue_relations_form(issue, f)
      else
        column_display_text(column, issue)
      end
    end
  end

  def column_display_text(column, issue)
    begin
      value = column.value(issue)
    rescue NoMethodError => e
      # Redmine 6 compatibility: Handle dot-notation columns like 'parent.subject'
      value = column.value_object(issue) if column.respond_to?(:value_object)
      value ||= ''
    end

    case value.class.name
    when 'Time'
      format_time(value)
    when 'Date'
      format_date(value)
    when 'Float'
      sprintf "%.2f", value
    when 'TrueClass'
      l(:general_text_Yes)
    when 'FalseClass'
      l(:general_text_No)
    else
      h(value)
    end
  end

  def column_total(column, issues)
    case column.name
    when :estimated_hours
      totalEstHours(issues)
    when :spent_hours
      totalSpentHours(issues)
    end
  end

  def group_column_total(column, issues, group)
    case column.name
    when :estimated_hours
      totalGroupEstHours(issues, group)
    when :spent_hours
      totalGroupSpentHours(issues, group)
    end
  end

  def inline_edit_condition
    cond = "issues.id in (#{@ids.map { |i| i.to_i }.join(',')})"
  end

  def group_class_name(group)
    begin
      if group.present?
        # strip out white spaces from the group name
        "group_" + group.name.gsub(/\s+/, "")
      else
        ""
      end
    rescue
      ""
    end
  end

  def group_total_name(group, column)
    if group.present? && column.present?
      "#{group_class_name(group)}_total_#{column.name}"
    else
      ""
    end
  end

  def render_issue_relations_form(issue, f)
    content = ''.html_safe
    
    # Display existing relations with delete checkboxes
    issue.relations.each do |relation|
      other_issue = relation.other_issue(issue)
      next unless other_issue && other_issue.visible?
      
      relation_label = "#{l(relation.label_for(issue))} ##{other_issue.id}"
      checkbox_name = "issues[#{issue.id}][delete_relation_ids][]"
      
      content << content_tag(:div, class: 'relation-item') do
        check_box_tag(checkbox_name, relation.id, false, id: "issue_#{issue.id}_delete_relation_#{relation.id}") +
        label_tag("issue_#{issue.id}_delete_relation_#{relation.id}", "#{l(:button_delete)} #{relation_label}")
      end
    end
    
    # Get available issues for the datalist
    available_issues = Issue.visible
                            .where(project_id: issue.project_id)
                            .where.not(id: issue.id)
                            .order(id: :desc)
                            .limit(500)
                            .pluck(:id, :subject)
    
    datalist_id = "issue_#{issue.id}_available_issues"
    
    # Add new relation fields
    content << content_tag(:div, class: 'add-relation') do
      select_html = select_tag(
        "issues[#{issue.id}][new_relation_type]",
        options_for_select([
          ['', ''],
          [l(:label_relates_to), IssueRelation::TYPE_RELATES],
          [l(:label_duplicates), IssueRelation::TYPE_DUPLICATES],
          [l(:label_duplicated_by), IssueRelation::TYPE_DUPLICATED],
          [l(:label_blocks), IssueRelation::TYPE_BLOCKS],
          [l(:label_blocked_by), IssueRelation::TYPE_BLOCKED],
          [l(:label_precedes), IssueRelation::TYPE_PRECEDES],
          [l(:label_follows), IssueRelation::TYPE_FOLLOWS],
          [l(:label_copied_to), IssueRelation::TYPE_COPIED_TO],
          [l(:label_copied_from), IssueRelation::TYPE_COPIED_FROM]
        ]),
        class: 'relation-type'
      )
      
      issue_field = text_field_tag(
        "issues[#{issue.id}][new_relation_issue_id]",
        '',
        placeholder: '#123',
        size: 12,
        class: 'relation-issue-id',
        list: datalist_id
      )
      
      datalist = content_tag(:datalist, id: datalist_id) do
        available_issues.map do |id, subject|
          content_tag(:option, value: id) do
            "##{id} - #{subject.truncate(50)}"
          end
        end.join.html_safe
      end
      
      select_html + ' ' + issue_field + datalist
    end
    
    content
  end

  private

  def totalEstHours(issues)
    estTotal = 0
    issues.each { |i| estTotal += i.estimated_hours if i.estimated_hours.present? }
    sprintf "%.2f", estTotal
  end

  def totalSpentHours(issues)
    spentTotal = 0
    issues.each { |i| spentTotal += i.spent_hours if i.spent_hours.present? }
    sprintf "%.2f", spentTotal
  end

  def totalGroupEstHours(issues, group)
    estTotal = 0
    issues.each do |i|
      if i.estimated_hours.present? && @query.group_by_column.value(i) == group
        estTotal += i.estimated_hours
      end
    end
    sprintf "%.2f", estTotal
  end

  def totalGroupSpentHours(issues, group)
    spentTotal = 0
    issues.each do |i|
      if i.spent_hours.present? && @query.group_by_column.value(i) == group
        spentTotal += i.spent_hours
      end
    end
    sprintf "%.2f", spentTotal
  end


  #####
  # Return custom field html tag corresponding to its format
  #####
  def custom_field_tag(name, custom_value, issue, f)
    custom_field = custom_value.custom_field
    field_name = "#{name}[#{issue.id}][custom_field_values][#{custom_field.id}]"
    field_name << "[]" if custom_field.multiple?
    field_id = "#{name}_custom_field_values_#{custom_field.id}"

    tag_options = {:id => field_id, :class => "#{custom_field.field_format}_cf"}

    field_format = Redmine::FieldFormat.find(custom_field.field_format)

    case custom_field.field_format
    when "attachment"
      #render :partial => 'attachments/form', :locals => {:container => issue}
    when "user"
      assignable_users = (issue.project.assignable_users.to_a + [issue.project.default_assigned_to]).uniq.compact
      blank_option = content_tag('option', "--- #{l(:actionview_instancetag_blank_option)} ---", :value => '')
      select_tag(field_name, blank_option + principals_options_for_select(assignable_users, custom_value.value))
    when "version"
      blank_option = content_tag('option', "--- #{l(:actionview_instancetag_blank_option)} ---", :value => '')
      select_tag(field_name, blank_option + version_options_for_select(issue.assignable_versions, custom_value.value))
    when "date"
      date_field_tag(field_name, custom_value.value, tag_options.merge(:size => 10)) +
          calendar_for(field_id)
    when "text"
      text_area_tag(field_name, custom_value.value, tag_options.merge(:rows => 4, :cols => 65, :style => "width:auto; resize:both;"))
    when "bool"
      custom_value.custom_field.format.edit_tag self,
                                                field_id,
                                                field_name,
                                                custom_value,
                                                :class => "#{custom_value.custom_field.field_format}_cf"
    when "list"
    when "enumeration"
      blank_option = ''.html_safe
      unless custom_field.multiple?
        if custom_field.is_required?
          unless custom_field.default_value.present?
            blank_option = content_tag('option', "--- #{l(:actionview_instancetag_blank_option)} ---", :value => '')
          end
        else
          blank_option = content_tag('option')
        end
      end
      s = select_tag(field_name, blank_option + options_for_select(custom_field.possible_values_options(custom_value.customized), custom_value.value),
                     tag_options.merge(:multiple => custom_field.multiple?, :id => (issue.id.to_s + '_' + custom_field.name.to_s + '_enum').parameterize.underscore))
      if custom_field.multiple?
        s << hidden_field_tag(field_name, '')
      end
      s
    else
      text_field_tag(field_name, custom_value.value, tag_options)
    end
  end

end
