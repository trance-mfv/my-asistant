class JiraTicketUpdateService < JiraBaseService
  def update_ticket(update_request)
    # Use LLM to interpret the update request
    chat = RubyLLM.chat(model: "gpt-4.1-mini")

    update_prompt = build_update_prompt(update_request)
    interpretation = chat.ask(update_prompt)

    # Execute the ticket update
    result = execute_ticket_update(interpretation, update_request)

    {
      request: update_request,
      interpretation: interpretation,
      answer: result,
      timestamp: Time.current
    }
  rescue StandardError => e
    {
      request: update_request,
      error: "Failed to update ticket: #{e.message}",
      timestamp: Time.current
    }
  end

  private

  def build_update_prompt(update_request)
    <<~PROMPT
      Analyze this Jira ticket update request and extract the required parameters:

      Request: "#{update_request}"

      Please respond in JSON format with these fields:
      {
        "issue_key": "The JIRA issue key to update (required, e.g., ABC-123)",
        "update_type": "field_update|status_change|assign",
        "summary": "New summary/title (optional)",
        "description": "New description (optional)",
        "assignee": "New assignee email or username (optional)",
        "status": "New status name for transitions (optional)",
        "comment": "Comment to add during update (optional)",
        "additional_fields": "Any other fields to update (optional)"
      }

      Update types:
      - field_update: Change summary, description, or other fields
      - status_change: Transition issue to new status (In Progress, Done, etc.)
      - assign: Change assignee

      Examples:
      - "Update ABC-123 summary to 'New title'" → {"issue_key": "ABC-123", "update_type": "field_update", "summary": "New title"}
      - "Move XYZ-456 to In Progress" → {"issue_key": "XYZ-456", "update_type": "status_change", "status": "In Progress"}
      - "Assign DEF-789 to john@company.com" → {"issue_key": "DEF-789", "update_type": "assign", "assignee": "john@company.com"}
      - "Update ABC-123 description to 'New description' and assign to jane@company.com" → {"issue_key": "ABC-123", "update_type": "field_update", "description": "New description", "assignee": "jane@company.com"}
    PROMPT
  end

  def execute_ticket_update(interpretation, original_request)
    # Extract text from RubyLLM::Message object
    interpretation_text = interpretation.respond_to?(:content) ? interpretation.content : interpretation.to_s

    # Try to parse JSON from interpretation
    begin
      params = JSON.parse(interpretation_text.gsub(/```json|```/, "").strip)
    rescue JSON::ParserError
      return { error: "Could not parse update parameters from request" }
    end

    # Validate required fields
    unless params["issue_key"]
      return { error: "Missing required field: issue_key is required" }
    end

    # Handle different update types
    case params["update_type"]
    when "status_change"
      handle_status_change(params)
    when "assign", "field_update"
      handle_field_update(params)
    else
      # Default to field update
      handle_field_update(params)
    end
  end

  def handle_status_change(params)
    issue_key = params["issue_key"]
    target_status = params["status"]

    # First, get available transitions for this issue
    transitions_result = call_jira_get_transitions(issue_key)
    return transitions_result if transitions_result["error"]

    # Find the transition ID for the target status
    transitions = transitions_result["transitions"] || []
    target_transition = transitions.find { |t| t["to"]["name"].downcase == target_status.downcase }

    unless target_transition
      available_statuses = transitions.map { |t| t["to"]["name"] }.join(", ")
      return {
        error: "Cannot transition to '#{target_status}'. Available transitions: #{available_statuses}",
        available_transitions: transitions
      }
    end

    # Execute the transition
    transition_params = {
      "issue_key" => issue_key,
      "transition_id" => target_transition["id"],
      "comment" => params["comment"]
    }

    call_jira_transition_issue(transition_params)
  end

  def handle_field_update(params)
    # Use the regular update for field changes
    call_jira_update_issue(params)
  end
end