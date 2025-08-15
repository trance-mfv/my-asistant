class JiraTicketQueryService < JiraBaseService
  def query_tickets(natural_language_question)
    # Use LLM to interpret the question and determine the best approach
    chat = RubyLLM.chat(model: "gpt-4.1-mini")

    interpretation_prompt = build_interpretation_prompt(natural_language_question)
    interpretation = chat.ask(interpretation_prompt)

    # Execute the interpreted query using direct MCP tool calls
    result = execute_query_based_on_interpretation(interpretation, natural_language_question)

    {
      question: natural_language_question,
      interpretation: interpretation,
      answer: result,
      timestamp: Time.current
    }
  rescue StandardError => e
    {
      question: natural_language_question,
      error: "Failed to process query: #{e.message}",
      timestamp: Time.current
    }
  end

  private

  def build_interpretation_prompt(question)
    <<~PROMPT
      Analyze this Jira query and extract the key parameters needed to search for tickets:

      Question: "#{question}"

      Please respond in JSON format with these fields:
      {
        "action": "search_issues|get_issue|get_projects|get_user_profile",
        "jql": "JQL query string if action is search_issues",
        "issue_key": "issue key if action is get_issue",
        "project_key": "project key if filtering by project",
        "assignee": "assignee filter (currentUser() for 'me')",
        "status": "status filter",
        "issue_type": "issue type filter",
        "limit": 50
      }

      For "open tickets assigned to me", use:
      - action: "search_issues"
      - jql: "assignee = currentUser() AND status != Done"
      - assignee: "currentUser()"
      - status: "Open"
    PROMPT
  end

  def execute_query_based_on_interpretation(interpretation, original_question)
    # Extract text from RubyLLM::Message object
    interpretation_text = interpretation.content

    # Try to parse JSON from interpretation
    begin
      params = JSON.parse(interpretation_text.gsub(/```json|```/, "").strip)
    rescue JSON::ParserError
      # Fallback to simple search
      params = {
        "action" => "search_issues",
        "jql" => "assignee = currentUser() AND status != Done",
        "limit" => 50
      }
    end

    case params["action"]
    when "search_issues"
      call_jira_search(params)
    when "get_issue"
      call_jira_get_issue(params["issue_key"]) if params["issue_key"]
    when "get_projects"
      call_jira_get_projects
    else
      call_jira_search(params)
    end
  end
end
