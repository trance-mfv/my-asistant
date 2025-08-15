class JiraBaseService
  def initialize
    @jira_mcp_client = RubyLLM::MCP.client(
      name: "jira-mcp-server",
      transport_type: :sse,
      config: {
        url: "http://localhost:9000/sse"
      }
    )
  end

  private

  def call_jira_search(params)
    jql = params["jql"] || build_default_jql(params)

    tool = @jira_mcp_client.tool("jira_search")

    result = tool.execute(
      jql: jql,
      fields: "summary,status,assignee,created,issuetype",
      limit: params["limit"] || 50
    )

    JSON.parse(result.text)
  rescue StandardError => e
    { error: "Search failed: #{e.message}" }
  end

  def call_jira_get_issue(issue_key)
    tool = @jira_mcp_client.tool("jira_get_issue")
    result = tool.execute(
      issue_key: issue_key,
      fields: "summary,status,assignee,description,created,updated"
    )

    JSON.parse(result.text)
  rescue StandardError => e
    { error: "Get issue failed: #{e.message}" }
  end

  def call_jira_get_projects
    tool = @jira_mcp_client.tool("jira_get_all_projects")
    result = tool.execute(include_archived: false)

    JSON.parse(result.text)
  rescue StandardError => e
    { error: "Get projects failed: #{e.message}" }
  end

  def call_jira_create_issue(params)
    tool = @jira_mcp_client.tool("jira_create_issue")

    # Prepare parameters for the MCP tool
    create_params = {
      project_key: params["project_key"],
      summary: params["summary"],
      issue_type: params["issue_type"]
    }

    # Add optional parameters if present
    create_params[:description] = params["description"] if params["description"]
    create_params[:assignee] = params["assignee"] if params["assignee"]
    create_params[:components] = params["components"] if params["components"]

    result = tool.execute(**create_params)
    JSON.parse(result.text)
  rescue StandardError => e
    { error: "Create issue failed: #{e.message}" }
  end

  def call_jira_update_issue(params)
    tool = @jira_mcp_client.tool("jira_update_issue")

    # Prepare parameters for the MCP tool
    update_params = {
      issue_key: params["issue_key"],
      fields: {}
    }

    # Build fields hash for update
    fields = {}
    fields[:summary] = params["summary"] if params["summary"]
    fields[:description] = params["description"] if params["description"]
    fields[:assignee] = { name: params["assignee"] } if params["assignee"]

    # Handle status transitions separately if needed
    # Status updates typically require transition_issue instead of update_issue
    update_params[:fields] = fields
    update_params[:additional_fields] = params["additional_fields"] if params["additional_fields"]

    result = tool.execute(**update_params)
    JSON.parse(result.text)
  rescue StandardError => e
    { error: "Update issue failed: #{e.message}" }
  end

  def call_jira_transition_issue(params)
    tool = @jira_mcp_client.tool("jira_transition_issue")

    transition_params = {
      issue_key: params["issue_key"],
      transition_id: params["transition_id"]
    }

    transition_params[:fields] = params["fields"] if params["fields"]
    transition_params[:comment] = params["comment"] if params["comment"]

    result = tool.execute(**transition_params)
    JSON.parse(result.text)
  rescue StandardError => e
    { error: "Transition issue failed: #{e.message}" }
  end

  def call_jira_get_transitions(issue_key)
    tool = @jira_mcp_client.tool("jira_get_transitions")
    result = tool.execute(issue_key: issue_key)

    JSON.parse(result.text)
  rescue StandardError => e
    { error: "Get transitions failed: #{e.message}" }
  end

  def build_default_jql(params)
    jql_parts = []

    jql_parts << "assignee = currentUser()" if params["assignee"] == "currentUser()"
    jql_parts << "status != Done" if params["status"] == "Open"
    jql_parts << "project = #{params['project_key']}" if params["project_key"]
    jql_parts << "issuetype = #{params['issue_type']}" if params["issue_type"]

    jql_parts.any? ? jql_parts.join(" AND ") : "order by created DESC"
  end
end
