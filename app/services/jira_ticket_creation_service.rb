class JiraTicketCreationService < JiraBaseService
  def create_ticket(creation_request)
    # Use LLM to interpret the creation request
    chat = RubyLLM.chat(model: "gpt-4.1-mini")

    creation_prompt = build_creation_prompt(creation_request)
    interpretation = chat.ask(creation_prompt)

    # Execute the ticket creation
    result = execute_ticket_creation(interpretation, creation_request)

    {
      request: creation_request,
      interpretation: interpretation,
      answer: result,
      timestamp: Time.current
    }
  rescue StandardError => e
    {
      request: creation_request,
      error: "Failed to create ticket: #{e.message}",
      timestamp: Time.current
    }
  end

  private

  def build_creation_prompt(creation_request)
    <<~PROMPT
      Analyze this Jira ticket creation request and extract the required parameters:

      Request: "#{creation_request}"

      Please respond in JSON format with these fields:
      {
        "project_key": "The JIRA project key (required)",
        "summary": "Issue title/summary (required)",
        "issue_type": "Bug|Task|Story|Epic|Subtask (required)",
        "description": "Detailed description (optional)",
        "assignee": "Assignee email or username (optional)",
        "priority": "Priority level (optional)",
        "components": "Comma-separated component names (optional)"
      }

      Common issue types:
      - Bug: For software defects
      - Task: For general work items
      - Story: For user stories
      - Epic: For large features
      - Subtask: For sub-items of other issues

      Examples:
      - "Create bug ticket 'Login fails' in PROJECT" → {"project_key": "PROJECT", "summary": "Login fails", "issue_type": "Bug"}
      - "New task 'Update docs' assigned to john@company.com" → {"summary": "Update docs", "issue_type": "Task", "assignee": "john@company.com"}
    PROMPT
  end

  def execute_ticket_creation(interpretation, original_request)
    # Extract text from RubyLLM::Message object
    interpretation_text = interpretation.content

    # Try to parse JSON from interpretation
    begin
      params = JSON.parse(interpretation_text.gsub(/```json|```/, "").strip)
    rescue JSON::ParserError => e
      return { error: "Could not parse creation parameters from request" }
    end

    # Validate required fields
    unless params["project_key"] && params["summary"] && params["issue_type"]
      return { error: "Missing required fields: project_key, summary, and issue_type are required" }
    end

    call_jira_create_issue(params)
  end
end
