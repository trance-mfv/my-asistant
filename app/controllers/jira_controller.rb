class JiraController < ApplicationController
  def index
    client = RubyLLM::MCP.client(
      name: "my-mcp-server",
      transport_type: :sse,
      config: {
        url: "http://localhost:9000"
      }
    )

    # Get available tools from the MCP server
    tools = client.tools
    puts "Available tools:"
    response = tools.map do |tool|
      "#{tool.name}: #{tool.description}"
    end


    render json: { message: response }
  end
end
