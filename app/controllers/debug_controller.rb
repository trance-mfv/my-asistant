# frozen_string_literal: true

class DebugController < ApplicationController
  skip_before_action :verify_authenticity_token

  def index
    # Use the specialized query service for Jira ticket queries
    query_service = JiraTicketQueryService.new
    query = params[:query] || "Show me all open tickets assigned to me"
    jira_response = query_service.query_tickets(query)

    # Group the data by status category
    grouped_data = jira_response[:answer]["issues"].group_by { |status| status.dig("status", "category", "name") }

    # Transform into format needed for chart
    chart_data = grouped_data.transform_values(&:count)

    # Prepare colors for each category
    colors = {
      "To Do" => "#6C7A89", # blue-gray
      "In Progress" => "#F4D03F", # yellow
      "Done" => "#27AE60" # green (in case there are done items)
    }

    data = {
      labels: chart_data.keys,
      datasets: [ {
        data: chart_data.values,
        backgroundColor: chart_data.keys.map { |category| colors[category] }
      } ]
    }

    html_content = <<-HTML
      <!DOCTYPE html>
      <html>
      <head>
        <title>Issue Status Distribution</title>
        <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
        <style>
          .chart-container {
            width: 600px;
            margin: 20px auto;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
          }
        </style>
      </head>
      <body>
        <div class="chart-container">
          <canvas id="issueChart"></canvas>
        </div>

        <script>
          document.addEventListener('DOMContentLoaded', function() {
            const ctx = document.getElementById('issueChart').getContext('2d');
            new Chart(ctx, {
              type: 'pie',
              data: #{data.to_json},
              options: {
                responsive: true,
                plugins: {
                  title: {
                    display: true,
                    text: 'Issue Distribution by Status',
                    font: {
                      size: 16,
                      weight: 'bold'
                    }
                  },
                  legend: {
                    position: 'bottom',
                    labels: {
                      padding: 20
                    }
                  },
                  tooltip: {
                    callbacks: {
                      label: function(context) {
                        const label = context.label || '';
                        const value = context.raw || 0;
                        const total = context.dataset.data.reduce((a, b) => a + b, 0);
                        const percentage = ((value / total) * 100).toFixed(1);
                        return `${label}: ${value} (${percentage}%)`;
                      }
                    }
                  }
                }
              }
            });
          });
        </script>
      </body>
      </html>
    HTML

    render html: html_content.html_safe

    # render json: {
    #   jira_response: jira_response
    # }
  end

  def create
    # Use the specialized creation service for Jira ticket creation
    creation_service = JiraTicketCreationService.new

    # Get creation request from parameters
    creation_request = params[:request] || "Create a bug ticket titled 'Test issue' in project DEMO"

    jira_response = creation_service.create_ticket(creation_request)

    render json: {
      creation_request: creation_request,
      jira_response: jira_response
    }
  end

  def update
    # Use the specialized update service for Jira ticket updates
    update_service = JiraTicketUpdateService.new

    # Get update request from parameters
    update_request = params[:request] || "Update KAN-1 summary to 'Updated task title'"

    jira_response = update_service.update_ticket(update_request)

    render json: {
      update_request: update_request,
      jira_response: jira_response
    }
  end

  def prompt
    # Use the dispatcher service to handle natural language processing
    user_input = params[:input] || params[:prompt] || params[:request] || "Show me all open tickets assigned to me"

    dispatcher = JiraNaturalLanguageDispatcherService.new
    result = dispatcher.process_natural_language_request(user_input)

    render json: result
  end
end
