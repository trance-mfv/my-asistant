class JiraNaturalLanguageDispatcherService
  def process_natural_language_request(user_input)
    # Determine user intent using LLM + fallback logic
    intent = determine_intent(user_input)

    # Route to appropriate service based on intent
    case intent
    when :query
      query_service = JiraTicketQueryService.new
      jira_response = query_service.query_tickets(user_input)

      {
        user_input: user_input,
        detected_intent: "query",
        jira_response: jira_response,
        timestamp: Time.current
      }
    when :create
      creation_service = JiraTicketCreationService.new
      jira_response = creation_service.create_ticket(user_input)

      {
        user_input: user_input,
        detected_intent: "create",
        jira_response: jira_response,
        timestamp: Time.current
      }
    when :update
      update_service = JiraTicketUpdateService.new
      jira_response = update_service.update_ticket(user_input)

      {
        user_input: user_input,
        detected_intent: "update",
        jira_response: jira_response,
        timestamp: Time.current
      }
    else
      {
        user_input: user_input,
        detected_intent: "unknown",
        error: "Could not determine intent. Please specify if you want to query, create, or update tickets.",
        suggestion: "Try phrases like 'Show me tickets...' for queries, 'Create a ticket...' for creation, or 'Update ABC-123...' for updates",
        timestamp: Time.current
      }
    end
  rescue StandardError => e
    {
      user_input: user_input,
      error: "Failed to process request: #{e.message}",
      timestamp: Time.current
    }
  end

  private

  def determine_intent(user_input)
    # First try LLM-based classification
    llm_intent = classify_intent_with_llm(user_input)
    return llm_intent if llm_intent != :unknown

    # Fallback to regex-based classification
    classify_intent_with_regex(user_input)
  end

  def classify_intent_with_llm(user_input)
    chat = RubyLLM.chat(model: "gpt-4.1-mini")

    intent_prompt = build_intent_classification_prompt(user_input)
    response = chat.ask(intent_prompt)

    # Extract intent from response
    response_text = response.respond_to?(:content) ? response.content : response.to_s

    if response_text.downcase.include?("create")
      :create
    elsif response_text.downcase.include?("update")
      :update
    elsif response_text.downcase.include?("query")
      :query
    else
      :unknown
    end
  rescue StandardError
    :unknown
  end

  def classify_intent_with_regex(user_input)
    input_lower = user_input.downcase

    # Creation keywords
    if input_lower.match?(/(?:create|new|add|make)\s+(?:ticket|issue|bug|task|story|epic)/)
      :create
    # Update keywords
    elsif input_lower.match?(/(?:update|edit|modify|change|assign|move|transition)\s+(?:ticket|issue|bug|task|story|epic)?/) ||
          input_lower.match?(/(?:set|assign)\s+\w+-\d+/) ||
          input_lower.match?(/\w+-\d+\s+(?:to|status|assignee)/)
      :update
    # Query keywords
    elsif input_lower.match?(/(?:show|list|find|search|get|display)\s+(?:tickets?|issues?|bugs?|tasks?)/) ||
          input_lower.match?(/(?:what|which|how many)\s+(?:tickets?|issues?)/) ||
          input_lower.match?(/tickets?\s+(?:assigned|for|in|with)/)
      :query
    else
      :unknown
    end
  end

  def build_intent_classification_prompt(user_input)
    <<~PROMPT
      Analyze this user input and determine if they want to QUERY existing Jira tickets, CREATE a new ticket, or UPDATE an existing ticket.

      User Input: "#{user_input}"

      Classification Rules:
      - QUERY: User wants to search, find, list, show, or get information about existing tickets
        Examples: "Show me open tickets", "Find bugs assigned to me", "List tickets in project X"

      - CREATE: User wants to create, add, make, or generate a new ticket
        Examples: "Create a bug ticket", "New task for documentation", "Add a story about user login"

      - UPDATE: User wants to modify, edit, assign, or change status of an existing ticket
        Examples: "Update ABC-123 summary", "Assign XYZ-456 to john@company.com", "Move DEF-789 to In Progress", "Change ticket ABC-123 description"

      Respond with exactly one word: either "QUERY", "CREATE", or "UPDATE"

      If unclear, prefer QUERY as it's safer.
    PROMPT
  end
end
