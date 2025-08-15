class JiraService
  include RubyLLM::MCP

  def initialize
    @mcp_client = RubyLLM::MCP.client(
      name: "my-mcp-server",
      transport_type: :sse,
      config: {
        url: "http://localhost:9001/sse"
      }
    )
  end

  # User profile operations
  def get_user_profile(user_identifier:)
    call_tool("jira_get_user_profile", { user_identifier: user_identifier })
  end

  # Issue operations
  def get_issue(issue_key:, fields: nil, expand: nil, comment_limit: nil, properties: nil, update_history: nil)
    params = { issue_key: issue_key }
    params[:fields] = fields if fields
    params[:expand] = expand if expand
    params[:comment_limit] = comment_limit if comment_limit
    params[:properties] = properties if properties
    params[:update_history] = update_history if update_history

    call_tool("jira_get_issue", params)
  end

  def create_issue(project_key:, summary:, issue_type:, assignee: nil, description: nil, components: nil, additional_fields: nil)
    params = {
      project_key: project_key,
      summary: summary,
      issue_type: issue_type
    }
    params[:assignee] = assignee if assignee
    params[:description] = description if description
    params[:components] = components if components
    params[:additional_fields] = additional_fields if additional_fields

    call_tool("jira_create_issue", params)
  end

  def update_issue(issue_key:, fields:, additional_fields: nil, attachments: nil)
    params = {
      issue_key: issue_key,
      fields: fields
    }
    params[:additional_fields] = additional_fields if additional_fields
    params[:attachments] = attachments if attachments

    call_tool("jira_update_issue", params)
  end

  def delete_issue(issue_key:)
    call_tool("jira_delete_issue", { issue_key: issue_key })
  end

  def search_issues(jql:, fields: nil, limit: nil, start_at: nil, projects_filter: nil, expand: nil)
    params = { jql: jql }
    params[:fields] = fields if fields
    params[:limit] = limit if limit
    params[:start_at] = start_at if start_at
    params[:projects_filter] = projects_filter if projects_filter
    params[:expand] = expand if expand

    call_tool("jira_search", params)
  end

  def add_comment(issue_key:, comment:)
    call_tool("jira_add_comment", {
      issue_key: issue_key,
      comment: comment
    })
  end

  def add_worklog(issue_key:, time_spent:, comment: nil, started: nil, original_estimate: nil, remaining_estimate: nil)
    params = {
      issue_key: issue_key,
      time_spent: time_spent
    }
    params[:comment] = comment if comment
    params[:started] = started if started
    params[:original_estimate] = original_estimate if original_estimate
    params[:remaining_estimate] = remaining_estimate if remaining_estimate

    call_tool("jira_add_worklog", params)
  end

  def get_worklog(issue_key:)
    call_tool("jira_get_worklog", { issue_key: issue_key })
  end

  def transition_issue(issue_key:, transition_id:, fields: nil, comment: nil)
    params = {
      issue_key: issue_key,
      transition_id: transition_id
    }
    params[:fields] = fields if fields
    params[:comment] = comment if comment

    call_tool("jira_transition_issue", params)
  end

  def get_transitions(issue_key:)
    call_tool("jira_get_transitions", { issue_key: issue_key })
  end

  # Linking operations
  def link_issues(link_type:, inward_issue_key:, outward_issue_key:, comment: nil, comment_visibility: nil)
    params = {
      link_type: link_type,
      inward_issue_key: inward_issue_key,
      outward_issue_key: outward_issue_key
    }
    params[:comment] = comment if comment
    params[:comment_visibility] = comment_visibility if comment_visibility

    call_tool("jira_create_issue_link", params)
  end

  def link_to_epic(issue_key:, epic_key:)
    call_tool("jira_link_to_epic", {
      issue_key: issue_key,
      epic_key: epic_key
    })
  end

  def create_remote_issue_link(issue_key:, url:, title:, summary: nil, relationship: nil, icon_url: nil)
    params = {
      issue_key: issue_key,
      url: url,
      title: title
    }
    params[:summary] = summary if summary
    params[:relationship] = relationship if relationship
    params[:icon_url] = icon_url if icon_url

    call_tool("jira_create_remote_issue_link", params)
  end

  def remove_issue_link(link_id:)
    call_tool("jira_remove_issue_link", { link_id: link_id })
  end

  def get_link_types
    call_tool("jira_get_link_types", {})
  end

  # Project operations
  def get_all_projects(include_archived: false)
    call_tool("jira_get_all_projects", { include_archived: include_archived })
  end

  def get_project_issues(project_key:, limit: nil, start_at: nil)
    params = { project_key: project_key }
    params[:limit] = limit if limit
    params[:start_at] = start_at if start_at

    call_tool("jira_get_project_issues", params)
  end

  def get_project_versions(project_key:)
    call_tool("jira_get_project_versions", { project_key: project_key })
  end

  def create_version(project_key:, name:, start_date: nil, release_date: nil, description: nil)
    params = {
      project_key: project_key,
      name: name
    }
    params[:start_date] = start_date if start_date
    params[:release_date] = release_date if release_date
    params[:description] = description if description

    call_tool("jira_create_version", params)
  end

  # Board operations
  def get_agile_boards(board_name: nil, project_key: nil, board_type: nil, start_at: nil, limit: nil)
    params = {}
    params[:board_name] = board_name if board_name
    params[:project_key] = project_key if project_key
    params[:board_type] = board_type if board_type
    params[:start_at] = start_at if start_at
    params[:limit] = limit if limit

    call_tool("jira_get_agile_boards", params)
  end

  def get_board_issues(board_id:, jql: nil, fields: nil, start_at: nil, limit: nil, expand: nil)
    params = { board_id: board_id }
    params[:jql] = jql if jql
    params[:fields] = fields if fields
    params[:start_at] = start_at if start_at
    params[:limit] = limit if limit
    params[:expand] = expand if expand

    call_tool("jira_get_board_issues", params)
  end

  # Sprint operations
  def get_sprints_from_board(board_id:, state: nil, start_at: nil, limit: nil)
    params = { board_id: board_id }
    params[:state] = state if state
    params[:start_at] = start_at if start_at
    params[:limit] = limit if limit

    call_tool("jira_get_sprints_from_board", params)
  end

  def get_sprint_issues(sprint_id:, fields: nil, start_at: nil, limit: nil)
    params = { sprint_id: sprint_id }
    params[:fields] = fields if fields
    params[:start_at] = start_at if start_at
    params[:limit] = limit if limit

    call_tool("jira_get_sprint_issues", params)
  end

  def create_sprint(board_id:, sprint_name:, start_date: nil, end_date: nil, goal: nil)
    params = {
      board_id: board_id,
      sprint_name: sprint_name
    }
    params[:start_date] = start_date if start_date
    params[:end_date] = end_date if end_date
    params[:goal] = goal if goal

    call_tool("jira_create_sprint", params)
  end

  def update_sprint(sprint_id:, sprint_name: nil, state: nil, start_date: nil, end_date: nil, goal: nil)
    params = { sprint_id: sprint_id }
    params[:sprint_name] = sprint_name if sprint_name
    params[:state] = state if state
    params[:start_date] = start_date if start_date
    params[:end_date] = end_date if end_date
    params[:goal] = goal if goal

    call_tool("jira_update_sprint", params)
  end

  # Batch operations
  def batch_create_issues(issues:, validate_only: false)
    call_tool("jira_batch_create_issues", {
      issues: issues,
      validate_only: validate_only
    })
  end

  def batch_get_changelogs(issue_ids_or_keys:, fields: nil, limit: nil)
    params = { issue_ids_or_keys: issue_ids_or_keys }
    params[:fields] = fields if fields
    params[:limit] = limit if limit

    call_tool("jira_batch_get_changelogs", params)
  end

  def batch_create_versions(project_key:, versions:)
    call_tool("jira_batch_create_versions", {
      project_key: project_key,
      versions: versions
    })
  end

  # Field operations
  def search_fields(keyword:, limit: nil, refresh: false)
    params = { keyword: keyword }
    params[:limit] = limit if limit
    params[:refresh] = refresh if refresh

    call_tool("jira_search_fields", params)
  end

  # Attachment operations
  def download_attachments(issue_key:, target_dir:)
    call_tool("jira_download_attachments", {
      issue_key: issue_key,
      target_dir: target_dir
    })
  end

  private

  def call_tool(tool_name, params = {})
    tool = @mcp_client.tool(tool_name)
    result = tool.execute(**params)

    JSON.parse(result.text)
  end
end
