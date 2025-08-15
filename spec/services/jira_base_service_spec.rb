require 'rails_helper'

RSpec.describe JiraBaseService do
  let(:service) { JiraBaseService.new }
  let(:mock_client) { double('jira_mcp_client') }
  let(:mock_tool) { double('tool') }
  let(:mock_result) { double('result', text: '{"success": true}') }

  before do
    allow(RubyLLM::MCP).to receive(:client).and_return(mock_client)
  end

  describe '#initialize' do
    it 'creates a jira_mcp_client' do
      expect(RubyLLM::MCP).to receive(:client).with(
        name: "jira-mcp-server",
        transport_type: :sse,
        config: {
          url: "http://localhost:9000/sse"
        }
      )
      JiraBaseService.new
    end
  end

  describe '#call_jira_search' do
    let(:params) { { "jql" => "project = TEST", "limit" => 25 } }

    before do
      allow(mock_client).to receive(:tool).with("jira_search").and_return(mock_tool)
      allow(mock_tool).to receive(:execute).and_return(mock_result)
      allow(service).to receive(:jira_mcp_client).and_return(mock_client)
    end

    it 'executes jira_search tool with correct parameters' do
      expect(mock_tool).to receive(:execute).with(
        jql: "project = TEST",
        fields: "summary,status,assignee,created,issuetype",
        limit: 25
      )

      service.send(:call_jira_search, params)
    end

    it 'returns parsed JSON response' do
      service.call_jira_search(params)
    end

    it 'returns parsed JSON response' do
      result = service.call_jira_search(params)
      expect(result).to eq({ "success" => true })
    end

    it 'uses default limit when not provided' do
      params.delete("limit")
      expect(mock_tool).to receive(:execute).with(
        jql: "project = TEST",
        fields: "summary,status,assignee,created,issuetype",
        limit: 50
      )

      service.send(:call_jira_search, params)
    end

    it 'builds default JQL when not provided' do
      params.delete("jql")
      allow(service).to receive(:build_default_jql).with(params).and_return("order by created DESC")

      expect(mock_tool).to receive(:execute).with(
        jql: "order by created DESC",
        fields: "summary,status,assignee,created,issuetype",
        limit: 25
      )

      service.send(:call_jira_search, params)
    end

    context 'when an error occurs' do
      before do
        allow(mock_tool).to receive(:execute).and_raise(StandardError, "Connection failed")
      end

      it 'returns error hash' do
        result = service.send(:call_jira_search, params)
        expect(result).to eq({ error: "Search failed: Connection failed" })
      end
    end
  end

  describe '#call_jira_get_issue' do
    let(:issue_key) { "TEST-123" }

    before do
      allow(mock_client).to receive(:tool).with("jira_get_issue").and_return(mock_tool)
      allow(mock_tool).to receive(:execute).and_return(mock_result)
      allow(service).to receive(:instance_variable_get).with(:@jira_mcp_client).and_return(mock_client)
    end

    it 'executes jira_get_issue tool with correct parameters' do
      expect(mock_tool).to receive(:execute).with(
        issue_key: issue_key,
        fields: "summary,status,assignee,description,created,updated"
      )

      service.send(:call_jira_get_issue, issue_key)
    end

    it 'returns parsed JSON response' do
      result = service.send(:call_jira_get_issue, issue_key)
      expect(result).to eq({ "success" => true })
    end

    context 'when an error occurs' do
      before do
        allow(mock_tool).to receive(:execute).and_raise(StandardError, "Issue not found")
      end

      it 'returns error hash' do
        result = service.send(:call_jira_get_issue, issue_key)
        expect(result).to eq({ error: "Get issue failed: Issue not found" })
      end
    end
  end

  describe '#call_jira_get_projects' do
    before do
      allow(mock_client).to receive(:tool).with("jira_get_all_projects").and_return(mock_tool)
      allow(mock_tool).to receive(:execute).and_return(mock_result)
      allow(service).to receive(:instance_variable_get).with(:@jira_mcp_client).and_return(mock_client)
    end

    it 'executes jira_get_all_projects tool with correct parameters' do
      expect(mock_tool).to receive(:execute).with(include_archived: false)

      service.send(:call_jira_get_projects)
    end

    it 'returns parsed JSON response' do
      result = service.send(:call_jira_get_projects)
      expect(result).to eq({ "success" => true })
    end

    context 'when an error occurs' do
      before do
        allow(mock_tool).to receive(:execute).and_raise(StandardError, "Authentication failed")
      end

      it 'returns error hash' do
        result = service.send(:call_jira_get_projects)
        expect(result).to eq({ error: "Get projects failed: Authentication failed" })
      end
    end
  end

  describe '#call_jira_create_issue' do
    let(:params) do
      {
        "project_key" => "TEST",
        "summary" => "Test issue",
        "issue_type" => "Bug",
        "description" => "Test description",
        "assignee" => "john.doe",
        "components" => [ "Frontend" ]
      }
    end

    before do
      allow(mock_client).to receive(:tool).with("jira_create_issue").and_return(mock_tool)
      allow(mock_tool).to receive(:execute).and_return(mock_result)
      allow(service).to receive(:instance_variable_get).with(:@jira_mcp_client).and_return(mock_client)
    end

    it 'executes jira_create_issue tool with correct parameters' do
      expect(mock_tool).to receive(:execute).with(
        project_key: "TEST",
        summary: "Test issue",
        issue_type: "Bug",
        description: "Test description",
        assignee: "john.doe",
        components: [ "Frontend" ]
      )

      service.send(:call_jira_create_issue, params)
    end

    it 'returns parsed JSON response' do
      result = service.send(:call_jira_create_issue, params)
      expect(result).to eq({ "success" => true })
    end

    it 'only includes optional parameters when present' do
      minimal_params = {
        "project_key" => "TEST",
        "summary" => "Test issue",
        "issue_type" => "Bug"
      }

      expect(mock_tool).to receive(:execute).with(
        project_key: "TEST",
        summary: "Test issue",
        issue_type: "Bug"
      )

      service.send(:call_jira_create_issue, minimal_params)
    end

    context 'when an error occurs' do
      before do
        allow(mock_tool).to receive(:execute).and_raise(StandardError, "Invalid project key")
      end

      it 'returns error hash' do
        result = service.send(:call_jira_create_issue, params)
        expect(result).to eq({ error: "Create issue failed: Invalid project key" })
      end
    end
  end

  describe '#call_jira_update_issue' do
    let(:params) do
      {
        "issue_key" => "TEST-123",
        "summary" => "Updated summary",
        "description" => "Updated description",
        "assignee" => "jane.doe",
        "additional_fields" => { "priority" => "High" }
      }
    end

    before do
      allow(mock_client).to receive(:tool).with("jira_update_issue").and_return(mock_tool)
      allow(mock_tool).to receive(:execute).and_return(mock_result)
      allow(service).to receive(:instance_variable_get).with(:@jira_mcp_client).and_return(mock_client)
    end

    it 'executes jira_update_issue tool with correct parameters' do
      expect(mock_tool).to receive(:execute).with(
        issue_key: "TEST-123",
        fields: {
          summary: "Updated summary",
          description: "Updated description",
          assignee: { name: "jane.doe" }
        },
        additional_fields: { "priority" => "High" }
      )

      service.send(:call_jira_update_issue, params)
    end

    it 'returns parsed JSON response' do
      result = service.send(:call_jira_update_issue, params)
      expect(result).to eq({ "success" => true })
    end

    it 'handles minimal update parameters' do
      minimal_params = { "issue_key" => "TEST-123", "summary" => "New summary" }

      expect(mock_tool).to receive(:execute).with(
        issue_key: "TEST-123",
        fields: { summary: "New summary" }
      )

      service.send(:call_jira_update_issue, minimal_params)
    end

    context 'when an error occurs' do
      before do
        allow(mock_tool).to receive(:execute).and_raise(StandardError, "Issue not found")
      end

      it 'returns error hash' do
        result = service.send(:call_jira_update_issue, params)
        expect(result).to eq({ error: "Update issue failed: Issue not found" })
      end
    end
  end

  describe '#call_jira_transition_issue' do
    let(:params) do
      {
        "issue_key" => "TEST-123",
        "transition_id" => "31",
        "fields" => { "resolution" => "Done" },
        "comment" => "Resolved issue"
      }
    end

    before do
      allow(mock_client).to receive(:tool).with("jira_transition_issue").and_return(mock_tool)
      allow(mock_tool).to receive(:execute).and_return(mock_result)
      allow(service).to receive(:instance_variable_get).with(:@jira_mcp_client).and_return(mock_client)
    end

    it 'executes jira_transition_issue tool with correct parameters' do
      expect(mock_tool).to receive(:execute).with(
        issue_key: "TEST-123",
        transition_id: "31",
        fields: { "resolution" => "Done" },
        comment: "Resolved issue"
      )

      service.send(:call_jira_transition_issue, params)
    end

    it 'returns parsed JSON response' do
      result = service.send(:call_jira_transition_issue, params)
      expect(result).to eq({ "success" => true })
    end

    it 'handles minimal transition parameters' do
      minimal_params = { "issue_key" => "TEST-123", "transition_id" => "31" }

      expect(mock_tool).to receive(:execute).with(
        issue_key: "TEST-123",
        transition_id: "31"
      )

      service.send(:call_jira_transition_issue, minimal_params)
    end

    context 'when an error occurs' do
      before do
        allow(mock_tool).to receive(:execute).and_raise(StandardError, "Invalid transition")
      end

      it 'returns error hash' do
        result = service.send(:call_jira_transition_issue, params)
        expect(result).to eq({ error: "Transition issue failed: Invalid transition" })
      end
    end
  end

  describe '#call_jira_get_transitions' do
    let(:issue_key) { "TEST-123" }

    before do
      allow(mock_client).to receive(:tool).with("jira_get_transitions").and_return(mock_tool)
      allow(mock_tool).to receive(:execute).and_return(mock_result)
      allow(service).to receive(:instance_variable_get).with(:@jira_mcp_client).and_return(mock_client)
    end

    it 'executes jira_get_transitions tool with correct parameters' do
      expect(mock_tool).to receive(:execute).with(issue_key: issue_key)

      service.send(:call_jira_get_transitions, issue_key)
    end

    it 'returns parsed JSON response' do
      result = service.send(:call_jira_get_transitions, issue_key)
      expect(result).to eq({ "success" => true })
    end

    context 'when an error occurs' do
      before do
        allow(mock_tool).to receive(:execute).and_raise(StandardError, "Issue not found")
      end

      it 'returns error hash' do
        result = service.send(:call_jira_get_transitions, issue_key)
        expect(result).to eq({ error: "Get transitions failed: Issue not found" })
      end
    end
  end

  describe '#build_default_jql' do
    it 'builds JQL for current user assignment' do
      params = { "assignee" => "currentUser()" }
      result = service.send(:build_default_jql, params)
      expect(result).to eq("assignee = currentUser()")
    end

    it 'builds JQL for open status' do
      params = { "status" => "Open" }
      result = service.send(:build_default_jql, params)
      expect(result).to eq("status != Done")
    end

    it 'builds JQL for specific project' do
      params = { "project_key" => "TEST" }
      result = service.send(:build_default_jql, params)
      expect(result).to eq("project = TEST")
    end

    it 'builds JQL for specific issue type' do
      params = { "issue_type" => "Bug" }
      result = service.send(:build_default_jql, params)
      expect(result).to eq("issuetype = Bug")
    end

    it 'combines multiple parameters with AND' do
      params = {
        "assignee" => "currentUser()",
        "status" => "Open",
        "project_key" => "TEST",
        "issue_type" => "Bug"
      }
      result = service.send(:build_default_jql, params)
      expect(result).to eq("assignee = currentUser() AND status != Done AND project = TEST AND issuetype = Bug")
    end

    it 'returns default ordering when no parameters' do
      params = {}
      result = service.send(:build_default_jql, params)
      expect(result).to eq("order by created DESC")
    end
  end
end
