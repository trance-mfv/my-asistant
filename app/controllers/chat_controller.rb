class ChatController < ApplicationController
  def index
    chat = RubyLLM.chat
    response = chat.ask params[:s]

    render json: { response: response.content }
  end
end
