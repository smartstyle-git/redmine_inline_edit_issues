class InlineIssuesController < ApplicationController

  before_action :find_project, :only => [:edit_multiple, :update_multiple]
  before_action :retrieve_query, :get_ids_before_edit, :only => [:edit_multiple]
  before_action :get_ids_before_update, :only => [:update_multiple]
  before_action :find_projects, :authorize, :only => [:edit_multiple, :update_multiple]

  helper :queries
  include QueriesHelper
  helper :sort
  include SortHelper
  include IssuesHelper
  include InlineIssuesHelper

  def edit_multiple
    description_column = @query.columns.select { |c| c.name == :description }.first
    @query_inline_columns = description_column.present? ?
                                @query.inline_columns.insert(1, description_column) :
                                @query.inline_columns

    sort_init(@query.sort_criteria.empty? ? [['id', 'desc']] : @query.sort_criteria)
    sort_update(@query.sortable_columns)
    @query.sort_criteria = sort_criteria.to_a

    if @query.valid?
      @limit = per_page_option
      @issue_count = @query.issue_count
      @issue_pages = Paginator.new @issue_count, @limit, params['page']
      @offset ||= @issue_pages.offset
      @issues = @query.issues(:include => [:assigned_to, :tracker, :priority, :category, :fixed_version],
                              :order => sort_clause,
                              :offset => @offset,
                              :limit => @limit,
                              :conditions => inline_edit_condition)

      @ids = @issues.map(&:id)

      @issue_count_by_group = issue_count_by_group

      @priorities = IssuePriority.active
    else
      # respond_to do |format|
      # format.html { render(:template => 'issues/index', :layout => !request.xhr?) }
      # format.any(:atom, :csv, :pdf) { render(:nothing => true) }
      # format.api { render_validation_errors(@query) }
      # end
    end
    @back_url = @project ? project_issues_path(@project) : params[:back_url]
    @update_url = @project ? update_multiple_inline_issues_path(:project_id => @project) : update_multiple_inline_issues_path(:ids => @ids)
  rescue ActiveRecord::RecordNotFound
    render_404
  rescue Query::StatementInvalid
    flash[:error] = l('label_no_issues_selected')
    redirect_back(fallback_location: root_path)
  end

  def update_multiple
    errors = []
    puts params[:issues].inspect
    Issue.find(params[:issues].keys).each do |i|
      issue_params = params[:issues][i.id.to_s]
      
      # Extract relation parameters
      delete_relation_ids = issue_params.delete(:delete_relation_ids)
      new_relation_type = issue_params.delete(:new_relation_type)
      new_relation_issue_id = issue_params.delete(:new_relation_issue_id)
      
      # Update issue attributes
      attribute_hash = issue_params.to_unsafe_h
      upd = i.update(attribute_hash)
      errors += i.errors.full_messages.map { |m| l(:label_issue) + " #{i.id}: " + m } if !upd
      
      # Process relation deletions
      if delete_relation_ids.present?
        IssueRelation.where(id: delete_relation_ids, issue_from_id: i.id).destroy_all
        IssueRelation.where(id: delete_relation_ids, issue_to_id: i.id).destroy_all
      end
      
      # Process new relation
      if new_relation_type.present? && new_relation_issue_id.present?
        # Remove # if present
        target_id = new_relation_issue_id.to_s.gsub(/^#/, '').to_i
        target_issue = Issue.visible.find_by(id: target_id)
        
        if target_issue
          relation = IssueRelation.new(
            issue_from: i,
            issue_to: target_issue,
            relation_type: new_relation_type
          )
          unless relation.save
            errors += relation.errors.full_messages.map { |m| l(:label_issue) + " #{i.id}: " + m }
          end
        else
          errors << "#{l(:label_issue)} #{i.id}: #{l(:label_issue)} ##{target_id} #{l(:notice_not_found)}"
        end
      end
    end

    if errors.present?
      flash[:error] = errors.to_sentence
      redirect_back(fallback_location: root_path)
    else
      flash[:notice] = l(:notice_successful_update)
      redirect_back_or_default params[:back_url] #_project_issues_path(@project)
    end
  end

  private

  def get_ids_before_edit
    @ids = []
    if params[:ids].present?
      if params[:ids].class.name == "Array"
        @ids = params[:ids]
      elsif params[:ids].class.name == "String"
        @ids = params[:ids].split(" ")
      end
    else
      @ids = @query.issues(:include => [:assigned_to, :tracker, :priority, :category, :fixed_version]).map(&:id)
    end
    @ids
  end

  def get_ids_before_update
    @ids = []
    if params[:ids].present?
      if params[:ids].class.name == "Array"
        @ids = params[:ids]
      elsif params[:ids].class.name == "String"
        @ids = params[:ids].split(" ")
      end
    end
    @ids
  end

  def find_project
    @project = Project.find(params[:project_id]) if params[:project_id].present?
    # @projects = params[:projects_id].present? ? Project.find(params[:projects_id]) : (params[:ids].present? ? Issue.find(params[:ids]).map(&:project_id).uniq : nil)
  end

  def find_projects
    @projects = @ids ? Issue.find(@ids).map(&:project).uniq : nil
  end

  # Returns the issue count by group or nil if query is not grouped
  def issue_count_by_group
    r = nil
    if @query.grouped?
      begin
        # Rails3 will raise an (unexpected) RecordNotFound if there's only a nil group value
        r = Issue.visible.
            joins(:status, :project).
            where(@query.statement).
            joins(joins_for_order_statement(@query.group_by_statement)).
            group(@query.group_by_statement).
            where(inline_edit_condition).
            count
      rescue ActiveRecord::RecordNotFound
        r = {nil => @query.issue_count}
      end
      c = @query.group_by_column
      if c.is_a?(QueryCustomFieldColumn)
        r = r.keys.inject({}) { |h, k| h[c.custom_field.cast_value(k)] = r[k]; h }
      end
    end
    r
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end

  # Additional joins required for the given sort options
  def joins_for_order_statement(order_options)
    joins = []

    if order_options
      if order_options.include?('authors')
        joins << "LEFT OUTER JOIN #{User.table_name} authors ON authors.id = #{queried_table_name}.author_id"
      end
      order_options.scan(/cf_\d+/).uniq.each do |name|
        column = available_columns.detect { |c| c.name.to_s == name }
        join = column && column.custom_field.join_for_order_statement
        if join
          joins << join
        end
      end
    end

    joins.any? ? joins.join(' ') : nil
  end

end
